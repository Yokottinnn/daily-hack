// **ロゴを入れた記事を全部 開いて、壊れた画像とはみ出しを探す。**
//
// 目で見るだけでは見つからないものを機械で拾う。実際に 2 つ見つけた（2026-09-20）。
//   - **h4 のロゴだけ高さ 89px** … CSS が h2/h3 を決め打ちしていた
//   - **囲み忘れたセルで 512px のアイコンが素の大きさ**
//
// **スマホ幅（390px）で見る。** 横はみ出しはここでしか出ない。
//
//   npm run build && npx http-server dist -p 4321 -s &
//   node scripts/check-logos.mjs
//
// playwright-core が無ければ: npm i --no-save playwright-core
import { chromium } from 'playwright-core';
import fs from 'node:fs';
const slugs = fs.readdirSync('public/images')
  .filter(d => fs.existsSync(`public/images/${d}/logos`));
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const p = await b.newPage({ viewport: { width: 390, height: 844 } });  // スマホ幅で見る
let bad = 0;
for (const s of slugs) {
  await p.goto(`http://127.0.0.1:4321/posts/${s}/`, { waitUntil: 'load' });
  await p.evaluate(() => { document.querySelectorAll('img[loading="lazy"]').forEach(i => i.loading = 'eager'); });
  await p.waitForFunction(() => Array.from(document.images).every(i => i.complete), null, { timeout: 20000 }).catch(() => {});
  const r = await p.evaluate(() => {
    const logos = Array.from(document.querySelectorAll('.brand-logo, .brand-logo-sm, .brand-logo-xs'));
    const broken = logos.filter(i => i.complete && i.naturalWidth === 0).map(i => i.getAttribute('src'));
    const huge = logos.filter(i => i.getBoundingClientRect().height > 60)
      .map(i => `${i.getAttribute('src')} h=${Math.round(i.getBoundingClientRect().height)}`);
    const overflow = document.documentElement.scrollWidth > window.innerWidth + 2
      ? document.documentElement.scrollWidth : 0;
    return { n: logos.length, broken, huge, overflow };
  });
  const flag = r.broken.length || r.huge.length || r.overflow;
  if (flag) bad++;
  console.log(`${flag ? '⚠️' : '  '} ${s}: ロゴ ${r.n}` +
    (r.broken.length ? ` / 壊れ ${r.broken.length} ${r.broken.slice(0,2)}` : '') +
    (r.huge.length ? ` / 大きすぎ ${r.huge.slice(0,2)}` : '') +
    (r.overflow ? ` / 横はみ出し ${r.overflow}px` : ''));
}
console.log(`\n要確認: ${bad} / ${slugs.length} 本`);
await b.close();
