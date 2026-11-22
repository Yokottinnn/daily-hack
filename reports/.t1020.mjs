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
// 1) Withings（日本）: 体重計の一覧から Body Smart・Body Comp・Body Scan などの製品ページを拾って読む
const wl = await read('withings-scales', 'https://www.withings.com/jp/ja/scales', { imgs: 0 });
const wdet = [...new Map(wl.filter((l) => /withings\.com\/jp\/ja\/(body|scale)/i.test(l.h) && !/scales$/.test(l.h)).map((l) => [l.h, l])).values()];
console.log(`\n- Withings の製品ページ候補 ${wdet.length} 件`); for (const l of wdet.slice(0, 30)) console.log(`  - ${l.t} — ${l.h}`);
const wpick = [];
for (const name of ['body-smart', 'body-comp', 'body-scan']) { const l = wdet.find((x) => x.h.toLowerCase().endsWith('/' + name)); wpick.push(l ? l.h : `https://www.withings.com/jp/ja/${name}`); }
let i = 0; for (const h of wpick) await read(`withings-${++i}`, h, { imgs: 5 });
// 2) エレコム: 体組成計の検索結果から HCS- の製品ページを拾って読む（エクリア）
const el = [];
for (const [k, u] of [['elecom-s1', 'https://www.elecom.co.jp/search/?q=%E4%BD%93%E7%B5%84%E6%88%90%E8%A8%88'], ['elecom-s2', 'https://www.elecom.co.jp/search/?q=HCS-WFS']]) el.push(...await read(k, u, { imgs: 0 }));
const edet = [...new Map(el.filter((l) => /\/products\/HCS-/i.test(l.h)).map((l) => [l.h.split('?')[0], l])).values()];
console.log(`\n- エレコムの製品ページ候補 ${edet.length} 件`); for (const l of edet.slice(0, 30)) console.log(`  - ${l.t} — ${l.h}`);
const epick = edet.filter((l) => /WFS|BTFS|FS/i.test(l.h)).slice(0, 3).map((l) => l.h);
if (!epick.length) epick.push('https://www.elecom.co.jp/products/HCS-WFS03WH.html', 'https://www.elecom.co.jp/products/HCS-WFS03BK.html');
let j = 0; for (const h of epick) await read(`elecom-${++j}`, h, { imgs: 5 });
// 3) ロゴ: 各社のトップのヘッダーにある logo の画像（img・svg）を取る
for (const [k, u] of [['withings', 'https://www.withings.com/jp/ja/'], ['elecom', 'https://www.elecom.co.jp/'], ['tanita', 'https://www.tanita.co.jp/']]) {
  if (left() < 12000) break;
  try {
    await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 30000 }); await p.waitForTimeout(3000);
    const cands = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('header img, img[src*="logo" i], img[alt*="logo" i], img[class*="logo" i], a[class*="logo" i] img')) out.push({ s: im.currentSrc || im.src, alt: im.alt || '', w: im.naturalWidth, h: im.naturalHeight });
      const svg = document.querySelector('header svg, a[class*="logo" i] svg, [class*="logo" i] svg');
      return { imgs: out.slice(0, 6), svg: svg ? svg.outerHTML.slice(0, 60000) : '' };
    });
    console.log(`\n- ロゴ ${k}: img ${cands.imgs.length} / svg ${cands.svg.length} 文字`);
    let n = 0;
    for (const c of cands.imgs) {
      if (!c.s || n >= 3) continue;
      try { const r = await ctx.request.get(c.s, { headers: { Referer: u }, timeout: 15000 }); const buf = await r.body(); const ct = r.headers()['content-type'] || ''; const ext = /svg/.test(ct) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg'; n++; fs.writeFileSync(`${D}/img/logo-${k}-${n}.${ext}`, buf); console.log(`  - logo-${k}-${n}.${ext} ${c.w}x${c.h} 「${c.alt}」 ${c.s.slice(0, 140)}`); } catch (e) { console.log(`  - ⚠️ ${String(e).slice(0, 80)}`); }
    }
    if (cands.svg) { fs.writeFileSync(`${D}/img/logo-${k}-inline.svg`, cands.svg); console.log(`  - logo-${k}-inline.svg`); }
  } catch (e) { console.log(`- ロゴ ${k} ⚠️ ${String(e).slice(0, 100)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
