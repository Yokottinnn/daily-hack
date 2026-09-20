// **横はみ出しを幅ごとに見る。**
//
// スマホ幅だけ見て「大丈夫」と言っていたら、**881〜1150px でナビが 137px
// はみ出していた**（2026-09-20）。タブレット横（1024px）とノートの狭い画面が
// 丸ごとその帯に落ちていて、**記事ページだけでなく全ページで**起きていた。
//
//   npm run build && npx http-server dist -p 4321 -s &
//   node scripts/check-widths.mjs
//
// playwright-core が無ければ: npm i --no-save playwright-core
import { chromium } from 'playwright-core';
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
let bad = 0;
for (const w of [360, 390, 414, 768, 900, 1000, 1024, 1100, 1150, 1200, 1440]) {
  const p = await b.newPage({ viewport: { width: w, height: 900 } });
  await p.goto('http://127.0.0.1:4321/', { waitUntil: 'load' });
  const top = await p.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  await p.goto('http://127.0.0.1:4321/posts/wangan-festivals-2026/', { waitUntil: 'load' });
  const post = await p.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  if (top > 2 || post > 2) { bad++; console.log(`⚠️ ${w}px: トップ ${top} / 記事 ${post}`); }
  await p.close();
}
console.log(bad ? `要確認 ${bad} 幅` : 'どの幅でもはみ出しなし');
await b.close();
