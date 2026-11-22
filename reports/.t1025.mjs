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
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4500);
    for (let i = 1; i <= 6; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 6), i); await p.waitForTimeout(500); }
    // 「仕様」「スペック」を開くボタンがあれば押す
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|すべての仕様|技術仕様|詳細仕様|仕様・スペック|SPEC)/i.test(t) && t.length < 20) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1500);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || a.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('img')) { const s = im.currentSrc || im.src; if (s && im.naturalWidth >= 600) out.push({ s, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) }); }
      const og = document.querySelector('meta[property="og:image"]'); if (og) out.unshift({ s: og.content, w: 0, h: 0, alt: 'og:image' });
      return out;
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 80)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅600以上）${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 6) || left() < 12000) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|banner|bnr/i.test(im.s)) continue; got.add(im.s);
      try {
        const r = await ctx.request.get(im.s, { headers: { Referer: url }, timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${im.s.slice(0, 120)}`); continue; }
        const buf = await r.body(); const ct = r.headers()['content-type'] || '';
        const ext = /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /avif/.test(ct) ? 'avif' : 'jpg';
        n++; const f = `${key}-${n}.${ext}`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${im.w}x${im.h} ${buf.length}B 「${im.alt}」 ${im.s.slice(0, 140)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
    return links;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
// エレコムの画像は直接取ると 403 になるので、製品ページに表示された画像とロゴを要素ごとに撮る（画像そのものは変えない）
const p2 = await ctx.newPage();
await p2.setViewportSize({ width: 1366, height: 1000 });
for (const [key, url] of [['wh', 'https://www.elecom.co.jp/products/HCS-WFS03WH.html'], ['bk', 'https://www.elecom.co.jp/products/HCS-WFS03BK.html']]) {
  if (left() < 30000) break;
  try {
    await p2.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p2.waitForTimeout(4000);
    for (let i = 1; i <= 8; i++) { await p2.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 8), i); await p2.waitForTimeout(400); }
    await p2.evaluate(() => window.scrollTo(0, 0)); await p2.waitForTimeout(800);
    const n = await p2.evaluate(() => {
      let i = 0;
      for (const im of document.querySelectorAll('img')) {
        const s = im.currentSrc || im.src || '';
        const isLogo = /logo_elecom_01/.test(s);
        if ((/HCS-WFS03(WH|BK)_(01|31|33|35|36|39|42)\.jpg/i.test(s) && im.naturalWidth >= 400) || isLogo) { im.setAttribute('data-shot', String(i++)); }
      }
      return i;
    });
    console.log(`\n### ${key} ${url}\n- 撮る対象 ${n} 件`);
    const seen2 = new Set();
    for (let i = 0; i < n && i < 12; i++) {
      const el = await p2.$(`img[data-shot="${i}"]`);
      if (!el) continue;
      const info = await el.evaluate((im) => ({ s: im.currentSrc || im.src, w: im.naturalWidth, h: im.naturalHeight, alt: im.alt || '' }));
      const name = (info.s.split('/').pop() || `x${i}`).split('?')[0].replace(/\.(jpg|png|svg)$/i, '');
      if (seen2.has(name)) continue; seen2.add(name);
      try {
        const p3 = await ctx.newPage();
        const resp = await p3.goto(info.s, { referer: url, timeout: 20000 }).catch(() => null);
        const st = resp ? resp.status() : 0;
        if (resp && st === 200) { const buf = await resp.body(); const ext = /svg/.test(resp.headers()['content-type'] || '') ? 'svg' : 'jpg'; fs.writeFileSync(`${D}/img/elecom-${key}-${name}.${ext}`, buf); console.log(`  - elecom-${key}-${name}.${ext} 直接 ${buf.length}B ${info.w}x${info.h}`); await p3.close(); continue; }
        console.log(`  - ${name} 直接は ${st}。表示を撮る`); await p3.close();
      } catch (e) { console.log(`  - ${name} 直接 ⚠️ ${String(e).slice(0, 60)}`); }
      try {
        await el.scrollIntoViewIfNeeded(); await p2.waitForTimeout(500);
        const box = await el.boundingBox();
        if (!box || box.width < 20) { console.log(`  - ${name} 表示されていない`); continue; }
        await el.screenshot({ path: `${D}/img/elecom-${key}-${name}.png` });
        console.log(`  - elecom-${key}-${name}.png 元 ${info.w}x${info.h} 表示 ${Math.round(box.width)}x${Math.round(box.height)} 「${info.alt.slice(0, 50)}」`);
      } catch (e) { console.log(`  - ${name} ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 120)}`); }
}
await p2.close().catch(() => {});
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
