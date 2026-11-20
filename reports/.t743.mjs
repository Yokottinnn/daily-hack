import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const AFF = '587f2635.77bb335f.587f2636.e34c8733';
const hgc = (u) => `https://hb.afl.rakuten.co.jp/hgc/${AFF}/?pc=${encodeURIComponent(u)}&m=${encodeURIComponent(u)}`;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const L = [
  ['甲羅組 カット生ずわい', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('甲羅組 カット生ずわい蟹 特盛 1.8kg') + '/'],
  ['ますよね タラバ', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('ますよね タラバ 総重量1kg') + '/'],
  ['森源 ずわいポーション', 'https://search.rakuten.co.jp/search/mall/' + encodeURIComponent('森源商店 ずわい蟹 ポーション 1kg') + '/'],
];
for (const [k, u] of L) {
  try {
    await p.goto(hgc(u), { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const items = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href*="item.rakuten.co.jp/"]')].map((a) => (a.innerText || '').replace(/\s+/g, ' ').trim()).filter((t) => t.length > 15))].slice(0, 3));
    console.log(`- ${k}: 着いた先 **${p.url().split('?')[0]}** 「${(await p.title()).slice(0, 60)}」 商品 ${items.length} 件`);
    for (const t of items) console.log(`  - ${t.slice(0, 90)}`);
  } catch (e) { console.log(`- ⚠️ ${k}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
