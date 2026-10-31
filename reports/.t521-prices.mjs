import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
const PAGES = [
  ['spu', 'https://event.rakuten.co.jp/campaign/point-up/everyday/point/'],
  ['marathon', 'https://event.rakuten.co.jp/campaign/point-up/marathon/'],
  ['marathon-guide', 'https://event.rakuten.co.jp/campaign/point-up/marathon/guide/'],
  ['pointday', 'https://event.rakuten.co.jp/campaign/card/pointday/'],
  ['sports', 'https://event.rakuten.co.jp/campaign/sports/'],
  ['supersale', 'https://event.rakuten.co.jp/campaign/supersale/'],
  ['top', 'https://www.rakuten.co.jp/'],
];
const t0 = Date.now();
for (const [key, u] of PAGES) {
  if (Date.now() - t0 > 200000) { console.log('- ⏱ 時間切れ'); break; }
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch((e) => console.log(`- ⚠️ 開けない ${u}: ${String(e).split('\n')[0]}`));
  await p.waitForTimeout(4000);
  const d = await p.evaluate(() => {
    const t = (document.body.innerText || '').split('\n').map((x) => x.trim()).filter(Boolean);
    // 個人の数字（「あなた」「現在の倍率」）は出さない
    const keep = t.filter((x) => /倍|%|％|上限|ポイント|エントリー|期間|条件|対象|付与|SPU/.test(x) && !/あなた|会員ランク|保有|現在の/.test(x) && x.length < 160);
    const alts = [...document.querySelectorAll('img[alt]')].map((i) => i.alt.trim()).filter((a) => /倍|最大|%/.test(a)).slice(0, 30);
    return { title: document.title, url: location.href, keep: [...new Set(keep)].slice(0, 140), alts: [...new Set(alts)] };
  }).catch(() => ({ title: '（読めない）', url: u, keep: [], alts: [] }));
  console.log(`\n## ${key}｜${d.title}\n- ${d.url}`, ...d.keep.map((x) => `\n  - ${x}`), ...d.alts.map((x) => `\n  - 画像 alt: ${x}`));
  await p.screenshot({ path: `${DIR}/${key}.png`, fullPage: false }).catch(() => {});
}
await p.close().catch(() => {});
process.exit(0);
