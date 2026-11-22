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
// 1) ダイソン: ヘアドライヤーの一覧 → Supersonic の製品ページ（最大 4）
const dl = await read('dyson-list', 'https://www.dyson.co.jp/hair-care/hair-dryers', { imgs: 0 });
const dprod = [...new Map(dl.filter((l) => /dyson\.co\.jp\/hair-care\/hair-dryers\/[^?]+/.test(l.h) && !/accessor|compare|support|filter/i.test(l.h)).map((l) => [l.h, l])).values()];
console.log(`\n- ダイソンの製品ページ候補 ${dprod.length} 件`); for (const l of dprod.slice(0, 20)) console.log(`  - ${l.t} — ${l.h}`);
const pick = [];
for (const re of [/nural.*shine|shine.*nural/i, /travel/i, /supersonic-r|supersonic r/i, /origin/i]) { const l = dprod.find((x) => re.test(x.h + ' ' + x.t) && !pick.includes(x)); if (l) pick.push(l); }
let i = 0; for (const l of pick) await read(`dyson-p${++i}`, l.h, { imgs: 5 });
// 2) ヤーマン: トップと検索からドライヤーの製品ページ（最大 3）
const yl = [...await read('yaman-top', 'https://www.ya-man.com/', { imgs: 0 }), ...await read('yaman-search', 'https://www.ya-man.com/shop/goods/search.aspx?keyword=%E3%83%89%E3%83%A9%E3%82%A4%E3%83%A4%E3%83%BC', { imgs: 0 })];
const yprod = [...new Map(yl.filter((l) => /ya-man\.com/.test(l.h) && /(dryer|YJHC|ドライヤー)/i.test(l.h + ' ' + l.t)).map((l) => [l.h, l])).values()];
console.log(`\n- ヤーマンのドライヤー候補 ${yprod.length} 件`); for (const l of yprod.slice(0, 20)) console.log(`  - ${l.t} — ${l.h}`);
let j = 0; for (const l of yprod.filter((l) => /goods|product|item|detail|lp|brand/i.test(l.h)).slice(0, 3)) await read(`yaman-p${++j}`, l.h, { imgs: 5 });
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
