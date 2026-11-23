import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const CONF = JSON.parse(fs.readFileSync(process.env.CONF, 'utf8'));
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const LIMIT = 225000;
const left = () => LIMIT - (Date.now() - t0);
const seen = new Set();
async function ddg(q) {
  try {
    await p.goto(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(q)}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await p.waitForTimeout(1500);
    return await p.evaluate(() => [...document.querySelectorAll('a.result__a')].map((a) => {
      let h = a.href; try { const u = new URL(h); if (u.searchParams.get('uddg')) h = u.searchParams.get('uddg'); } catch {}
      return { h, t: (a.innerText || '').trim().slice(0, 80) };
    }));
  } catch (e) { console.log(`- ⚠️ 検索失敗 ${q}: ${String(e).slice(0, 80)}`); return []; }
}
async function read(key, url, opt = {}) {
  if (left() < 15000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  if (seen.has(url)) return []; seen.add(url);
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,[role=button],[aria-expanded="false"]')) { const t = (el.innerText || '').trim(); if (/(仕様|スペック|製品仕様|すべての仕様|技術仕様|詳細|SPEC)/i.test(t) && t.length < 20) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1200);
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
    console.log(`\n### ${key}\n- 「${ti.slice(0, 90)}」 ${p.url()}\n- 本文 ${txt.length} 文字 / 画像（幅600以上）${imgs.length} 枚`);
    if (opt.logo) {
      const lg = await p.evaluate(() => {
        const out = [];
        for (const im of document.querySelectorAll('header img, img[src*="logo" i], img[alt*="logo" i], img[class*="logo" i]')) { const s = im.currentSrc || im.src; if (s) out.push({ s, alt: (im.alt || '').slice(0, 40), w: im.naturalWidth, h: im.naturalHeight }); }
        const svgs = [...document.querySelectorAll('header svg, [class*="logo" i] svg, a[href="/"] svg')].map((s) => s.outerHTML).filter((x) => x.length > 300 && x.length < 60000).slice(0, 2);
        return { imgs: out.slice(0, 4), svgs };
      });
      let k = 0;
      for (const im of lg.imgs) {
        try { const r = await ctx.request.get(im.s, { timeout: 10000 }); if (!r.ok()) continue; const buf = await r.body(); const ct = r.headers()['content-type'] || ''; const ext = /svg/.test(ct) ? 'svg' : /png/.test(ct) ? 'png' : /webp/.test(ct) ? 'webp' : 'jpg'; k++; fs.writeFileSync(`${D}/logo/${opt.logo}-${k}.${ext}`, buf); console.log(`  - logo ${opt.logo}-${k}.${ext} ${im.w}x${im.h} 「${im.alt}」 ${im.s.slice(0, 140)}`); } catch {}
      }
      lg.svgs.forEach((s, i) => { fs.writeFileSync(`${D}/logo/${opt.logo}-svg${i + 1}.svg`, s); console.log(`  - logo ${opt.logo}-svg${i + 1}.svg（インライン SVG ${s.length} 文字）`); });
    }
    let n = 0; const got = new Set();
    for (const im of imgs) {
      if (n >= (opt.imgs ?? 4) || left() < 12000) break;
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
const per = Math.floor(LIMIT / CONF.length);
for (const [ci, c] of CONF.entries()) {
  const until = (ci + 1) * per;
  const dom = new RegExp(c.dom, 'i'); const pick = new RegExp(c.pick, 'i');
  console.log(`\n## ${c.key}`);
  let cands = [];
  for (const q of c.q) {
    if (Date.now() - t0 > until - 30000) break;
    const r = (await ddg(q)).filter((x) => dom.test(x.h));
    console.log(`- 検索「${q}」→ 公式 ${r.length} 件`); for (const x of r.slice(0, 6)) console.log(`  - ${x.t} — ${x.h}`);
    cands.push(...r.map((x) => x.h));
  }
  cands = [...new Set([...c.direct, ...cands])];
  let i = 0, logoDone = false;
  const prod = cands.filter((h) => pick.test(decodeURIComponent(h)));
  const order = [...new Set([...prod, ...cands])];
  for (const h of order) {
    if (i >= 3 || Date.now() - t0 > until - 12000) break;
    const links = await read(`${c.key}-${++i}`, h, { imgs: 4, logo: logoDone ? null : c.key });
    logoDone = true;
    const more = [...new Map(links.filter((l) => dom.test(l.h) && pick.test(decodeURIComponent(l.h) + l.t)).map((l) => [l.h.split('?')[0], l])).values()];
    if (more.length) { console.log(`  - このページの製品リンク ${more.length} 件`); for (const l of more.slice(0, 15)) console.log(`    - ${l.t} — ${l.h}`); }
    for (const l of more.slice(0, 4)) if (!order.includes(l.h)) order.push(l.h);
  }
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
