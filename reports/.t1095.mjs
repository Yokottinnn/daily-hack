import { createRequire } from 'node:module';
import fs from 'node:fs';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const D = process.env.D;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
// 1) CS-N210 の「仕様」「設定一覧」タブ（隠れているタブは innerText に出ないので textContent も取る）
try {
  await p.goto('https://www.cellstar.co.jp/products/recorder/cs/cs-n210.html', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(3000);
  for (const label of ['仕様', '設定一覧', 'ご購入前に']) {
    const clicked = await p.evaluate((label) => { for (const el of document.querySelectorAll('a,button,li,[role=tab]')) { if ((el.innerText || '').trim() === label) { el.click(); return true; } } return false; }, label);
    await p.waitForTimeout(1500);
    const txt = await p.evaluate(() => document.body.innerText);
    fs.writeFileSync(`${D}/cellstar-csn210-${label}.txt`, txt.slice(0, 60000));
    console.log(`- 「${label}」 押した: ${clicked} / 本文 ${txt.length} 文字`);
  }
  const all = await p.evaluate(() => { const m = document.querySelector('main') || document.body; return m.textContent.replace(/[ \t]+/g, ' ').replace(/\n\s*\n+/g, '\n'); });
  fs.writeFileSync(`${D}/cellstar-csn210-textContent.txt`, all.slice(0, 120000));
  console.log(`- textContent ${all.length} 文字`);
  const lines = all.split('\n').filter((l) => /付属|電源|コード|画角|画素|発売|水平|垂直|対角|シガー|消費/.test(l)).slice(0, 60);
  console.log('\n```text\n' + lines.join('\n').slice(0, 6000) + '\n```');
} catch (e) { console.log(`- ⚠️ CS-N210: ${String(e).slice(0, 140)}`); }
// 2) セルスターのお知らせから CS-N210 の発表を探す（発売日）
try {
  await p.goto('https://www.cellstar.co.jp/', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await p.waitForTimeout(2500);
  const news = await p.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim() })).filter((x) => /N210|新製品|ニュース|news|release/i.test(x.t + x.h)).slice(0, 30));
  console.log('\n- トップのお知らせ・新製品のリンク'); for (const n of news) console.log(`  - ${n.t.slice(0, 80)} — ${n.h}`);
  const hit = news.find((x) => /N210/.test(x.t + x.h));
  if (hit) {
    await p.goto(hit.h, { waitUntil: 'domcontentloaded', timeout: 25000 }); await p.waitForTimeout(2500);
    const t = await p.evaluate(() => document.body.innerText);
    fs.writeFileSync(`${D}/cellstar-news-n210.txt`, `URL: ${p.url()}\n\n` + t.slice(0, 30000));
    console.log(`- 開いた: ${p.url()}（${t.length} 文字）`);
  }
} catch (e) { console.log(`- ⚠️ お知らせ: ${String(e).slice(0, 140)}`); }
await ctx.close().catch(() => {});
console.log(`\n---\n経過 ${Math.round((Date.now() - t0) / 1000)} 秒`);
process.exit(0);
