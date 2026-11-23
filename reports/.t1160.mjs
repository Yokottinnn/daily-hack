import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 2 });
const p = await ctx.newPage();
const pages = [
  ['benefit-main', 'https://www.city.koto.lg.jp/281000/kosodatesien/2026benefit.html'],
];
for (const [key, url] of pages) {
  try {
    const r = await p.goto(url, { waitUntil: 'load', timeout: 30000 });
    console.log(`- ${key}: HTTP ${r ? r.status() : '?'} ${url}`);
    await p.waitForTimeout(1500);
    // 本文の見出しの位置まで動かして、上 720px を撮る
    const h = await p.$('h1');
    if (h) { await h.scrollIntoViewIfNeeded(); await p.evaluate(() => window.scrollBy(0, -120)); }
    await p.screenshot({ path: `${D}/${key}-view.png` });
    const main = await p.$('#tmp_contents, #contents, main, #main');
    if (main) await main.screenshot({ path: `${D}/${key}-main.png` });
    console.log(`  - 撮った: ${key}-view.png${main ? ' / ' + key + '-main.png' : ''}`);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 200)}`); }
}
await ctx.close();
await b.close().catch(() => {});
