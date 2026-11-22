import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();
const p = await ctx.newPage();
async function save(url, name) {
  try {
    const r = await ctx.request.get(url, { timeout: 20000 });
    if (!r.ok()) { console.log(`  - ${name}: HTTP ${r.status()}`); return; }
    const buf = await r.body(); const ct = r.headers()['content-type'] || '';
    const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg';
    fs.writeFileSync(`${D}/${name}.${ext}`, buf);
    console.log(`  - 保存 ${name}.${ext}: ${buf.length} bytes — ${url}`);
  } catch (e) { console.log(`  - ${name}: ${String(e).slice(0, 80)}`); }
}
const PAGES = [
  ['iris4', 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/pressure-cooker/electric-pressure-cooker/electric-pressure-cooker-4.0l'],
  ['plaza', 'https://www.irisplaza.co.jp/index.php?KB=SEARCH&SEARCH_WORD=KPC-MB4-B'],
];
for (const [key, url] of PAGES) {
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 6; i++) { await p.evaluate((y) => window.scrollTo(0, document.body.scrollHeight * y / 6), i); await p.waitForTimeout(600); }
    console.log(`\n## ${key}「${(await p.title()).slice(0, 70)}」\n- URL: ${p.url()}`);
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const i of document.images) {
        const s = i.currentSrc || i.src || i.getAttribute('data-src') || '';
        if (!s || /\/news\//.test(s)) continue;
        out.push({ s, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 50) });
      }
      for (const el of document.querySelectorAll('[style*="background-image"]')) {
        const m = (el.getAttribute('style') || '').match(/url\(["']?([^"')]+)/); if (m) out.push({ s: new URL(m[1], location.href).href, w: 0, h: 0, a: 'bg' });
      }
      return out;
    });
    const seen = new Set(); const cand = [];
    for (const im of imgs) { if (seen.has(im.s)) continue; seen.add(im.s); if (/logo|icon|sns|btn|arrow|banner/i.test(im.s)) continue; if (im.w && im.w < 400) continue; cand.push(im); }
    console.log(`- 候補 ${cand.length} 枚（全 ${imgs.length}）`);
    let j = 0;
    for (const im of cand.slice(0, 14)) { j++; console.log(`  - ${key}-${j} ${im.w}x${im.h} 「${im.a}」 ${im.s}`); if (j <= 8) await save(im.s, `${key}-${j}`); }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
