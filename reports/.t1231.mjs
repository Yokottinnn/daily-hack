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
    await p.waitForTimeout(2500);
    const ls = await p.evaluate(() => [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 80) })));
    console.log(`- 開けた: ${url}（リンク ${ls.length}）`);
    return ls;
  } catch (e) { console.log(`- ⚠️ 開けない: ${url}: ${String(e).slice(0, 120)}`); return []; }
}
for (const u of ['https://swim.or.jp/', 'https://swim.or.jp/compe/', 'https://swim.or.jp/tournament/']) {
  if (left() < 60000) break;
  for (const l of await links(u)) {
    if (/ジャパンオープン|japan.?open|japanopen/i.test(l.t + ' ' + l.h) && /swim\.or\.jp/.test(l.h) && !seen.has(l.h)) { seen.add(l.h); cand.push(l); }
  }
}
console.log(`\n## 大会のページの候補（${cand.length}）`);
for (const c of cand.slice(0, 12)) console.log(`- ${c.t} — ${c.h}`);
for (const c of cand.slice(0, 4)) {
  if (left() < 25000) { console.log('- ⏱ 時間切れ'); break; }
  try {
    await p.goto(c.h, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await p.waitForTimeout(2500);
    const r = await p.evaluate(() => ({
      title: document.title,
      text: (document.querySelector('main') || document.body).innerText.replace(/\n{2,}/g, '\n').slice(0, 6000),
      links: [...document.querySelectorAll('a')].map((a) => ({ h: a.href, t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 60) })).filter((l) => /チケット|ticket|観戦|入場|中継|配信|要項|pdf/i.test(l.t + ' ' + l.h)).slice(0, 25),
      imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 500).map((i) => i.src).slice(0, 6),
    }));
    console.log(`\n## ${r.title}\n${c.h}\n\n\`\`\`text\n${r.text}\n\`\`\``);
    console.log('\n関係するリンク:');
    for (const l of r.links) console.log(`- ${l.t} — ${l.h}`);
    console.log('\n大きい画像:');
    for (const i of r.imgs) console.log(`- ${i}`);
  } catch (e) { console.log(`- ⚠️ 読めない ${c.h}: ${String(e).slice(0, 120)}`); }
}
await ctx.close().catch(() => {});
process.exit(0);
