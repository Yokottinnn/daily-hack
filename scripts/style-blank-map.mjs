#!/usr/bin/env node
/**
 * style-blank-map.mjs — 国土地理院の「白地図(blank)」タイルを Daily Hack の配色に塗り替える。
 *
 * blank タイルは陸も海も白で、境界線だけが黒。そのままだと陸と海の区別が付かないので、
 * 白い領域を塗りつぶし探索して「海」を特定し、残った白を陸として着色する。
 * 境界線はピンクに置き換える。
 *
 * 線が 1px かつアンチエイリアスなので、閾値を緩めに取って線を太らせてから探索する
 * （隙間があると海の塗りが陸に漏れる）。
 *
 * 探索の開始点は既定で画像の四隅。ただし日本全体のような「四隅が海」の bbox でしか
 * 成立しない。関東のような内陸を含む範囲では、四隅が陸だったり、東京湾のように
 * 外洋と繋がる経路が bbox の外に出てしまって湾が陸色に塗られる。
 * その場合は --sea で海の座標を明示する（bbox の meta.json が必要）。
 *
 * Usage:
 *   node scripts/style-blank-map.mjs in.png out.png
 *   node scripts/style-blank-map.mjs in.png out.png --meta in.png.meta.json --sea 139.85,35.45 --sea 139.4,35.2
 */
import sharp from 'sharp';
import { readFile } from 'node:fs/promises';

const argv = process.argv.slice(2);
const [inPath, outPath] = argv.filter((a) => !a.startsWith('--') && !seaFlagValue(a));
function seaFlagValue(a) {
  const i = argv.indexOf(a);
  return i > 0 && (argv[i - 1] === '--sea' || argv[i - 1] === '--meta');
}
const metaPath = argv.includes('--meta') ? argv[argv.indexOf('--meta') + 1] : null;
const seaArgs = argv.reduce((acc, a, i) => (a === '--sea' ? [...acc, argv[i + 1]] : acc), []);

if (!inPath || !outPath) {
  console.error('usage: style-blank-map.mjs <in.png> <out.png> [--meta m.json --sea lon,lat ...]');
  process.exit(1);
}

const SEA = [0xfa, 0xf6, 0xf2]; // 生成りの背景（海）
const LAND = [0xfd, 0xe9, 0xd6]; // 淡いオレンジ（陸）
const LINE = [0xe8, 0xa8, 0xc0]; // 境界線のピンク

// これより暗い画素は「線」とみなす。緩めに取って線を繋げ、塗りの漏れを防ぐ。
const LINE_THRESHOLD = 235;

const img = sharp(inPath).ensureAlpha();
const { width, height } = await img.metadata();
const raw = await img.raw().toBuffer();

const N = width * height;
const isLine = new Uint8Array(N);
for (let i = 0; i < N; i++) {
  const p = i * 4;
  // グレースケール換算で判定（blank タイルは無彩色）
  const v = (raw[p] * 299 + raw[p + 1] * 587 + raw[p + 2] * 114) / 1000;
  if (v < LINE_THRESHOLD) isLine[i] = 1;
}

// 塗り開始点。既定は四隅、--sea があればその座標も加える。
const seeds = [0, width - 1, (height - 1) * width, height * width - 1];

if (seaArgs.length) {
  if (!metaPath) {
    console.error('--sea を使うときは --meta で bbox の meta.json を渡すこと');
    process.exit(1);
  }
  const meta = JSON.parse(await readFile(metaPath, 'utf8'));
  const mercY = (lat) => {
    const r = (lat * Math.PI) / 180;
    return Math.log(Math.tan(r) + 1 / Math.cos(r));
  };
  const yTop = mercY(meta.north);
  const yBottom = mercY(meta.south);
  for (const s of seaArgs) {
    const [lon, lat] = s.split(',').map(Number);
    const x = Math.round(((lon - meta.west) / (meta.east - meta.west)) * (width - 1));
    const y = Math.round(((yTop - mercY(lat)) / (yTop - yBottom)) * (height - 1));
    if (x < 0 || x >= width || y < 0 || y >= height) {
      console.error(`--sea ${s} が画像の外を指している`);
      process.exit(1);
    }
    const i = y * width + x;
    if (isLine[i]) {
      // 線の上を指すと 1px も塗られず、原因が分からないまま失敗するので落とす
      console.error(`--sea ${s} が境界線の上を指している。少しずらすこと`);
      process.exit(1);
    }
    seeds.push(i);
  }
}

// 海を塗りつぶし探索（線は壁として扱う）
const isSea = new Uint8Array(N);
const stack = [...seeds];
for (const s of seeds) if (!isLine[s]) isSea[s] = 1;
while (stack.length) {
  const i = stack.pop();
  if (isLine[i]) continue;
  const x = i % width;
  const y = (i / width) | 0;
  const neighbours = [];
  if (x > 0) neighbours.push(i - 1);
  if (x < width - 1) neighbours.push(i + 1);
  if (y > 0) neighbours.push(i - width);
  if (y < height - 1) neighbours.push(i + width);
  for (const j of neighbours) {
    if (!isSea[j] && !isLine[j]) {
      isSea[j] = 1;
      stack.push(j);
    }
  }
}

let land = 0;
for (let i = 0; i < N; i++) {
  const p = i * 4;
  const c = isLine[i] ? LINE : isSea[i] ? SEA : LAND;
  if (!isLine[i] && !isSea[i]) land++;
  raw[p] = c[0];
  raw[p + 1] = c[1];
  raw[p + 2] = c[2];
  raw[p + 3] = 255;
}

await sharp(raw, { raw: { width, height, channels: 4 } })
  .png({ compressionLevel: 9 })
  .toFile(outPath);

const pct = ((land / N) * 100).toFixed(1);
console.log(`wrote ${outPath} (${width}x${height}) 陸の占有率 ${pct}%`);
// 内陸を含む bbox なら 7 割前後になるのが普通。日本全体なら 1〜2 割。
// どちらにせよ数字だけでは判断できないので、生成物は必ず目視すること。
console.log('※ 陸／海の判定は塗りつぶし探索なので、必ず生成物を開いて湾や内海の色を確認すること。');
