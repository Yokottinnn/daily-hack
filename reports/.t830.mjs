import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 220000 - (Date.now() - t0);
const PAGES = [
  ['kararie-futon', 'https://www.irisohyama.co.jp/kararie/futon/'],
  ['fk-w3', 'https://www.irisohyama.co.jp/kararie/futon/fk-w3-product/'],
  ['fk-c5', 'https://www.irisohyama.co.jp/kararie/futon/fk-c5-product/'],
  ['support-fk-c5', 'https://www.irisohyama.co.jp/products/support/4967576773508'],
];
for (const [key, url] of PAGES) {
  if (left() < 20000) { console.log(`- ⏱ ${key} は時間切れ`); break; }
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3500);
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
    await p.waitForTimeout(1200);
    const title = await p.title();
    const text = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${title}\nURL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...new Set([...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /kararie\/futon|fk-|\.pdf/i.test(h)))].slice(0, 40));
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) })).filter((i) => i.src && i.w >= 500));
    console.log(`\n### ${key}（HTTP ${r ? r.status() : '?'}・「${title.slice(0, 60)}」・本文 ${text.length} 字・写真候補 ${imgs.length}）\n- URL: ${p.url()}`);
    for (const l of links) console.log(`  - link ${l}`);
    let n = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 12)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++n).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
