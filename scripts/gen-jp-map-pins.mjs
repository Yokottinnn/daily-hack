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
  `  <a class="jp-pin${cls}" style="left:${fmt(xy.left)}%;top:${fmt(xy.top)}%" href="${f.url}" target="_blank" rel="noopener" title="${f.name}" aria-label="${f.name}">${f.no}</a>`;

const dot = (xy) => `  <span class="jp-dot" style="left:${fmt(xy.left)}%;top:${fmt(xy.top)}%"></span>`;

const insetList = [];
const mainList = [];
for (const f of list) {
  const target = inset && inBox(inset, f) ? insetList : mainList;
  const xy = target === insetList ? toInset(f.lat, f.lon) : toMain(f.lat, f.lon);
  if (target === mainList && (xy.left < 0 || xy.left > 100 || xy.top < 0 || xy.top > 100)) {
    outside.push(`${f.no} ${f.name} (left=${fmt(xy.left)}% top=${fmt(xy.top)}%)`);
    continue;
  }
  target.push({ ...f, _xy: xy, _badge: { ...xy } });
}

// 大阪の4施設のように半径15kmに固まっていると、全国スケールでは番号が完全に重なる。
// 位置を偽らずに読ませるため、ドットは実座標に置いたまま「番号バッジだけ」を反発で散らし、
// 実座標との間を引き出し線で結ぶ（添付の公式マップと同じ考え方）。
//
// gap は「地図の表示幅に対する %」。スマホでも番号が読める必要があるので、
// 想定する最小表示幅でバッジ径 + 余白を満たす値を渡すこと。
// 本体マップはスマホで約354px・バッジ21px → 24px/354px ≒ 6.8% が下限。
function spread(items, gap) {
  for (let iter = 0; iter < 600; iter++) {
    let moved = false;
    for (let i = 0; i < items.length; i++) {
      for (let j = i + 1; j < items.length; j++) {
        const a = items[i]._badge;
        const b = items[j]._badge;
        let dx = b.left - a.left;
        let dy = b.top - a.top;
        let d = Math.hypot(dx, dy);
        if (d >= gap) continue;
        if (d < 1e-6) {
          // 完全一致だと押す向きが決まらないので、黄金角で向きを散らす
          const t = (i * 2.399963) % (Math.PI * 2);
          dx = Math.cos(t);
          dy = Math.sin(t);
          d = 1;
        }
        const push = ((gap - d) / 2 / d) * 1.05;
        a.left -= dx * push;
        a.top -= dy * push;
        b.left += dx * push;
        b.top += dy * push;
        moved = true;
      }
    }
    if (!moved) break;
  }
}
spread(mainList, 7.0);
// インセットはスマホで全幅(約354px)に降りるので、本体ほど広く取る必要はない
spread(insetList, 8.0);

const near = [];
for (const f of [...mainList, ...insetList]) {
  const d = Math.hypot(f._badge.left - f._xy.left, f._badge.top - f._xy.top);
  if (d > 14) near.push(`${f.no} ${f.name} のバッジが実座標から ${d.toFixed(1)}% 離れた`);
}

const render = (items) => {
  const out = [];
  out.push('  <svg class="jp-leaders" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">');
  for (const f of items) {
    if (Math.hypot(f._badge.left - f._xy.left, f._badge.top - f._xy.top) < 0.4) continue;
    out.push(`    <line x1="${fmt(f._xy.left)}" y1="${fmt(f._xy.top)}" x2="${fmt(f._badge.left)}" y2="${fmt(f._badge.top)}" />`);
  }
  out.push('  </svg>');
  for (const f of items) out.push(dot(f._xy));
  for (const f of items) out.push(pin(f, f._badge));
  return out.join('\n');
};

console.log('<!-- 本体マップ: 実座標のドット + 引き出し線 + 番号バッジ -->');
console.log(render(mainList));
if (inset) {
  // インセットの位置を本体マップ上に破線で示すための矩形
  const nw = toMain(inset.north, inset.west);
  const se = toMain(inset.south, inset.east);
  console.log('\n<!-- インセット範囲を示す枠 -->');
  console.log(
    `  <span class="jp-inset-rect" style="left:${fmt(nw.left)}%;top:${fmt(nw.top)}%;width:${fmt(se.left - nw.left)}%;height:${fmt(se.top - nw.top)}%"></span>`,
  );
  console.log(`\n<!-- 拡大インセット (${insetList.length}件) -->`);
  console.log(render(insetList));
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
