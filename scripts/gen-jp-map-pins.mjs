#!/usr/bin/env node
/**
 * gen-jp-map-pins.mjs — 施設リスト(JSON)を全国マップ上の % 座標に変換し、
 * .jp-pin（番号つきリンク）と .jp-legend（番号↔施設名の凡例）の HTML を吐く。
 *
 * ベース画像は gen-map-base.mjs + style-blank-map.mjs で作ったもの。
 * bbox は gen-map-base.mjs が書き出す <out>.meta.json を使う。
 *
 * 関東のように施設が密集する範囲は、拡大インセット側に逃がす。
 * --inset <inset-meta.json> を渡すと、その bbox に入る施設は本体マップから除外し、
 * インセット用の座標として別に出力する（同じ番号が2箇所に出るのを避けるため）。
 *
 * Usage:
 *   node scripts/gen-jp-map-pins.mjs <meta.json> <facilities.json> [--inset <meta.json>] [--legend]
 *
 * facilities.json の形:
 *   [{ "no":1, "name":"TOKYO-BAY", "lat":35.68, "lon":139.99, "url":"https://..." }]
 */
import { readFile } from 'node:fs/promises';

const argv = process.argv.slice(2);
const [metaPath, listPath] = argv.filter(
  (a, i) => !a.startsWith('--') && argv[i - 1] !== '--inset',
);
const withLegend = argv.includes('--legend');
const insetPath = argv.includes('--inset') ? argv[argv.indexOf('--inset') + 1] : null;
if (!metaPath || !listPath) {
  console.error('usage: gen-jp-map-pins.mjs <meta.json> <facilities.json> [--inset m.json] [--legend]');
  process.exit(1);
}

const meta = JSON.parse(await readFile(metaPath, 'utf8'));
const list = JSON.parse(await readFile(listPath, 'utf8'));
const inset = insetPath ? JSON.parse(await readFile(insetPath, 'utf8')) : null;

// Web メルカトルの y は緯度に対して線形でないので、y 方向も投影してから比率を取る
const mercY = (lat) => {
  const r = (lat * Math.PI) / 180;
  return Math.log(Math.tan(r) + 1 / Math.cos(r));
};
const fmt = (v) => v.toFixed(2);
// bbox 内での位置を % で返す
const project = (m) => {
  const yTop = mercY(m.north);
  const yBottom = mercY(m.south);
  return (lat, lon) => ({
    left: ((lon - m.west) / (m.east - m.west)) * 100,
    top: ((yTop - mercY(lat)) / (yTop - yBottom)) * 100,
  });
};
const inBox = (m, f) => f.lon >= m.west && f.lon <= m.east && f.lat >= m.south && f.lat <= m.north;

const toMain = project(meta);
const toInset = inset ? project(inset) : null;

const outside = [];
const pin = (f, xy, cls = '') =>
  `  <a class="jp-pin${cls}" style="left:${fmt(xy.left)}%;top:${fmt(xy.top)}%" href="${f.url}" target="_blank" rel="noopener" aria-label="${f.name}">${f.no}</a>`;

const insetPins = [];
const mainList = [];
const dot = (xy) => `  <span class="jp-dot" style="left:${fmt(xy.left)}%;top:${fmt(xy.top)}%"></span>`;
for (const f of list) {
  if (inset && inBox(inset, f)) {
    const xy = toInset(f.lat, f.lon);
    // インセット内は密集しないので反発は不要。ドットとバッジは同じ位置に重ねる。
    insetPins.push(dot(xy));
    insetPins.push(pin(f, xy));
    continue;
  }
  const xy = toMain(f.lat, f.lon);
  if (xy.left < 0 || xy.left > 100 || xy.top < 0 || xy.top > 100) {
    outside.push(`${f.no} ${f.name} (left=${fmt(xy.left)}% top=${fmt(xy.top)}%)`);
    continue;
  }
  f._xy = xy;
  f._badge = { ...xy };
  mainList.push(f);
}

// 大阪の4施設のように半径15kmに固まっていると、全国スケールでは番号が完全に重なる。
// 位置を偽らずに読ませるため、ドットは実座標に置いたまま「番号バッジだけ」を反発で散らし、
// 実座標との間を引き出し線で結ぶ（添付の公式マップと同じ考え方）。
const MIN_GAP = 4.4; // バッジ同士の最小距離(%)。番号バッジを出す 720px 以上でピン径(26px)+余白に相当
for (let iter = 0; iter < 400; iter++) {
  let moved = false;
  for (let i = 0; i < mainList.length; i++) {
    for (let j = i + 1; j < mainList.length; j++) {
      const a = mainList[i]._badge;
      const b = mainList[j]._badge;
      let dx = b.left - a.left;
      let dy = b.top - a.top;
      let d = Math.hypot(dx, dy);
      if (d >= MIN_GAP) continue;
      if (d < 1e-6) {
        // 完全一致だと押す向きが決まらないので、番号で向きを散らす
        const t = (i * 2.399963) % (Math.PI * 2);
        dx = Math.cos(t);
        dy = Math.sin(t);
        d = 1;
      }
      const push = ((MIN_GAP - d) / 2 / d) * 1.05;
      a.left -= dx * push;
      a.top -= dy * push;
      b.left += dx * push;
      b.top += dy * push;
      moved = true;
    }
  }
  if (!moved) break;
}

const near = [];
for (const f of mainList) {
  const d = Math.hypot(f._badge.left - f._xy.left, f._badge.top - f._xy.top);
  if (d > 6) near.push(`${f.no} ${f.name} のバッジが実座標から ${d.toFixed(1)}% 離れた`);
}

console.log('<!-- 本体マップ: 実座標のドット + 引き出し線 + 番号バッジ -->');
console.log('  <svg class="jp-leaders" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">');
for (const f of mainList) {
  if (Math.hypot(f._badge.left - f._xy.left, f._badge.top - f._xy.top) < 0.4) continue;
  console.log(
    `    <line x1="${fmt(f._xy.left)}" y1="${fmt(f._xy.top)}" x2="${fmt(f._badge.left)}" y2="${fmt(f._badge.top)}" />`,
  );
}
console.log('  </svg>');
for (const f of mainList) console.log(dot(f._xy));
console.log(mainList.map((f) => pin(f, f._badge)).join('\n'));
if (inset) {
  // インセットの位置を本体マップ上に破線で示すための矩形
  const nw = toMain(inset.north, inset.west);
  const se = toMain(inset.south, inset.east);
  console.log('\n<!-- インセット範囲を示す枠 -->');
  console.log(
    `  <span class="jp-inset-rect" style="left:${fmt(nw.left)}%;top:${fmt(nw.top)}%;width:${fmt(se.left - nw.left)}%;height:${fmt(se.top - nw.top)}%"></span>`,
  );
  console.log(`\n<!-- 拡大インセット (${insetPins.length}件) -->`);
  console.log(insetPins.join('\n'));
}

if (withLegend) {
  console.log('\n<ul class="jp-legend">');
  for (const f of list) {
    console.log(
      `  <li><a href="${f.url}" target="_blank" rel="noopener"><span class="n">${f.no}</span>${f.name}</a></li>`,
    );
  }
  console.log('</ul>');
}

if (outside.length) {
  console.error('\n⚠️ bbox 外の施設あり:');
  for (const w of outside) console.error('  ' + w);
}
if (near.length) {
  console.error(`\n⚠️ バッジが実座標から大きく離れた (${near.length}件) — インセットで逃がすか確認すること:`);
  for (const w of near) console.error('  ' + w);
}
if (outside.length) process.exit(2);
