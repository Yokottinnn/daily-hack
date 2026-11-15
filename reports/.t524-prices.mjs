import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
const U = JSON.parse(fs.readFileSync(process.env.UJSON, 'utf8'));
const t0 = Date.now();
const seen = new Set();
async function dump(u, label, depth) {
  if (Date.now() - t0 > 205000 || seen.has(u)) return;
  seen.add(u);
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(3500);
  const d = await p.evaluate(() => {
    const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => x && x.length < 300);
    const links = [...document.querySelectorAll('article a[href], main a[href], .content a[href], a[href]')].map((a) => [a.innerText.trim().slice(0, 40), a.href]).filter(([, h]) => /city\.koto|city\.chuo|kayak|hobie|toyosu|omocha|おもちゃ|prtimes|\.lg\.jp|shimizu|bluesharks|wanganmatsuri|koto-wangan/i.test(h)).slice(0, 25);
    const imgs = [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 600).map((i) => `${i.naturalWidth}x${i.naturalHeight} ${i.currentSrc || i.src}`).slice(0, 8);
    return { title: document.title, url: location.href, t: t.slice(0, 110), links, imgs };
  }).catch(() => ({ title: '（読めない）', url: u, t: [], links: [], imgs: [] }));
  console.log(`\n## ${label}｜${d.title}\n- ${d.url}`);
  for (const x of d.t) console.log(`  - ${x}`);
  for (const [tx, h] of d.links) console.log(`  - リンク: ${tx} → ${h}`);
  for (const i of d.imgs) console.log(`  - 画像: ${i}`);
  if (depth > 0) for (const [, h] of d.links.filter(([, h]) => !/news\.google/.test(h)).slice(0, 2)) await dump(h, label + ' の先', depth - 1);
}
for (const [label, u] of U) await dump(u, label, 1);
await p.close().catch(() => {});
process.exit(0);
