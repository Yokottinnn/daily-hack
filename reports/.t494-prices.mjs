import { createRequire } from 'node:module';
const req = createRequire(process.env.PW_DIR + '/x.js');
const { chromium } = req('playwright-core');
const fs = await import('node:fs');
const b = await chromium.connectOverCDP(`http://127.0.0.1:${process.env.CDP_PORT}`);
const ctx = b.contexts()[0] || (await b.newContext());
const p = await ctx.newPage();
await p.setViewportSize({ width: 1280, height: 900 });
const DIR = process.env.SHOT_DIR; fs.mkdirSync(DIR, { recursive: true });
for (const [key, u] of [['bath', 'https://nac-duskin.com/duskin-bathcleaning/'], ['kitchen', 'https://nac-duskin.com/duskin-kitchencleaning/'], ['aircon', 'https://nac-duskin.com/duskin-acclean/'], ['toilet', 'https://nac-duskin.com/duskin-toiletcleaning/']]) {
  await p.goto(u, { waitUntil: 'domcontentloaded', timeout: 25000 }).catch(() => {});
  await p.waitForTimeout(3500);
  // 「料金プラン」の見出しから 2,400px ぶんを撮る（画像の中の料金を目で読む）
  const y = await p.evaluate(() => { const h = [...document.querySelectorAll('h1,h2,h3,h4,p,div,span')].find((e) => /^料金プラン$/.test((e.innerText || '').trim())); return h ? h.getBoundingClientRect().top + window.scrollY - 40 : -1; });
  const imgs = await p.evaluate(() => [...document.querySelectorAll('img')].filter((i) => /price|plan|ryokin|fee|menu/i.test(i.src + ' ' + i.alt)).map((i) => `${i.naturalWidth}x${i.naturalHeight} alt=${i.alt} ${i.src}`));
  console.log(`\n## ${key} ${u}\n- 料金プランの位置: ${y}`, ...imgs.slice(0, 12).map((x) => `\n- 画像 ${x}`));
  if (y < 0) continue;
  const H = await p.evaluate(() => document.documentElement.scrollHeight);
  for (let i = 0; i < 2; i++) {
    const top = Math.min(y + i * 1200, H - 1200);
    await p.screenshot({ path: `${DIR}/${key}-${i + 1}.png`, clip: { x: 0, y: top, width: 1280, height: 1200 }, fullPage: true }).catch((e) => console.log(`- ⚠️ 撮れない ${String(e).split('\n')[0]}`));
  }
  console.log(`- 撮った: ${key}-1.png・${key}-2.png`);
}
await p.close().catch(() => {});
process.exit(0);
