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
const START = [
  ['search', 'https://www.irisohyama.co.jp/search/?q=%E9%A3%9F%E5%99%A8%E6%B4%97%E3%81%84%E4%B9%BE%E7%87%A5%E6%A9%9F'],
  ['cat1', 'https://www.irisohyama.co.jp/products/electrical-appliances/kitchen-appliances/dishwasher/'],
  ['cat2', 'https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/dishwasher/'],
];
const found = new Map();
async function grab(key, url, wantImgs) {
  const r = await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await p.waitForTimeout(3500);
  await p.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 900) { window.scrollTo(0, y); await new Promise((s) => setTimeout(s, 120)); } });
  await p.waitForTimeout(1000);
  const title = await p.title();
  const text = await p.evaluate(() => document.body ? document.body.innerText : '');
  fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${title}\nURL: ${p.url()}\nSTATUS: ${r ? r.status() : '?'}\n\n${text.slice(0, 90000)}`);
  const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })).filter((l) => /dishwasher|dish-washer|shokusen|食器洗|食洗/i.test(l.h + ' ' + l.t)));
  console.log(`\n### ${key}（HTTP ${r ? r.status() : '?'}・「${title.slice(0, 70)}」・本文 ${text.length} 字・食洗機らしいリンク ${links.length}）\n- URL: ${p.url()}`);
  for (const l of links.slice(0, 30)) console.log(`  - link ${l.t} — ${l.h}`);
  if (wantImgs) {
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || '').slice(0, 60) })).filter((i) => i.src && i.w >= 500 && !/\/news\//.test(i.src)));
    let n = 0;
    for (const im of [...new Map(imgs.map((i) => [i.src, i])).values()].slice(0, 8)) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 15000 });
        const buf = await res.body();
        const ext = (im.src.match(/\.(jpe?g|png|webp)/i) || ['', 'jpg'])[1].toLowerCase();
        const name = `${key}-${String(++n).padStart(2, '0')}.${ext}`;
        fs.writeFileSync(`${D}/img/${name}`, buf);
        console.log(`  - img ${name} ${im.w}x${im.h} ${buf.length}B alt「${im.alt}」 ${im.src}`);
      } catch (e) { console.log(`  - img ⚠️ ${im.src} ${String(e).slice(0, 80)}`); }
    }
  }
  return links;
}
for (const [key, url] of START) {
  if (left() < 30000) break;
  try {
    const links = await grab(key, url, false);
    for (const l of links) if (/irisohyama\.co\.jp\/products\//.test(l.h) && !/support|manual|\.pdf/.test(l.h)) found.set(l.h, l.t);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
console.log(`\n## 製品ページの候補 ${found.size} 件`);
let i = 0;
for (const [url] of [...found].slice(0, 6)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  try { await grab(`p${++i}`, url, true); } catch (e) { console.log(`- ⚠️ p${i}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
