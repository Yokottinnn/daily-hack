import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 }, locale: 'ja-JP' });   // Cookie なし（ログインしていない）
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
const PAGES = [
  ['kindle16', 'https://www.amazon.co.jp/Kindle-2026'],
  ['paperwhite', 'https://www.amazon.co.jp/Kindle-Paperwhite-2026'],
  ['colorsoft', 'https://www.amazon.co.jp/Kindle-Colorsoft-2026'],
  ['scribe', 'https://www.amazon.co.jp/kindlescribe2026'],
  ['kindle32', 'https://www.amazon.co.jp/Kindle-32GB'],
  ['pwse', 'https://www.amazon.co.jp/Kindle-Paperwhite-SE-2026'],
];
for (const [key, url] of PAGES) {
  if (left() < 25000) { console.log(`- ⏱ ${key} は時間切れ`); continue; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    const ti = await p.title();
    const fin = p.url();
    const asin = (fin.match(/\/dp\/([A-Z0-9]{10})/) || [])[1] || await p.evaluate(() => (document.querySelector('input#ASIN, input[name="ASIN"]') || {}).value || '');
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    // 箇条書き・選択肢（広告の有無・容量・色）・「技術仕様」以降だけを残す（ページ全体は出さない）
    const k = Math.max(txt.indexOf('技術仕様'), txt.indexOf('技術詳細'));
    const feat = await p.evaluate(() => { const e = document.querySelector('#feature-bullets'); return e ? e.innerText : ''; });
    const twister = await p.evaluate(() => [...document.querySelectorAll('#twister, #twister_feature_div, [id^="inline-twister"]')].map((e) => e.innerText).join('\n'));
    const spec = k >= 0 ? txt.slice(k, k + 9000) : '(技術仕様の見出しが見つからない)';
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${fin}\nASIN: ${asin}\n\n## 箇条書き\n${feat.slice(0, 5000)}\n\n## 選択肢\n${twister.slice(0, 3000)}\n\n## 仕様\n${spec}`);
    const imgs = await p.evaluate(() => {
      const out = [];
      const li = document.querySelector('#landingImage, #imgBlkFront');
      if (li) {
        if (li.getAttribute('data-old-hires')) out.push(li.getAttribute('data-old-hires'));
        const dyn = li.getAttribute('data-a-dynamic-image');
        if (dyn) { try { const o = JSON.parse(dyn); const best = Object.entries(o).sort((a, z) => z[1][0] - a[1][0])[0]; if (best) out.push(best[0]); } catch {} }
      }
      for (const s of document.querySelectorAll('script')) { const m = (s.textContent || '').match(/"hiRes":"(https:[^"]+)"/g); if (m) for (const x of m) out.push(x.slice(9, -1)); }
      return [...new Set(out)].slice(0, 6);
    });
    console.log(`\n### ${key}\n- 「${ti.slice(0, 100)}」 ${fin.slice(0, 120)}\n- ASIN: **${asin}** / 本文 ${txt.length} 文字 / 技術仕様 ${k >= 0 ? 'あり' : '無し'} / 写真候補 ${imgs.length}`);
    let n = 0;
    for (const s of imgs) {
      if (n >= 4 || left() < 15000) break;
      try {
        const r = await ctx.request.get(s, { timeout: 15000 });
        if (!r.ok()) { console.log(`  - img ✗ ${r.status()} ${s.slice(0, 100)}`); continue; }
        const buf = await r.body(); n++; const f = `${key}-${n}.jpg`; fs.writeFileSync(`${D}/img/${f}`, buf);
        console.log(`  - img ${f} ${buf.length}B ${s.slice(0, 120)}`);
      } catch (e) { console.log(`  - img ⚠️ ${String(e).slice(0, 80)}`); }
    }
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); }
}
await ctx.close().catch(() => {});
console.log(`\n---\n対象 ${PAGES.length} / 経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
