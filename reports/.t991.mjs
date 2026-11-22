import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D, TMPD = process.env.TMPD;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext();   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 200000 - (Date.now() - t0);
const BASE = 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/microwave-microwave-oven/steam-oven/';
const PAGES = [['ms-f2601', BASE + 'steam-oven-range-tank-type-26l'], ['ms-2402', BASE + 'steam-oven-range-tank-type-24l']];
for (const [key, url] of PAGES) {
  if (left() < 40000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(3000);
    // 「もっと読む」を全部押す
    const n = await p.evaluate(() => { let c = 0; for (const e of document.querySelectorAll('a,button,span,div')) { if ((e.innerText || '').trim() === 'もっと読む' && e.children.length === 0) { e.click(); c++; } } return c; });
    await p.waitForTimeout(1500);
    await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
    const text = await p.evaluate(() => (document.querySelector('main') || document.body).innerText);
    fs.writeFileSync(`${D}/${key}.txt`, `URL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\nもっと読む: ${n}\n\n${text.slice(0, 60000)}`);
    console.log(`\n## ${key}（HTTP ${r ? r.status() : '?'}・本文 ${text.length} 字・もっと読む ${n} 回）\n- URL: ${p.url()}`);
    const imgs = await p.evaluate(() => {
      const og = (document.querySelector('meta[property="og:image"]') || {}).content;
      const list = [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) }))
        .filter((i) => i.src && i.w >= 400 && !/\/news\//.test(i.src) && !/logo|banner|icon/i.test(i.src));
      if (og) list.unshift({ src: og, w: 0, h: 0, alt: 'og:image' });
      return list;
    });
    let k = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 8)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++k).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
    const pdfs = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => /\.pdf(\?|$)/i.test(h)));
    console.log(`- PDF のリンク ${pdfs.length} 件: ${pdfs.slice(0, 3).join(' ')}`);
    if (pdfs[0] && left() > 30000) {
      const res = await ctx.request.get(pdfs[0], { timeout: 60000 });
      const buf = await res.body();
      fs.writeFileSync(`${TMPD}/${key}.pdf`, buf);
      console.log(`- PDF ${buf.length}B（HTTP ${res.status()}）→ 手元に保存（公開しない）`);
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 160)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
