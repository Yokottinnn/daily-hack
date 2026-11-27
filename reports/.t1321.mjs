import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = await b.newContext({ viewport: { width: 1366, height: 900 } });   // Cookie なし
const p = await ctx.newPage();
const t0 = Date.now();
const left = () => 190000 - (Date.now() - t0);
const seen = new Set();
const cand = [];
async function links(url) {
  try {
    await p.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(3000);
    const ls = await p.evaluate(() => [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 100) })));
    console.log(`- 開けた: ${url}（リンク ${ls.length}・題名「${(await p.title()).slice(0, 60)}」）`);
    return ls;
  } catch (e) { console.log(`- ⚠️ 開けない: ${url}: ${String(e).slice(0, 120)}`); return []; }
}
for (const u of ['https://www.kotsu.metro.tokyo.jp/bus/', 'https://www.kotsu.metro.tokyo.jp/bus/news/', 'https://www.kotsu.metro.tokyo.jp/', 'https://www.kotsu.metro.tokyo.jp/news/']) {
  if (left() < 80000) break;
  for (const l of await links(u)) {
    if (/築地三丁目|築地/.test(l.t) && !seen.has(l.h)) { seen.add(l.h); cand.push(l); }
  }
}
console.log(`\n## お知らせの候補（${cand.length}）`);
for (const c of cand.slice(0, 12)) console.log(`- ${c.t} — ${c.h}`);
const pick = cand.filter((c) => /築地三丁目/.test(c.t)).concat(cand.filter((c) => !/築地三丁目/.test(c.t)));
for (const c of pick.slice(0, 3)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  if (/\.pdf($|\?)/i.test(c.h)) { console.log(`\n- PDF: ${c.h}（本文は読まない。URL だけ）`); continue; }
  try {
    await p.goto(c.h, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => ({
      title: document.title,
      text: (document.querySelector('main') || document.querySelector('#contents') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 6000),
      links: [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })).filter((l) => /pdf|地図|案内|のりば|築地/i.test(l.t + ' ' + l.h)).slice(0, 20),
      imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 300).map((i) => `${i.src}（${i.naturalWidth}x${i.naturalHeight}・alt「${(i.alt || '').slice(0, 60)}」）`).slice(0, 8),
    }));
    console.log(`\n## ${r.title}\n${c.h}\n\n\`\`\`text\n${r.text}\n\`\`\``);
    console.log('\n関係するリンク:');
    for (const l of r.links) console.log(`- ${l.t} — ${l.h}`);
    console.log('\n画像:');
    for (const i of r.imgs) console.log(`- ${i}`);
  } catch (e) { console.log(`- ⚠️ 読めない ${c.h}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
