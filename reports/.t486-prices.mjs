import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const PROGS = [['ユアマイスター', 's00000020962001', 'https://yourmystar.jp/'], ['ナックダスキン', 's00000023342001', ''], ['キレイユ', 's00000020635004', '']];
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
for (const [name, id, seed] of PROGS) {
  console.log(`\n## ${name}\n`);
  let home = seed;
  const d = await read(`https://media-console.a8.net/program/detail-partnered?programId=${id}`);
  const ext = d.links.filter((l) => /^https?:/.test(l.h) && !/a8\.net|a8\.co\.jp|google|twitter|facebook|line\.me/.test(l.h)).map((l) => l.h);
  console.log(`- A8 の詳細から見えた外部リンク: ${[...new Set(ext)].slice(0, 6).join(' / ') || '無し'}`);
  if (!home) home = ext[0] || '';
  if (!home) { console.log('- 公式サイトが分からない。ここで止める'); continue; }
  const top = await read(home);
  console.log(`### ${top.title}\n- ${top.url}`, ...top.yen.map((x) => `  - ${x}`));
  const host = new URL(top.url).host;
  const subs = [...new Map(top.links.filter((l) => SVC.test(l.t) && l.h.includes(host) && !l.h.includes('#')).map((l) => [l.h, l])).values()].slice(0, 9);
  console.log(`- 料金・メニューらしいリンク: ${subs.map((l) => `${l.t}=${l.h}`).join(' ／ ') || '無し'}`);
  for (const l of subs) {
    if (Date.now() - t0 > 215000) { console.log('- ⏱ 時間切れ'); break; }
    const s = await read(l.h);
    console.log(`\n### ${l.t}｜${s.title}\n- ${s.url}`, ...s.yen.map((x) => `  - ${x}`), ...s.imgs.map((x) => `  - 画像 ${x}`));
  }
}
await p.close().catch(() => {});
process.exit(0);
