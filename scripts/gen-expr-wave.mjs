// expr-01-wave.png の「手だけ」を振るコマを作る（GIF の手を振る場面用・2026-10-03）。
//
//   FILL=1 node scripts/gen-expr-wave.mjs public/images/expr-01-wave.png <out-sprite.png> [コマ数=9] [振り幅°=18]
//
// 手だけを多角形で切り出した層を、手首を軸に回す。袖口は上に重ねて継ぎ目を隠す。
// 振り幅は髪に重なる向き（内側）を中心にする（外側へ振ると、手の後ろの髪にすき間ができる）。
// FILL=1 で、手を抜いた穴を右隣の髪のピンクで埋める（輪郭線の黒は拾わない）。
// 出力は横に並べたスプライト。HTML 側で background-position を steps(コマ数) で送る。
// 座標は 500px に縮めた expr-01-wave.png のもの。**ほかの絵には そのまま使えない**（手の位置が違う）
import sharp from 'sharp';
const [,, src, out, N = '9', DEG = '18'] = process.argv;
const { data, info } = await sharp(src).resize(500, 500).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
const W = info.width, H = info.height;
const ss = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const P = [108, 150], Hc = [68, 86];
const l = Math.hypot(Hc[0] - P[0], Hc[1] - P[1]), dH = [(Hc[0] - P[0]) / l, (Hc[1] - P[1]) / l];
const POLY = [[0, 26], [40, 12], [82, 16], [110, 28], [126, 54], [119, 100], [124, 140], [126, 172], [86, 176], [60, 142], [28, 124], [0, 104]];
function polyDist(x, y) {
  let inside = false, best = 1e9;
  for (let i = 0, j = POLY.length - 1; i < POLY.length; j = i++) {
    const [xi, yi] = POLY[i], [xj, yj] = POLY[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    const dx = xj - xi, dy = yj - yi, t = Math.max(0, Math.min(1, ((x - xi) * dx + (y - yi) * dy) / (dx * dx + dy * dy)));
    best = Math.min(best, Math.hypot(x - xi - t * dx, y - yi - t * dy));
  }
  return inside ? best : -best;
}
const th = (x, y) => (x - P[0]) * dH[0] + (y - P[1]) * dH[1];
// 手の層（元画像の座標）と、袖口（手首より下・多角形の中）
const hand = new Float32Array(W * H), cuff = new Float32Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const pd = polyDist(x, y), t = th(x, y), i = y * W + x;
  const inP = ss(-1, 1.5, pd);
  hand[i] = inP * ss(-4, -1, t);          // 手首より少し下から手の層に入れる（袖口の下に潜らせる）
  cuff[i] = inP * (1 - ss(-2, 2, t));     // 袖口は上に重ねる
}
// 下地: 手を抜いた穴は、右隣の髪を横へ伸ばして埋める（手の後ろにも髪は続いている）
const base = Buffer.from(data);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x;
  if (hand[i] < 0.02 || cuff[i] > 0.5) continue;
  let fill = null;
  for (let xx = x + 1; xx < Math.min(W, x + 60); xx++) {
    const j = y * W + xx;
    if (hand[j] < 0.02) { const r = data[j * 4], g = data[j * 4 + 1], b = data[j * 4 + 2]; if (process.env.FILL === '1' && data[j * 4 + 3] > 200 && r > 180 && g < 170 && b > 90 && r + g + b > 330) fill = j; break; }
  }
  const k = 1 - hand[i];
  if (fill !== null) { for (let c = 0; c < 4; c++) base[i * 4 + c] = data[i * 4 + c] * k + data[fill * 4 + c] * (1 - k); }
  else base[i * 4 + 3] = data[i * 4 + 3] * k;
}
const px = (buf, i) => [buf[i * 4], buf[i * 4 + 1], buf[i * 4 + 2], buf[i * 4 + 3] / 255];
function sampleHand(x, y) {
  const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0; const o = [0, 0, 0, 0];
  for (const [dx, dy, w] of [[0, 0, (1 - fx) * (1 - fy)], [1, 0, fx * (1 - fy)], [0, 1, (1 - fx) * fy], [1, 1, fx * fy]]) {
    const xx = x0 + dx, yy = y0 + dy; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
    const i = yy * W + xx, a = (data[i * 4 + 3] / 255) * hand[i];
    o[0] += data[i * 4] * a * w; o[1] += data[i * 4 + 1] * a * w; o[2] += data[i * 4 + 2] * a * w; o[3] += a * w;
  }
  return o[3] > 0 ? [o[0] / o[3], o[1] / o[3], o[2] / o[3], o[3]] : [0, 0, 0, 0];
}
const over = (top, bot) => { const a = top[3] + bot[3] * (1 - top[3]); if (a <= 0) return [0, 0, 0, 0];
  return [0, 1, 2].map((c) => (top[c] * top[3] + bot[c] * bot[3] * (1 - top[3])) / a).concat([a]); };
const n = +N, frames = [];
for (let k = 0; k < n; k++) {
  const a = (+DEG * Math.PI / 180) * (0.62 * Math.sin((2 * Math.PI * k) / n) + 0.38), s = Math.sin(-a), co = Math.cos(-a);
  const outBuf = Buffer.alloc(W * H * 4);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x;
    const sx = P[0] + co * (x - P[0]) - s * (y - P[1]), sy = P[1] + s * (x - P[0]) + co * (y - P[1]);
    let c = over(sampleHand(sx, sy), px(base, i));
    const cu = px(data, i); cu[3] *= cuff[i];
    c = over(cu, c);
    outBuf[i * 4] = c[0]; outBuf[i * 4 + 1] = c[1]; outBuf[i * 4 + 2] = c[2]; outBuf[i * 4 + 3] = Math.round(c[3] * 255);
  }
  frames.push(await sharp(outBuf, { raw: { width: W, height: H, channels: 4 } }).png().toBuffer());
}
await sharp({ create: { width: W * n, height: H, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } })
  .composite(frames.map((f, k) => ({ input: f, left: k * W, top: 0 }))).png().toFile(out);
console.log('sprite', out, n, 'frames');
