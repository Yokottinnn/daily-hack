#!/usr/bin/env node
/**
 * gen-map-pins.mjs — 緯度経度のリストを、ベース地図上の % 座標 (left/top) に変換して
 * .wangan-pin / .wangan-area の HTML を吐く。
 *
 * Usage:
 *   node scripts/gen-map-pins.mjs public/images/wangan-map-base.png.meta.json pins.json
 *
 * pins.json の形:
 *   { "pins": [{ "no": 1, "label": "○○タワー", "lat": 35.66, "lon": 139.78, "class": "" }],
 *     "areas": [{ "name": "晴海", "lat": 35.648, "lon": 139.783 }] }
 */
import { readFile } from 'node:fs/promises';

const [metaPath, pinsPath] = process.argv.slice(2);
if (!metaPath || !pinsPath) {
  console.error('usage: gen-map-pins.mjs <meta.json> <pins.json>');
  process.exit(1);
}

const meta = JSON.parse(await readFile(metaPath, 'utf8'));
const { pins = [], areas = [] } = JSON.parse(await readFile(pinsPath, 'utf8'));

// Web メルカトルの y は緯度に対して線形でないので、y 方向も投影してから比率を取る
const mercY = (lat) => {
  const r = (lat * Math.PI) / 180;
  return Math.log(Math.tan(r) + 1 / Math.cos(r));
};
const yTop = mercY(meta.north);
const yBottom = mercY(meta.south);

const pct = (lat, lon) => {
  const left = ((lon - meta.west) / (meta.east - meta.west)) * 100;
  const top = ((yTop - mercY(lat)) / (yTop - yBottom)) * 100;
  return { left, top };
};

const fmt = (v) => v.toFixed(2);
const warn = [];

for (const a of areas) {
  const { left, top } = pct(a.lat, a.lon);
  if (left < 0 || left > 100 || top < 0 || top > 100) warn.push(`AREA 範囲外: ${a.name}`);
  console.log(
    `    <span class="wangan-area" style="left:${fmt(left)}%;top:${fmt(top)}%">${a.name}</span>`,
  );
}
for (const p of pins) {
  const { left, top } = pct(p.lat, p.lon);
  if (left < 0 || left > 100 || top < 0 || top > 100) warn.push(`PIN 範囲外: ${p.no} ${p.label}`);
  const cls = p.class ? ` ${p.class}` : '';
  console.log(
    `    <span class="wangan-pin${cls}" style="left:${fmt(left)}%;top:${fmt(top)}%"><span class="pin-no">${p.no}</span><span class="pin-label">${p.label}</span></span>`,
  );
}

if (warn.length) {
  console.error('\n⚠️ bbox 外の要素あり:');
  for (const w of warn) console.error('  ' + w);
  process.exit(2);
}
