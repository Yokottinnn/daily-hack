#!/usr/bin/env node
/**
 * gen-map-base.mjs — 国土地理院 (GSI) タイルを繋いで湾岸エリアのベース地図 PNG を生成する。
 *
 * 出典表記が必須: 「出典：国土地理院ウェブサイト (https://maps.gsi.go.jp/development/ichiran.html)」
 *
 * Usage:
 *   node scripts/gen-map-base.mjs --west 139.73 --south 35.61 --east 139.83 --north 35.68 \
 *     --zoom 15 --style pale --out public/images/wangan-map-base.png
 *
 * 生成物と一緒に <out>.meta.json に実 bbox を吐く。ピンの %座標 はこの bbox から計算する。
 */
import sharp from 'sharp';
import { writeFile } from 'node:fs/promises';

const argv = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? fallback : argv[i + 1];
};

const west = Number(arg('west'));
const south = Number(arg('south'));
const east = Number(arg('east'));
const north = Number(arg('north'));
const zoom = Number(arg('zoom', '15'));
const style = arg('style', 'pale');
const out = arg('out', 'public/images/wangan-map-base.png');

if ([west, south, east, north].some(Number.isNaN)) {
  console.error('need --west --south --east --north');
  process.exit(1);
}

const TILE = 256;
const n = 2 ** zoom;

// Web メルカトル: 経度/緯度 → タイル座標 (小数)
const lonToTileX = (lon) => ((lon + 180) / 360) * n;
const latToTileY = (lat) => {
  const r = (lat * Math.PI) / 180;
  return ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n;
};

const x0f = lonToTileX(west);
const x1f = lonToTileX(east);
const y0f = latToTileY(north);
const y1f = latToTileY(south);

const tx0 = Math.floor(x0f);
const tx1 = Math.floor(x1f);
const ty0 = Math.floor(y0f);
const ty1 = Math.floor(y1f);

const cols = tx1 - tx0 + 1;
const rows = ty1 - ty0 + 1;
const canvasW = cols * TILE;
const canvasH = rows * TILE;

console.log(`tiles ${cols}x${rows} (${canvasW}x${canvasH}px) z=${zoom} style=${style}`);

async function fetchTile(x, y) {
  const url = `https://cyberjapandata.gsi.go.jp/xyz/${style}/${zoom}/${x}/${y}.png`;
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(url);
    if (res.ok) return Buffer.from(await res.arrayBuffer());
    await new Promise((r) => setTimeout(r, 400 * (attempt + 1)));
  }
  // 海しかない領域はタイルが無い (404) ことがあるので白で埋める
  return sharp({
    create: { width: TILE, height: TILE, channels: 3, background: '#ffffff' },
  })
    .png()
    .toBuffer();
}

const jobs = [];
for (let ty = ty0; ty <= ty1; ty++) {
  for (let tx = tx0; tx <= tx1; tx++) {
    jobs.push(
      fetchTile(tx, ty).then((input) => ({
        input,
        left: (tx - tx0) * TILE,
        top: (ty - ty0) * TILE,
      })),
    );
  }
}
const composites = await Promise.all(jobs);

// bbox ぴったりに切り出す
const cropLeft = Math.round((x0f - tx0) * TILE);
const cropTop = Math.round((y0f - ty0) * TILE);
const cropW = Math.round((x1f - x0f) * TILE);
const cropH = Math.round((y1f - y0f) * TILE);

// ⚠️ sharp は 1 パイプライン内で composite を extract より後に適用するため、
// 合成と切り出しを同じチェーンに書くとタイルが切り出し後のキャンバスに乗ってズレる。
// 必ず「合成 → バッファ化 → 別パスで切り出し」の 2 パスにすること。
const stitched = await sharp({
  create: { width: canvasW, height: canvasH, channels: 3, background: '#ffffff' },
})
  .composite(composites)
  .png()
  .toBuffer();

await sharp(stitched)
  .extract({ left: cropLeft, top: cropTop, width: cropW, height: cropH })
  .png({ compressionLevel: 9 })
  .toFile(out);

// 実 bbox (crop の丸め込み後) を書き戻す
const tileXToLon = (tileX) => (tileX / n) * 360 - 180;
const tileYToLat = (tileY) => {
  const m = Math.PI - 2 * Math.PI * (tileY / n);
  return (180 / Math.PI) * Math.atan(0.5 * (Math.exp(m) - Math.exp(-m)));
};
const meta = {
  zoom,
  style,
  width: cropW,
  height: cropH,
  west: tileXToLon(tx0 + cropLeft / TILE),
  east: tileXToLon(tx0 + (cropLeft + cropW) / TILE),
  north: tileYToLat(ty0 + cropTop / TILE),
  south: tileYToLat(ty0 + (cropTop + cropH) / TILE),
  attribution: '出典：国土地理院ウェブサイト',
};
await writeFile(`${out}.meta.json`, JSON.stringify(meta, null, 2));

console.log(`wrote ${out} (${cropW}x${cropH})`);
console.log(JSON.stringify(meta, null, 2));
