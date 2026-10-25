#!/usr/bin/env node
// 3 店ボタンの価格を取る（Mac の毎日ジョブ scripts/strategy-board/mac-weekly.sh の 4 段目）。LLM 不使用・$0。
//   RAKUTEN_APP_ID / RAKUTEN_ACCESS_KEY / YAHOO_APP_ID を環境変数で受ける（mac-weekly.sh が Keychain から渡す）。
//   **鍵は出力しない。** 出力は公開ブランチ ops/heartbeat に載るので、商品の公開情報（価格・送料・ポイント・レビュー・URL）だけ。
//
//   node scripts/shop/fetch-prices.mjs --out <shop-prices.json> [--dir src/data/shop]
//
// 商品ごとに src/data/shop/<シリーズ>.json の rakuten.keyword / yahoo.keyword で検索し、
// 商品名に must（型番など）を全部含み exclude を含まないものから「本体価格 − 通常ポイント」が最小の 1 件を選ぶ。
// 当たりが無ければ found: false（古い価格を残さない。apply-prices.mjs が価格を消す）。
import fs from 'node:fs';
import path from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).map((a, i, all) => a.startsWith('--') ? [a.slice(2), all[i + 1]] : null).filter(Boolean));
const OUT = args.out || '/tmp/shop-prices.json';
const DIR = args.dir || path.join(process.cwd(), 'src/data/shop');
const { RAKUTEN_APP_ID = '', RAKUTEN_ACCESS_KEY = '', YAHOO_APP_ID = '' } = process.env;
const RAKUTEN_EP = process.env.RAKUTEN_ENDPOINT || 'https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701';
const YAHOO_EP = 'https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch';
const DEFAULT_EXCLUDE = ['中古', 'ジャンク', '訳あり', 'レンタル', '交換用', '専用ケース', 'カバーのみ'];

const norm = (s) => String(s || '').normalize('NFKC').toLowerCase().replace(/\s+/g, '');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const hit = (name, must = [], exclude = []) => {
  const n = norm(name);
  return must.every((m) => n.includes(norm(m))) && ![...DEFAULT_EXCLUDE, ...exclude].some((x) => n.includes(norm(x)));
};

async function getJson(url, headers = {}) {
  for (let i = 0; i < 3; i++) {
    const res = await fetch(url, { headers: { 'User-Agent': 'daily-hack-shop/1.0', ...headers } });
    if (res.status === 429) { await sleep(3000 * (i + 1)); continue; }
    const text = await res.text();
    if (!res.ok) throw new Error(`HTTP ${res.status} ${text.slice(0, 160).replace(/[A-Za-z0-9_-]{24,}/g, '［伏せた］')}`);
    return JSON.parse(text);
  }
  throw new Error('HTTP 429 が続いた');
}

async function rakuten(q) {
  if (!RAKUTEN_APP_ID) return { skipped: 'RAKUTEN_APP_ID が無い' };
  const p = new URLSearchParams({ applicationId: RAKUTEN_APP_ID, keyword: q.keyword, hits: '30', availability: '1', formatVersion: '2', format: 'json' });
  if (RAKUTEN_ACCESS_KEY) p.set('accessKey', RAKUTEN_ACCESS_KEY);
  const j = await getJson(`${RAKUTEN_EP}?${p}`);
  const items = (j.Items || j.items || []).map((x) => x.Item || x);
  const ok = items.filter((x) => hit(x.itemName, q.must, q.exclude)).map((x) => {
    const pts = Math.floor(x.itemPrice * (x.pointRate || 1) / 100);
    return { name: x.itemName, itemUrl: x.itemUrl, price: x.itemPrice, postageIncluded: x.postageFlag === 0, pointRate: x.pointRate || 1,
      reviewAverage: x.reviewAverage || null, reviewCount: x.reviewCount || 0, shop: x.shopName, net: x.itemPrice - pts };
  }).sort((a, b) => a.net - b.net);
  return ok[0] ? { found: true, candidates: ok.length, ...ok[0] } : { found: false, candidates: 0, searched: items.length };
}

async function yahoo(q) {
  if (!YAHOO_APP_ID) return { skipped: 'YAHOO_APP_ID が無い' };
  const p = new URLSearchParams({ appid: YAHOO_APP_ID, query: q.keyword, results: '30', in_stock: 'true' });
  const j = await getJson(`${YAHOO_EP}?${p}`);
  const ok = (j.hits || []).filter((x) => hit(x.name, q.must, q.exclude)).map((x) => {
    const point = (x.point && x.point.amount) || 0;
    return { name: x.name, url: x.url, price: x.price, shippingFree: x.shipping ? x.shipping.code === 2 : null, point,
      reviewAverage: (x.review && x.review.rate) || null, reviewCount: (x.review && x.review.count) || 0, shop: x.seller && x.seller.name, net: x.price - point };
  }).sort((a, b) => a.net - b.net);
  return ok[0] ? { found: true, candidates: ok.length, ...ok[0] } : { found: false, candidates: 0, searched: (j.hits || []).length };
}

const out = { generatedAt: new Date().toISOString(), keys: { rakuten: !!RAKUTEN_APP_ID, rakutenAccessKey: !!RAKUTEN_ACCESS_KEY, yahoo: !!YAHOO_APP_ID }, series: {}, errors: [] };
for (const f of fs.readdirSync(DIR).filter((x) => x.endsWith('.json') && x !== 'config.json').sort()) {
  const sid = f.replace(/\.json$/, '');
  const data = JSON.parse(fs.readFileSync(path.join(DIR, f), 'utf8'));
  out.series[sid] = {};
  for (const it of data.items || []) {
    const row = {};
    for (const [store, fn] of [['rakuten', rakuten], ['yahoo', yahoo]]) {
      const q = it[store];
      if (!q || !q.keyword) continue;
      try { row[store] = await fn(q); } catch (e) { row[store] = { error: String(e.message || e).slice(0, 200) }; out.errors.push(`${sid}/${it.id}/${store}: ${row[store].error}`); }
      await sleep(1100);
    }
    out.series[sid][it.id] = row;
  }
}
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out, null, 1) + '\n');
const n = Object.values(out.series).flatMap((s) => Object.values(s)).flatMap((r) => Object.values(r)).filter((x) => x.found).length;
console.log(`shop-prices: 当たり ${n} 件・エラー ${out.errors.length} 件 → ${OUT}`);
