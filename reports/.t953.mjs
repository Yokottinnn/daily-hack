import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 228000 - (Date.now() - t0);
const seen = new Set();
async function dump(key, url) {
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(5000);
    for (let i = 1; i <= 6; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 6), i); await p.waitForTimeout(400); }
    // タブ・「もっと見る」を全部開く
    for (const re of ['製品仕様', 'ご使用方法', 'もっと見る', '仕様', '使い方']) {
      const n = await p.evaluate((re) => { let c = 0; for (const el of document.querySelectorAll('a,button,li,span,div,dt,summary,[role=tab]')) { const t = (el.innerText || '').trim(); if (t.length < 24 && t.includes(re)) { try { el.click(); c++; } catch {} } } return c; }, re);
      await p.waitForTimeout(1200);
      console.log(`- ${key}: 「${re}」を ${n} 個押した`);
    }
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `URL: ${p.url()}\n\n${txt.slice(0, 120000)}`);
    const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].map((im) => ({ s: im.currentSrc || im.src, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) })).filter((x) => x.s && x.w >= 300 && x.h >= 200 && x.w / x.h < 4));
    console.log(`\n### ${key}\n- 本文 ${txt.length} 文字 / 画像候補 ${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= 10) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|bnr|banner|category|cat10/i.test(im.s)) continue; got.add(im.s);
      try {
        const r = await ctx.request.get(im.s, { headers: { Referer: url }, timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${im.s.slice(0, 140)}`); continue; }
        const buf = await r.body(); const ct = r.headers()['content-type'] || '';
        const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg';
        n++; const f = `${key}-${n}.${ext}`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${im.w}x${im.h} ${buf.length}B 「${im.alt}」 ${im.s.slice(0, 160)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await dump('yaman-duo', 'https://www.ya-man.com/Form/Product/ProductDetail.aspx?shop=0&pid=yjfa1p&bid=yaman_tokyo_japan&cat=101');
// ヤーマンのプレスリリース（2026-11 ディープリフト デュオ）の画像
await dump('yaman-duo-pr', 'https://digitalpr.jp/r/145430');
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
