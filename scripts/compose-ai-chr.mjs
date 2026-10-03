// AI で作ったキャラの動画を、告知カードに重ねて GIF にする（2026-10-03・300 フォロワーで初めて作った）。
//
//   node scripts/compose-ai-chr.mjs <layer-bg.html と layer-ui.html のある dir> <キャラ動画のコマ dir（12fps の png）> <out.gif> [一辺=1080] [fps=12]
//
// 動画は Hugging Face の無料デモ（Lightricks/ltx-video-distilled）を **Mac から** 呼んで作る（ops/tasks/x212・x213）。
// クラウドから呼ぶと匿名の GPU 枠が大勢と共有で尽きている。Mac 側の枠は 1 日 3 本ほど。
// 入力は「カードの背景にキャラを置いた 640x640」（ops/data/x-cards/follower-300-grok/in-*.png）。
// 背景が同じなので、動画を戻すときに継ぎ目が出ない。文字・パネルは UI 層として上に重ねる（AI に描かせると崩れる）。
//
// 背景 → キャラ動画のコマ（640x640 を x0,y440 に・上と右の縁をぼかす）→ UI 層（CSS アニメ付き）の順に重ねて GIF / コマを作る
import { chromium } from 'playwright';
import sharp from 'sharp';
import fs from 'node:fs';
const [,, dir, framesDir, out, size = '1080', fps = '12', offsetMs = '1500'] = process.argv;
// offsetMs: UI の動きを途中から始める。**最初のコマは X の一覧に出る**ので、吹き出し・リボンが揃った時点から始める
const frames = fs.readdirSync(framesDir).filter((f) => f.endsWith('.png')).sort();
const n = frames.length;
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const p = await b.newPage({ viewport: { width: 1080, height: 1080 } });
await p.goto('file://' + dir + '/layer-bg.html'); await p.evaluate(() => document.fonts.ready);
const bg = await p.screenshot({ type: 'png' });
await p.goto('file://' + dir + '/layer-ui.html'); await p.evaluate(() => document.fonts.ready);
await p.evaluate(() => document.getAnimations().forEach((a) => a.pause()));
// キャラの縁をなじませるマスク（上 60px・右 60px をぼかす。下と左は画面の端）
const mask = Buffer.from(`<svg width="640" height="640"><defs>
 <linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000"/><stop offset="0.1" stop-color="#fff"/></linearGradient>
 <linearGradient id="r" x1="1" y1="0" x2="0" y2="0"><stop offset="0" stop-color="#000"/><stop offset="0.1" stop-color="#fff"/></linearGradient>
 <mask id="m"><rect width="640" height="640" fill="url(#t)"/></mask></defs>
 <rect width="640" height="640" fill="url(#r)" mask="url(#m)"/></svg>`);
const maskRaw = await sharp(mask).greyscale().raw().toBuffer();
const outFrames = [];
for (let i = 0; i < n; i++) {
  await p.evaluate((t) => document.getAnimations().forEach((a) => { a.currentTime = t; }), (i * 1000) / +fps + +offsetMs);
  const ui = await p.screenshot({ type: 'png', omitBackground: true });
  const vf = await sharp(framesDir + '/' + frames[i]).resize(640, 640).removeAlpha().raw().toBuffer();
  const rgba = Buffer.alloc(640 * 640 * 4);
  for (let k = 0; k < 640 * 640; k++) { rgba[k * 4] = vf[k * 3]; rgba[k * 4 + 1] = vf[k * 3 + 1]; rgba[k * 4 + 2] = vf[k * 3 + 2]; rgba[k * 4 + 3] = maskRaw[k]; }
  const chr = await sharp(rgba, { raw: { width: 640, height: 640, channels: 4 } }).png().toBuffer();
  const f = await sharp(bg).composite([{ input: chr, left: 0, top: 440 }, { input: ui, left: 0, top: 0 }]).resize(+size, +size).png().toBuffer();
  outFrames.push(f);
}
await b.close();
fs.mkdirSync(out + '.frames', { recursive: true });
outFrames.forEach((f, i) => fs.writeFileSync(`${out}.frames/${String(i).padStart(4, '0')}.png`, f));
const gif = await sharp(outFrames, { join: { animated: true } }).gif({ delay: Array(n).fill(Math.round(1000 / +fps)), loop: 0, effort: 10, colours: 256, dither: 0.6 }).toBuffer();
fs.writeFileSync(out, gif);
console.log(out, n, 'frames', (gif.length / 1048576).toFixed(2), 'MB');
