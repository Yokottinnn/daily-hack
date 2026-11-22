import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 226000 - (Date.now() - t0);
async function read(key, url, wait = 4000) {
  if (left() < 12000) { console.log(`- ⏱ ${key} は時間切れ`); return []; }
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await p.waitForTimeout(wait);
    for (let i = 1; i <= 4; i++) { await p.evaluate((k) => window.scrollTo(0, document.body.scrollHeight * k / 4), i); await p.waitForTimeout(400); }
    // 「仕様」を開くボタンがあれば押す
    await p.evaluate(() => { for (const el of document.querySelectorAll('button,summary,a,[role=button]')) { const t = (el.innerText || '').trim(); if (/^(仕様|スペック|製品仕様|仕様・スペック|主な仕様)$/.test(t)) { try { el.click(); } catch {} } } });
    await p.waitForTimeout(1200);
    const ti = await p.title();
    const txt = await p.evaluate(() => document.body ? document.body.innerText : '');
    fs.writeFileSync(`${D}/${key}.txt`, `TITLE: ${ti}\nURL: ${p.url()}\n\n${txt.replace(/\n{3,}/g, '\n\n').slice(0, 30000)}`);
    const yen = [...new Set((txt.match(/[0-9,]{3,8}\s*円[^\n]{0,12}/g) || []))].slice(0, 8);
    console.log(`- ${key}: 「${ti.slice(0, 70)}」 ${p.url().slice(0, 110)} / 本文 ${txt.length} 字 / 円の表記 ${yen.join(' ｜ ')}`);
    return await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href.split('#')[0], t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })));
  } catch (e) { console.log(`- ⚠️ ${key}: ${String(e).slice(0, 140)}`); return []; }
}
console.log('## パナソニック（購入ページ → Store Plus）');
await read('pana-da49-shop', 'https://panasonic.jp/teeth/products/EW-DA49/shopping.html', 6000);
await read('pana-dt88-shop', 'https://panasonic.jp/teeth/products/EW-DT88/shopping.html', 6000);
const EC = 'https://ec-plus.panasonic.jp/store/ap/storeaez/a2A/ProductDetail?HB=';
for (const hb of ['EW-DA49-K', 'EW-DT88-K', 'EW0810-W', 'EW0800-W', 'EW0830', 'EW08304', 'EW0861-W']) await read(`ec-${hb}`, EC + hb);
console.log('\n## オムロン（公式の製品ページ）');
const ol = await read('omron-list', 'https://www.healthcare.omron.co.jp/product/toothbrush/');
const cand = [...new Map(ol.filter((l) => /healthcare\.omron\.co\.jp\/product\/toothbrush\/.+/i.test(l.h)).map((l) => [l.h, l])).values()];
console.log(`- 製品ページ候補 ${cand.length} 件`); for (const l of cand.slice(0, 30)) console.log(`  - ${l.t} — ${l.h}`);
let n = 0;
for (const re of [/b3221/i, /b318/i, /b3220/i]) {
  const l = cand.find((x) => re.test(x.h + ' ' + x.t));
  if (l) await read(`omron-p${++n}`, l.h); else console.log(`- 候補なし ${re}`);
}
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
