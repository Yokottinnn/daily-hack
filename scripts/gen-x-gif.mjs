// X の告知画像の「動く版」（GIF）を、CSS アニメーション付きの HTML から作る。
//
//   node scripts/gen-x-gif.mjs <html> <out.gif> [一辺 px=1080] [fps=12] [秒=3]
//
// **HTML 側の約束:** 動きはすべて CSS アニメーションで書き、周期は「秒」で割り切れる長さにする
// （3 秒なら 1.5s / 3s）。割り切れないと継ぎ目で飛ぶ。
// 撮り方: 全アニメーションを止め、currentTime を 1 コマずつ進めて撮る（実時間を待たないので速い・ずれない）。
// まとめるのは sharp（リポジトリに既にある）。**X の GIF は 15MB まで。** 1080・12fps・3 秒で約 6MB だった。
// HTML は画像・フォントと同じ階層に置く（file:// の下位リソース・x-post-images スキル §4）。
import { chromium } from 'playwright';
import sharp from 'sharp';
import fs from 'node:fs';
import path from 'node:path';

const [,, html, out, size = '1080', fps = '12', secs = '3'] = process.argv;
if (!html || !out) { console.error('usage: node scripts/gen-x-gif.mjs <html> <out.gif> [size] [fps] [secs]'); process.exit(1); }
const bundled = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const b = await chromium.launch(fs.existsSync(bundled) ? { executablePath: bundled } : {});
const p = await b.newPage({ viewport: { width: 1080, height: 1080 } });
await p.goto('file://' + path.resolve(html));
await p.evaluate(() => document.fonts.ready);
// **画像が読めたかを見る。** 読めないと灰色のまま黙って出る（x-post-images スキル §4）
if (!(await p.evaluate(() => [...document.images].every((i) => i.naturalWidth > 0)))) throw new Error('画像が読めていない: ' + html);
const n = Math.round(+fps * +secs);
await p.evaluate(() => document.getAnimations().forEach((a) => a.pause()));
const anims = await p.evaluate(() => document.getAnimations().length);
if (!anims) throw new Error('CSS アニメーションが 1 つも無い。静止画なら gen-x-cards.mjs か jpeg で撮る');
const frames = [];
for (let i = 0; i < n; i++) {
  const t = (i * 1000) / +fps;
  await p.evaluate((t) => document.getAnimations().forEach((a) => { a.currentTime = t; }), t);
  frames.push(await sharp(await p.screenshot({ type: 'png' })).resize(+size, +size).png().toBuffer());
}
await b.close();
const gif = await sharp(frames, { join: { animated: true } })
  .gif({ delay: Array(n).fill(Math.round(1000 / +fps)), loop: 0, effort: 10, colours: 256, dither: 0.6 })
  .toBuffer();
fs.writeFileSync(out, gif);
console.log(`${out}: ${n} コマ / アニメーション ${anims} 個 / ${(gif.length / 1048576).toFixed(2)} MB（X の上限 15 MB）`);
if (gif.length > 15 * 1048576) { console.error('**15 MB を超えた。一辺か fps を下げる**'); process.exit(1); }
