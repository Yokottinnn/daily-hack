// 3 店ボタンの Amazon・楽天を「検索結果」ではなく「その商品のページ」へ飛ばすため、商品ページの候補を集める（2026-10-31 利用者が選んだ）。
// **読むだけ。カートに入れない・買わない。** Mac の Chrome（CDP）で検索結果を開き、1 件ずつの題名に must（型番）が全部入っていて
// exclude を含まないものを候補にする。Amazon は ASIN、楽天は item.rakuten.co.jp の商品 URL。候補の 1 件目の商品ページも開いて写真を残す。
// 使い方: SHOP_JSON=<src/data/shop/<シリーズ>.json> SERIES=<シリーズ> node find-product-pages.mjs   LLM 不使用・$0
// 出力: $OPS_REPORT_DIR/shop-pages/<シリーズ>/candidates.json と p-<商品 id>-<店>.jpg
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const PW_DIR = [path.join(os.homedir(), '.openclaw/workspace/node_modules'), path.join(os.homedir(), 'openclaw/node_modules')]
  .find((d) => fs.existsSync(path.join(d, 'playwright-core')));
if (!PW_DIR) { console.log('playwright-core が無い'); process.exit(0); }
const { chromium } = createRequire(path.join(PW_DIR, 'x.js'))('playwright-core');
const SERIES = process.env.SERIES || '';
const BUDGET = Number(process.env.FIND_BUDGET_MS || 230000);
const t0 = Date.now();
const OUT = path.join(process.env.OPS_REPORT_DIR || '/tmp', 'shop-pages', SERIES);
fs.mkdirSync(OUT, { recursive: true });
const data = JSON.parse(fs.readFileSync(process.env.SHOP_JSON, 'utf8'));
// fetch-prices.mjs と同じ除外語
const DEFAULT_EXCLUDE = ['中古', 'ジャンク', '訳あり', 'レンタル', '交換用', '専用ケース', 'カバーのみ', '変換ケーブル', '変換アダプター', '交換バッテリー'];

const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT || '18810'}`);
const ctx = b.contexts()[0] || (await b.newContext());
const pg = await ctx.newPage();
await pg.setViewportSize({ width: 1280, height: 900 }).catch(() => {});

const read = (store) => pg.evaluate((store) => {
  const out = [];
  if (store === 'amazon') {
    for (const e of document.querySelectorAll('[data-component-type="s-search-result"][data-asin]')) {
      const asin = e.getAttribute('data-asin'); if (!asin) continue;
      const title = ((e.querySelector('h2') || {}).innerText || '').trim();
      const price = ((e.querySelector('.a-price .a-offscreen') || {}).textContent || '').trim();
      out.push({ asin, title: title.slice(0, 200), price, sponsored: /スポンサー|Sponsored/.test(e.innerText) });
    }
  } else {
    const seen = new Set();
    for (const e of document.querySelectorAll('.searchresultitem, [class*="searchresultitem"]')) {
      const a = [...e.querySelectorAll('a[href]')].find((x) => /^https:\/\/item\.rakuten\.co\.jp\/[^/]+\/[^/?#]+\/?/.test(x.href));
      if (!a) continue;
      const url = a.href.match(/^https:\/\/item\.rakuten\.co\.jp\/[^/]+\/[^/?#]+\/?/)[0];
      if (seen.has(url)) continue; seen.add(url);
      const title = (a.getAttribute('title') || a.innerText || '').trim() || (e.innerText || '').split('\n').sort((x, z) => z.length - x.length)[0];
      const price = ((e.querySelector('[class*="price"]') || {}).innerText || '').split('\n')[0].trim();
      out.push({ url, title: title.slice(0, 200), price, ad: /^\s*\[PR\]/.test(e.innerText) });
    }
  }
  return out;
}, store);

const norm = (s) => String(s || '').normalize('NFKC').toLowerCase().replace(/[\s\-‐－]/g, '');
const result = { series: SERIES, generated: new Date().toISOString(), items: {} };
const lines = [`# 商品ページの候補: ${SERIES}（scripts/shop/find-product-pages.mjs・**$0**）`, '', `生成: **${result.generated}**`, ''];
for (const it of data.items || []) {
  if (Date.now() - t0 > BUDGET) { lines.push(`- ⚠️ 時間切れ（${it.id} から先は次の回）`); break; }
  const must = it.rakuten?.must || it.yahoo?.must || [];
  const exclude = [...DEFAULT_EXCLUDE, ...(it.rakuten?.exclude || [])];
  const ok = (t) => must.length && must.every((m) => norm(t).includes(norm(m))) && !exclude.some((x) => norm(t).includes(norm(x)));
  const row = {};
  lines.push(`## ${it.id}（must: ${must.join('・')}）`);
  for (const store of ['amazon', 'rakuten']) {
    const kw = it[store]?.keyword || it.rakuten?.keyword;
    if (!kw) continue;
    const url = store === 'amazon' ? `https://www.amazon.co.jp/s?k=${encodeURIComponent(kw)}` : `https://search.rakuten.co.jp/search/mall/${encodeURIComponent(kw)}/`;
    try {
      await pg.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await pg.waitForTimeout(3000);
      const all = await read(store);
      const hits = all.filter((x) => ok(x.title));
      row[store] = { searched: all.length, hits: hits.slice(0, 8) };
      lines.push(`- ${store}: 検索 ${all.length} 件・型番あり ${hits.length} 件`);
      for (const h of hits.slice(0, 4)) lines.push(`  - ${h.asin || h.url}｜${h.price || '—'}${h.sponsored || h.ad ? '｜広告枠' : ''}｜${h.title.slice(0, 80)}`);
      // 1 件目（広告枠でないもの優先）の商品ページを開いて写真を残す
      const top = hits.find((x) => !x.sponsored && !x.ad) || hits[0];
      if (top) {
        await pg.goto(store === 'amazon' ? `https://www.amazon.co.jp/dp/${top.asin}` : top.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await pg.waitForTimeout(3000);
        const pv = await pg.evaluate(() => ({ title: document.title.slice(0, 120), cart: /カートに入れる|今すぐ買う/.test(document.body.innerText || ''), h1: ((document.querySelector('h1') || {}).innerText || '').slice(0, 120) }));
        row[store].top = { ...top, page: pv };
        await pg.screenshot({ path: path.join(OUT, `p-${it.id}-${store}.jpg`), type: 'jpeg', quality: 55 }).catch(() => {});
        lines.push(`  - 開いた: ${pv.h1 || pv.title}｜カート: ${pv.cart ? 'あり' : '**無い**'}`);
      }
    } catch (e) {
      row[store] = { error: String(e).split('\n')[0].slice(0, 200) };
      lines.push(`- ${store}: ⚠️ ${row[store].error}`);
    }
  }
  result.items[it.id] = row;
  lines.push('');
}
await pg.close().catch(() => {});
fs.writeFileSync(path.join(OUT, 'candidates.json'), JSON.stringify(result, null, 1));
fs.writeFileSync(path.join(OUT, 'report.md'), lines.join('\n'));
console.log(lines.slice(0, 4).join('\n'));
console.log(`商品 ${(data.items || []).length} 件 / 調べた ${Object.keys(result.items).length} 件`);
process.exit(0);
