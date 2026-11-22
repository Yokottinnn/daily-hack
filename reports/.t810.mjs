import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 235000 - (Date.now() - t0);
const seenPages = new Set();
let imgN = 0;
async function dump(key, url, follow, max) {
  if (left() < 12000) { console.log(`- ⏱ ${key} は時間切れ`); return; }
  if (seenPages.has(url)) return; seenPages.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4000);
    await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 3));
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const body = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${body.slice(0, 70000)}`);
    const links = await p.evaluate(() => [...new Map([...document.querySelectorAll('a[href]')].map((a) => [a.href.split('#')[0], (a.innerText || a.title || '').replace(/\s+/g, ' ').trim().slice(0, 60)])).entries()]);
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ s: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 60) })).filter((i) => i.w >= 500 && i.h >= 300 && /^https?:/.test(i.s)));
    const og = await p.evaluate(() => (document.querySelector('meta[property="og:image"]') || {}).content || '');
    console.log(`\n### ${key}（${ti.slice(0, 80)}）\n- URL: ${p.url()}\n- 本文 ${body.length} 文字 / 大きい画像 ${imgs.length} 枚 / og:image ${og}`);
    for (const i of imgs.slice(0, 8)) console.log(`  - img ${i.w}x${i.h} 「${i.a}」 ${i.s.slice(0, 200)}`);
    if (follow) {
      const hit = links.filter(([h, t]) => follow.test(h) || follow.test(t));
      console.log(`- 一致したリンク ${hit.length} 件`);
      for (const [h, t] of hit.slice(0, 25)) console.log(`  - ${t} — ${h}`);
      let k = 0;
      for (const [h] of hit) {
        if (k >= max) break;
        if (/\.(pdf|jpg|png)$/i.test(h) || seenPages.has(h)) continue;
        k++; await dump(`${key}-p${k}`, h, null, 0);
      }
    } else {
      let saved = 0;
      for (const i of imgs) {
        if (saved >= 3 || left() < 8000) break;
        try {
          const r = await ctx.request.get(i.s, { timeout: 15000 });
          if (!r.ok()) continue;
          const buf = await r.body();
          const ct = r.headers()['content-type'] || '';
          const ext = ct.includes('png') ? 'png' : ct.includes('webp') ? 'webp' : 'jpg';
          const f = `${key}-${++saved}.${ext}`;
          fs.writeFileSync(`${D}/img/${f}`, buf);
          imgN++;
          console.log(`  - 保存 img/${f} ${buf.length} bytes ← ${i.s.slice(0, 160)}`);
        } catch (e) { console.log(`  - ⚠️ 画像失敗 ${String(e).slice(0, 80)}`); }
      }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await dump('dyson-cordless', 'https://www.dyson.co.jp/vacuum-cleaners/cordless', /pencilvac|v12-detect-slim|v12/i, 3);
await dump('shark-top', 'https://www.sharkninja.co.jp/', /lc702|boost|evopower|powerclean/i, 3);
await dump('makita-cleaner', 'https://www.makita.co.jp/product/cate/?&type=2&move=catm&catl=05&title=%E3%82%AF%E3%83%AA%E3%83%BC%E3%83%8A', /cl287|CL287/i, 2);
await dump('makita-news', 'https://www.makita.co.jp/news/', /287|クリーナ/i, 2);
await dump('iris-search', 'https://www.irisohyama.co.jp/search/?q=SCD-186P', /scd-?186|186p/i, 2);
await dump('iris-cleaner', 'https://www.irisohyama.co.jp/products/home-appliances/cleaner/', /scd-?186|186p|stick/i, 2);
console.log(`\n---\n保存した画像 ${imgN} 枚 / 開いたページ ${seenPages.size}`);
await ctx.close().catch(() => {});
process.exit(0);
