import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PAGES = [['ナックダスキン', ['https://nac-duskin.com/duskin-acclean/', 'https://nac-duskin.com/duskin-bathcleaning/', 'https://nac-duskin.com/duskin-kitchencleaning', 'https://nac-duskin.com/duskin-toiletcleaning/', 'https://nac-duskin.com/duskin-homecleaning/']], ['キレイユ', ['https://kireiyu.com/', 'https://kireiyu.com/area/']], ['ミガクる', ['https://migxl.com/']]];
const SVC = /エアコン|浴室|お風呂|風呂釜|キッチン|レンジフード|換気扇|料金|価格|メニュー|まとめて|セット|トイレ|洗面/;
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
const t0 = Date.now();
const read = async (u) => {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(3000);
  return p.evaluate(() => ({
    url: location.href, title: document.title,
    yen: [...new Set((document.body.innerText || '').split('\n').map((x) => x.trim()).filter((x) => /[0-9０-９,，]+\s*円/.test(x) && x.length < 140))].slice(0, 70),
    links: [...document.querySelectorAll('a[href]')].map((a) => ({ t: (a.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 50), h: a.href })),
    imgs: [...document.querySelectorAll('img')].filter((i) => i.naturalWidth >= 600).map((i) => `${i.naturalWidth}x${i.naturalHeight} ${i.currentSrc || i.src}`).slice(0, 8),
  })).catch(() => ({ url: u, title: '（読めない）', yen: [], links: [], imgs: [] }));
};
for (const [name, urls] of PAGES) {
  console.log(`\n## ${name}\n`);
  const seen = new Set(urls);
  const queue = [...urls];
  let n = 0;
  while (queue.length && n < 9) {
    if (Date.now() - t0 > 70000 * (PAGES.findIndex((x) => x[0] === name) + 1)) { console.log('- ⏱ この社の持ち時間が切れた'); break; }
    const u = queue.shift(); n++;
    const s = await read(u);
    console.log(`\n### ${s.title}\n- ${s.url}`, ...s.yen.map((x) => `  - ${x}`), ...s.imgs.map((x) => `  - 画像 ${x}`));
    const host = new URL(s.url).host;
    for (const l of s.links) if (SVC.test(l.t) && l.h.includes(host) && !l.h.includes('#') && !seen.has(l.h) && seen.size < 14) { seen.add(l.h); queue.push(l.h); console.log(`  - リンク ${l.t}=${l.h}`); }
  }
}
await p.close().catch(() => {});
process.exit(0);
