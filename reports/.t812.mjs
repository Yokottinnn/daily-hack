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
  for (const i of imgs.slice(0, 12)) console.log(`  - img ${i.w}x${i.h} 「${i.a}」 ${i.s.slice(0, 200)}`);
  let saved = 0;
  for (const i of imgs) {
    if (saved >= max || left() < 8000) break;
    if (re && !re.test(i.s + ' ' + i.a)) continue;
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
async function dump(key, url, { clicks = [], imgs = 0, imgRe = null, links = null } = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return; }
  const p = await ctx.newPage();   // ページごとに開き直す（t810 で遷移が割り込まれたため）
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(4500);
    for (const c of clicks) {
      try {
        const loc = p.getByText(c, { exact: false });
        const n = await loc.count();
        for (let k = 0; k < Math.min(n, 30); k++) { await loc.nth(k).click({ timeout: 1500 }).catch(() => {}); }
        await p.waitForTimeout(800);
        console.log(`- クリック「${c}」 ${n} 件`);
      } catch (e) { console.log(`- クリック失敗「${c}」`); }
    }
    await p.evaluate(() => { document.querySelectorAll('details').forEach((d) => { d.open = true; }); });
    const ex = p.locator('[aria-expanded="false"]');
    const en = Math.min(await ex.count(), 40);
    for (let k = 0; k < en; k++) await ex.nth(k).click({ timeout: 800 }).catch(() => {});
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const body = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${body.slice(0, 90000)}`);
    console.log(`\n### ${key}（${ti.slice(0, 80)}）\n- URL: ${p.url()}\n- 本文 ${body.length} 文字（開閉 ${en} 件を開いた）`);
    if (links) {
      const ls = await p.evaluate(() => [...new Map([...document.querySelectorAll('a[href]')].map((a) => [a.href.split('#')[0], (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80)])).entries()]);
      for (const [h, t] of ls.filter(([h, t]) => links.test(h) || links.test(t)).slice(0, 20)) console.log(`  - リンク ${t} — ${h}`);
    }
    if (imgs) await saveImgs(p, key, imgs, imgRe);
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
  await p.close().catch(() => {});
}
async function pdf(key, url) {
  try {
    const r = await ctx.request.get(url, { timeout: 25000 });
    const buf = await r.body();
    fs.writeFileSync(`${D}/${key}.pdf`, buf);
    console.log(`- PDF ${key}: HTTP ${r.status()} ${buf.length} bytes ← ${url}`);
  } catch (e) { console.log(`- ⚠️ PDF ${key}: ${String(e).slice(0, 100)}`); }
}
await dump('dyson-pencilvac-fc', 'https://www.dyson.co.jp/vacuum-cleaners/powerbroom/pencilvac/fluffycones', { clicks: ['製品仕様', '最長運転時間は何分', 'ゴミを格納できますか', '簡単にゴミ捨て'] });
await dump('dyson-v12-dsa', 'https://www.dyson.co.jp/vacuum-cleaners/cordless/v12/detect-slim-absolute', { clicks: ['製品仕様'], imgs: 3 });
await dump('makita-cl287fd', 'https://www.makita.co.jp/product/detail/?&model=CL287FD', { imgs: 4 });
await dump('makita-news', 'https://www.makita.co.jp/news/', { links: /287|クリーナ/ });
await dump('iris-scd186p', 'https://www.irisohyama.co.jp/products/electrical-appliances/home-appliances/vacuum-cleaner/rechargeable-stick-cleaner/cleaner-stick-cordless-scd186p', { clicks: ['仕様', 'スペック'], imgs: 4 });
await pdf('iris-scd186p-manual-213781', 'https://www.irisohyama.co.jp/products/manual/pdf/213781.pdf');
await pdf('iris-scd186p-manual-213777', 'https://www.irisohyama.co.jp/products/manual/pdf/213777.pdf');
console.log(`\n---\n保存した画像 ${imgN} 枚`);
await ctx.close().catch(() => {});
process.exit(0);
