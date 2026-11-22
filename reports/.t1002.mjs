import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし（ログインを持ち込まない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
const seen = new Set();
async function save(key, im, url) {
  try {
    const r = await ctx.request.get(im, { headers: { Referer: url }, timeout: 15000 });
    if (!r.ok()) { console.log(`  - ✗ ${r.status()} ${im.slice(0, 120)}`); return null; }
    const buf = await r.body(); const ct = r.headers()['content-type'] || '';
    const ext = /svg/.test(ct) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : /avif/.test(ct) ? 'avif' : 'jpg';
    return { buf, ext };
  } catch (e) { console.log(`  - ⚠️ ${String(e).slice(0, 80)}`); return null; }
}
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|すべての仕様|技術仕様|詳細仕様|仕様・スペック|商品仕様|SPEC)/i.test(t) && t.length < 20) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.slice(0, 90000)}`);
    const links = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || a.getAttribute('aria-label') || a.querySelector('img')?.alt || '').replace(/\s+/g, ' ').trim().slice(0, 70) })));
    if (opt.logo) {
      // ヘッダーのロゴ（img・インライン svg）を丸ごと書き出す。選ぶのはクラウドで目で見てから
      const lg = await p.evaluate(() => {
        const out = [];
        for (const im of document.querySelectorAll('header img, img[class*=logo i], img[alt*=logo i], img[src*=logo i], [class*=logo i] img')) out.push({ k: 'img', s: im.currentSrc || im.src, alt: im.alt || '', w: im.naturalWidth, h: im.naturalHeight });
        for (const sv of document.querySelectorAll('header svg, [class*=logo i] svg, svg[class*=logo i]')) { const h = sv.outerHTML; if (h.length > 300 && h.length < 60000) out.push({ k: 'svg', html: h, cls: (sv.getAttribute('class') || '') + ' / ' + (sv.parentElement?.className || '') }); }
        const ic = document.querySelector('link[rel*=apple-touch-icon]'); if (ic) out.push({ k: 'img', s: ic.href, alt: 'apple-touch-icon' });
        return out;
      });
      let n = 0;
      for (const l of lg.slice(0, 10)) {
        n++;
        if (l.k === 'svg') { fs.writeFileSync(`${D}/logo/${key}-${n}.svg`, l.html); console.log(`  - logo svg ${key}-${n}.svg ${l.html.length}B (${String(l.cls).slice(0, 60)})`); continue; }
        const s = await save(key, l.s, url); if (!s) continue;
        fs.writeFileSync(`${D}/logo/${key}-${n}.${s.ext}`, s.buf); console.log(`  - logo img ${key}-${n}.${s.ext} ${l.w}x${l.h} 「${l.alt}」 ${l.s.slice(0, 140)}`);
      }
    }
    const imgs = await p.evaluate(() => {
      const out = [];
      for (const im of document.querySelectorAll('img')) { const s = im.currentSrc || im.src; if (s && im.naturalWidth >= 600) out.push({ s, w: im.naturalWidth, h: im.naturalHeight, alt: (im.alt || '').slice(0, 60) }); }
      const og = document.querySelector('meta[property="og:image"]'); if (og) out.unshift({ s: og.content, w: 0, h: 0, alt: 'og:image' });
      return out;
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 80)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅600以上）${imgs.length} 枚`);
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 5) || left() < 12000) break;
      if (got.has(im.s) || /logo|icon|sprite|badge|banner|bnr|bn\d/i.test(im.s)) continue; got.add(im.s);
      const s = await save(key, im.s, url); if (!s) continue;
      n++; const f = `${key}-${n}.${s.ext}`; fs.writeFileSync(`${D}/img/${f}`, s.buf);
      console.log(`  - img ${f} ${im.w}x${im.h} ${s.buf.length}B 「${im.alt}」 ${im.s.slice(0, 140)}`);
    }
    return links;
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
const uniq = (arr) => [...new Map(arr.map((l) => [l.h, l])).values()];
// デロンギ アイコナ 温度設定機能付き電気カフェケトル KBOE1260J（写真は JavaScript で出るのでクラウドから取れない）
await read('delonghi-kboe1260j', 'https://www.delonghi.com/ja-jp/p/aikona-kboe1260j-gy-aikona-%E6%B8%A9%E5%BA%A6%E8%A8%AD%E5%AE%9A%E6%A9%9F%E8%83%BD%E4%BB%98ki%E9%9B%BB%E6%B0%97kafueketoru-gurafuaitoburatsuku/KBOE1260J-GY.html?pid=0210400014', { imgs: 6 });
await read('delonghi-kboe1260j-w', 'https://www.delonghi.com/ja-jp/c/kettles', { imgs: 0 });
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
