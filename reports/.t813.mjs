import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const t0 = Date.now();
const left = () => 235000 - (Date.now() - t0);
let imgN = 0;
async function saveImgs(p, key, max, re) {
  const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((i) => ({ s: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, a: (i.alt || '').slice(0, 60) })).filter((i) => i.w >= 400 && i.h >= 300 && /^https?:/.test(i.s)));
  const pick = imgs.filter((i) => !re || re.test(i.s + ' ' + i.a));
  console.log(`- 画像 ${imgs.length} 枚 / 条件に合う ${pick.length} 枚`);
  for (const i of pick.slice(0, 12)) console.log(`  - img ${i.w}x${i.h} 「${i.a}」 ${i.s.slice(0, 200)}`);
  let saved = 0;
  for (const i of pick) {
    if (saved >= max || left() < 8000) break;
    try {
      const r = await ctx.request.get(i.s, { timeout: 15000 });
      if (!r.ok()) continue;
      const buf = await r.body();
      const ct = r.headers()['content-type'] || '';
      const ext = ct.includes('png') ? 'png' : ct.includes('webp') ? 'webp' : 'jpg';
      const f = `${key}-${++saved}.${ext}`;
      fs.writeFileSync(`${D}/img/${f}`, buf); imgN++;
      console.log(`  - 保存 img/${f} ${buf.length} bytes ← ${i.s.slice(0, 160)}`);
    } catch (e) { console.log(`  - ⚠️ 画像失敗 ${String(e).slice(0, 80)}`); }
  }
}
// クリックはしない（t812 で開閉のクリックが別ページへの遷移を起こしたため）。HTML の中から語の前後を抜き出す。
async function dump(key, url, { grep = null, imgs = 0, imgRe = null, links = null, wait = 6000 } = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return; }
  const p = await ctx.newPage();
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(wait);
    await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await p.waitForTimeout(1500);
    const ti = await p.title();
    const body = await p.evaluate(() => document.body ? document.body.innerText : '');
    const html = await p.content();
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${body.slice(0, 90000)}`);
    console.log(`\n### ${key}（${ti.slice(0, 80)}）\n- URL: ${p.url()}\n- 本文 ${body.length} 文字 / HTML ${html.length} 文字`);
    if (grep) {
      const plain = html.replace(/<script[\s\S]*?<\/script>/g, (m) => m.replace(/\\u003c/g, '<')).replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ');
      const out = [];
      for (const w of grep) {
        let i = 0, n = 0;
        while ((i = plain.indexOf(w, i)) >= 0 && n < 4) { out.push(`[${w}] ${plain.slice(Math.max(0, i - 80), i + 160)}`); i += w.length; n++; }
      }
      fs.writeFileSync(`${D}/${key}-grep.txt`, out.join('\n'));
      console.log(`- 語の一致 ${out.length} 件（${key}-grep.txt）`);
      for (const o of out.slice(0, 14)) console.log(`  - ${o.slice(0, 240)}`);
    }
    if (links) {
      const ls = await p.evaluate(() => [...new Map([...document.querySelectorAll('a[href]')].map((a) => [a.href.split('#')[0], (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80)])).entries()]);
      for (const [h, t] of ls.filter(([h, t]) => links.test(h) || links.test(t)).slice(0, 20)) console.log(`  - リンク ${t} — ${h}`);
    }
    if (imgs) await saveImgs(p, key, imgs, imgRe);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
  await p.close().catch(() => {});
}
const G = ['質量', '重量', '運転時間', '充電時間', '本体寸法', 'kg'];
await dump('dyson-pencilvac-fc', 'https://www.dyson.co.jp/vacuum-cleaners/powerbroom/pencilvac/fluffycones', { grep: G });
await dump('dyson-v12-dsa', 'https://www.dyson.co.jp/vacuum-cleaners/cordless/v12/detect-slim-absolute', { grep: G });
await dump('makita-cl287fd', 'https://www.makita.co.jp/product/detail/?&model=CL287FD', { grep: ['質量', '連続使用', '集じん容量', '吸込仕事率', '発売', '標準価格', 'kg'], imgs: 4, imgRe: /287|CL287|product|detail/i, wait: 9000 });
await dump('makita-news', 'https://www.makita.co.jp/news/', { links: /287|クリーナ/, wait: 5000 });
await dump('iris-scd186p', 'https://www.irisohyama.co.jp/products/electrical-appliances/home-appliances/vacuum-cleaner/rechargeable-stick-cleaner/cleaner-stick-cordless-scd186p', { imgs: 4, imgRe: /186|scd|cleaner|stick/i });
console.log(`\n---\n保存した画像 ${imgN} 枚`);
await ctx.close().catch(() => {});
process.exit(0);
