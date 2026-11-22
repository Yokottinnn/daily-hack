import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const items = [
  ['シャープ KI-WX75', 'KI-WX75'], ['シャープ KI-WX70', 'KI-WX70'], ['シャープ KI-WS50', 'KI-WS50'],
  ['ダイキン MCK707A', 'MCK707A'], ['ダイキン MCK557A', 'MCK557A'],
  ['パナソニック F-VX70D', 'F-VX70D'], ['パナソニック F-VXW90', 'F-VXW90'],
];
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
let n = 0, ok = 0;
for (const [kw, model] of items) {
  for (const [shop, url] of [
    ['Yahoo!', `https://shopping.yahoo.co.jp/search?p=${encodeURIComponent(kw)}`],
    ['Amazon', `https://www.amazon.co.jp/s?k=${encodeURIComponent(kw)}&tag=dailyhack-22`],
  ]) {
    if (Date.now() - t0 > 105000) { console.log('- ⏱ 時間切れ'); break; }
    n++;
    try {
      const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await p.waitForTimeout(2500);
      const fin = p.url();
      const title = (await p.title()).slice(0, 60);
      const hits = await p.evaluate((m) => (document.body.innerText.match(new RegExp(m, 'g')) || []).length, model);
      const tagKept = shop === 'Amazon' ? /tag=dailyhack-22/.test(fin) : null;
      if (r && r.status() < 400 && hits > 0) ok++;
      console.log(`- ${shop} ${model}: HTTP ${r ? r.status() : '?'} / 型番 ${hits} 回 / ${tagKept === null ? '' : `tag ${tagKept ? '残る' : '**消えた**'} / `}着いた先 ${fin.slice(0, 110)} / 題名「${title}」`);
    } catch (e) { console.log(`- ${shop} ${model}: ⚠️ ${String(e).slice(0, 100)}`); }
  }
}
console.log(`\n対象 ${items.length * 2} / 開いた ${n} / 型番が出た ${ok}`);
await p.close().catch(() => {});
process.exit(0);
