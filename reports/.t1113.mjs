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
  ['kindle16', 'https://www.amazon.co.jp/dp/B0G4SL3W21'],
  ['paperwhite', 'https://www.amazon.co.jp/dp/B0GV5VHTL6'],
  ['colorsoft', 'https://www.amazon.co.jp/dp/B0GV62167S'],
  ['scribe', 'https://www.amazon.co.jp/dp/B0FC1PBJRB'],
];
const TABS = ['デザインのディテール', '測定値', 'ディスプレイ', 'パフォーマンス', '電源', '接続性', 'ソフトウェア', 'サービス', 'その他の詳細', '技術仕様', '仕様'];
let first = true;
for (const [key, url] of PAGES) {
  if (left() < 30000) { console.log(`- ⏱ ${key} は時間切れ`); continue; }
  if (!first) await p.waitForTimeout(20000);   // 続けて開くと確認画面になる（t1110）
  first = false;
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(4000);
    for (let i = 1; i <= 5; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 5), i); await p.waitForTimeout(400); }
    const ti = await p.title();
    const fin = p.url();
    if (/checkpoint|validateCaptcha/.test(fin)) { console.log(`\n### ${key}\n- ⚠️ 確認画面（${fin.slice(0, 60)}）。読めない`); continue; }
    const asin = (fin.match(/\/dp\/([A-Z0-9]{10})/) || [])[1] || '';
    let out = `TITLE: ${ti}\nURL: ${fin}\nASIN: ${asin}\n`;
    let got = 0;
    for (const lab of TABS) {
      const ok = await p.evaluate((lab) => {
        const els = [...document.querySelectorAll('a,button,li,span,div,[role=tab]')].filter((e) => (e.innerText || '').trim() === lab && e.offsetParent !== null);
        const e = els[els.length - 1]; if (!e) return false; e.scrollIntoView({ block: 'center' }); e.click(); return true;
      }, lab).catch(() => false);
      if (!ok) continue;
      await p.waitForTimeout(800);
      const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
      const s = txt.lastIndexOf('商品仕様'); const e = txt.indexOf('電子書籍リーダーの比較', s);
      const part = s >= 0 ? txt.slice(s, e > s ? Math.min(e, s + 4000) : s + 4000) : '';
      out += `\n## タブ: ${lab}\n${part}\n`; got++;
    }
    fs.writeFileSync(`${D}/${key}.txt`, out);
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
    console.log(`\n### ${key}\n- 「${ti.slice(0, 100)}」 ${fin.slice(0, 120)}\n- ASIN: **${asin}** / 押せたタブ ${got} / 写真候補 ${imgs.length}`);
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
