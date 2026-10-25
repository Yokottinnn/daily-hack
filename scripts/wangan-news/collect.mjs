// 湾岸ニュースの話題を集める（読むだけ・LLM 不使用・$0）。
// 2026-10-24 利用者「湾岸ライフのページ配下に、とよすとのように湾岸関連のイベントやニュースをキュレーションしてまとめてほしい」。
// 毎朝のルーティン（docs/wangan-news-routine.md）がこれを走らせ、出てきた候補から記事にするものを選ぶ。
//
//   ① Google ニュースの検索 RSS（地名ごと・直近 2 日）… 話題を見つける入口。**記事の根拠にはしない**
//   ② PR TIMES の検索結果（地名ごと）… 会社が自分で出した一次情報。根拠に使える
//
// 記事に書くときは、必ず一次情報（プレスリリース・区や都のお知らせ・施設の公式）を開いて裏を取る。
// 競合のまとめサイト（とよすと など）は「話題があった」という合図にだけ使い、文も写真も使わない。
//
// 使い方: node scripts/wangan-news/collect.mjs [--out /path/candidates.json] [--days 2]
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const OUT = opt('--out', 'wangan-news-candidates.json');
const DAYS = Number(opt('--days', '2'));
const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');

// 湾岸の範囲は **中央区（晴海・勝どき・月島・佃・豊海）と江東区（豊洲・有明・東雲・辰巳・青海）だけ**。
// **港区（台場・芝浦・海岸・竹芝）と品川区（天王洲）は対象外**（2026-10-24 利用者「港区はほぼ対象外なので絶対に含めないで」）。
// 地名だけだと別の土地の同名に当たるので、紛らわしいものは語を足す
const AREAS = [
  { key: 'harumi', q: '晴海' }, { key: 'kachidoki', q: '勝どき' }, { key: 'tsukishima', q: '月島' },
  { key: 'tsukuda', q: '佃 中央区' }, { key: 'toyosu', q: '豊洲' },
  { key: 'ariake', q: '有明 江東区 OR 有明ガーデン OR 有明アリーナ' }, { key: 'shinonome', q: '東雲 江東区' },
  { key: 'tatsumi', q: '辰巳 江東区' }, { key: 'aomi', q: '青海 江東区' },
];
// 港区・品川区の話題を落とす。湾岸（中央区・江東区）の地名が一緒に出ていなければ、対象外として skip にする
const OUT_OF_AREA = /港区|お台場|台場|芝浦|竹芝|浜松町|海岸[一二三1-3]丁目|天王洲|品川区|高輪/;
const IN_AREA = /晴海|勝どき|月島|佃|豊海|豊洲|有明|東雲|辰巳|青海|中央区|江東区/;
// 話題の入口にだけ使う（文・写真を使わない）媒体。記事の根拠にしない
const REFERENCE_ONLY = /とよすと|toyosu\.tokyo|湾岸ナビ|号外NET|at tokyo bayside/i;
// 湾岸の生活と関係が薄い話題（事件・事故・訃報・相場など）。記事にしない
const SKIP = /逮捕|容疑|死亡|遺体|殺|事故で|火災|訃報|株価|決算短信|求人|採用情報|ホーチミン|豊洲市場の(?:相場|せり)/;
// 新しい話題ではないもの。ウォーカープラスの「＜画像3 / 20＞」は過去の記事の写真ページが日付だけ新しく出てくる（2012 年の記事まで混ざる）
const STALE = /\(@\w+\) on X$|^[＜<]?画像\s*\d+\s*\/\s*\d+[＞>]|の天気|天気・紫外線|中古車|入荷しました/;

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36';
async function get(url) {
  for (let i = 1; i <= 3; i++) {
    try {
      const r = await fetch(url, { headers: { 'user-agent': UA, 'accept-language': 'ja' }, signal: AbortSignal.timeout(30000) });
      if (r.ok) return await r.text();
      if (r.status < 500) return null;
    } catch { /* もう一度 */ }
    await new Promise((ok) => setTimeout(ok, 2000 * i));
  }
  return null;
}
const unesc = (s) => (s || '').replace(/<!\[CDATA\[|\]\]>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").trim();
const tag = (s, t) => unesc((s.match(new RegExp(`<${t}[^>]*>([\\s\\S]*?)</${t}>`)) || [])[1]);

// 既に記事にした一次情報の URL（湾岸ニュースの記事の references）。同じ話題を二度書かない
function coveredUrls() {
  const dir = path.join(ROOT, 'src/content/posts');
  const seen = new Set();
  for (const f of fs.readdirSync(dir)) {
    if (!f.endsWith('.md')) continue;
    const t = fs.readFileSync(path.join(dir, f), 'utf8');
    const fm = t.split('\n---')[0];
    if (!/湾岸ニュース/.test(fm)) continue;
    for (const m of fm.matchAll(/https?:\/\/[^"'\s,\]]+/g)) seen.add(m[0].replace(/[?#].*$/, ''));
  }
  return seen;
}

const items = [];
const errors = [];
const since = Date.now() - DAYS * 864e5;
for (const a of AREAS) {
  // ① Google ニュース
  const rss = await get(`https://news.google.com/rss/search?q=${encodeURIComponent(a.q + ` when:${DAYS}d`)}&hl=ja&gl=JP&ceid=JP:ja`);
  if (!rss) errors.push(`google:${a.key}`);
  for (const it of (rss || '').split('<item>').slice(1)) {
    const title = tag(it, 'title'); const source = tag(it, 'source'); const date = new Date(tag(it, 'pubDate'));
    if (!title || (date.getTime() && date.getTime() < since)) continue;
    items.push({ via: 'google', area: a.key, title: title.replace(new RegExp(`\\s-\\s${source.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), ''), source, date: date.toISOString(), url: tag(it, 'link') });
  }
  // ② PR TIMES
  const pr = await get(`https://prtimes.jp/main/action.php?run=html&page=searchkey&search_word=${encodeURIComponent(a.q.split(' ')[0])}`);
  if (!pr) errors.push(`prtimes:${a.key}`);
  for (const m of (pr || '').matchAll(/href="(\/main\/html\/rd\/p\/\d+\.\d+\.html)"[^>]*>([\s\S]*?)<\/a>/g)) {
    const text = unesc(m[2].replace(/<[^>]+>/g, ' ')).replace(/\s+/g, ' ');
    const dm = text.match(/(\d{4})年(\d{1,2})月(\d{1,2})日\s*(\d{1,2})時(\d{1,2})分/);
    const date = dm ? new Date(`${dm[1]}-${dm[2].padStart(2, '0')}-${dm[3].padStart(2, '0')}T${dm[4].padStart(2, '0')}:${dm[5]}:00+09:00`) : null;
    if (!date || date.getTime() < since) continue;
    items.push({ via: 'prtimes', area: a.key, title: text.replace(/\d{4}年\d{1,2}月\d{1,2}日.*$/, '').trim(), source: 'PR TIMES', date: date.toISOString(), url: 'https://prtimes.jp' + m[1] });
  }
  await new Promise((ok) => setTimeout(ok, 800));
}

// 同じ話題をまとめる（題名の先頭 24 字で重ねる）。PR TIMES を先に残す（一次情報）
const covered = coveredUrls();
const norm = (s) => s.replace(/[\s「」『』【】（）()！!？?・、。〜~：:]/g, '').slice(0, 24);
const byKey = new Map();
for (const it of items.sort((x, y) => (x.via === 'prtimes' ? -1 : 1) - (y.via === 'prtimes' ? -1 : 1))) {
  const k = norm(it.title);
  if (byKey.has(k)) { const o = byKey.get(k); if (!o.areas.includes(it.area)) o.areas.push(it.area); o.also.push({ source: it.source, url: it.url }); continue; }
  byKey.set(k, { ...it, areas: [it.area], also: [] });
}
const out = [...byKey.values()].map((it) => ({
  ...it,
  referenceOnly: REFERENCE_ONLY.test(it.source + ' ' + it.url),
  skip: SKIP.test(it.title) || STALE.test(it.title) || (OUT_OF_AREA.test(it.title) && !IN_AREA.test(it.title.replace(OUT_OF_AREA, ''))) || /tenki\.jp|ガリバー/.test(it.source) || undefined,
  covered: covered.has(it.url.replace(/[?#].*$/, '')) || undefined,
})).sort((x, y) => y.date.localeCompare(x.date));

const res = { generated: new Date().toISOString(), days: DAYS, total: out.length, errors, items: out };
fs.writeFileSync(OUT, JSON.stringify(res, null, 1));
JSON.parse(fs.readFileSync(OUT, 'utf8')); // 書いたものを読み直す（最上位ルール 13）
const usable = out.filter((x) => !x.skip && !x.covered);
console.log(`候補 ${out.length} 件（記事にできそう ${usable.length}・一次情報 ${usable.filter((x) => x.via === 'prtimes').length}）・取れなかった入口 ${errors.length}${errors.length ? '（' + errors.join(', ') + '）' : ''} → ${OUT}`);
