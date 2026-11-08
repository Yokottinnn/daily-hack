#!/usr/bin/env node
// 成果リンクの取りこぼしを、ビルドのたびに見つけて止める（2026-11-08・利用者が「点検を毎日の仕組みにする」を選んだ）。
// dist/posts/*/index.html を読み、次の 3 つが 1 本でもあればビルドを失敗させる。
//   1. タグの無い Amazon のリンク（tag=dailyhack-22 が無い amazon.co.jp）
//   2. 楽天 ID で包んでいない楽天市場の商品リンク（item.rakuten.co.jp を直接指す）
//   3. LinkSwitch が入らない記事（isPR: false）にある Yahoo!ショッピングのリンク（成果リンクに書き換わらない）
// 経緯と確かめ方は docs/shop-comparison.md の「成果リンクになることを実物で確かめた」。LLM 不使用・$0。
import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'dist/posts';
const TAG = 'tag=dailyhack-22';
if (!fs.existsSync(ROOT)) { console.log('check-aff-links: dist/posts が無いので飛ばす'); process.exit(0); }
const bad = [];
for (const slug of fs.readdirSync(ROOT)) {
  const f = path.join(ROOT, slug, 'index.html');
  if (!fs.existsSync(f)) continue;
  const html = fs.readFileSync(f, 'utf8');
  const isPR = html.includes('vcdal.js');
  for (const m of html.matchAll(/href="([^"]+)"/g)) {
    const u = m[1].replace(/&amp;/g, '&');
    if (/^https?:\/\/(www\.)?amazon\.co\.jp/.test(u) && !u.includes(TAG)) bad.push([slug, 'Amazon にタグが無い', u]);
    if (/^https?:\/\/item\.rakuten\.co\.jp/.test(u)) bad.push([slug, '楽天の商品リンクが楽天 ID で包まれていない', u]);
    if (!isPR && /^https?:\/\/(store\.)?shopping\.yahoo\.co\.jp/.test(u)) bad.push([slug, 'isPR でない記事の Yahoo! リンク（成果リンクに書き換わらない）', u]);
  }
}
if (bad.length) {
  console.error(`✗ check-aff-links: 成果にならないリンクが ${bad.length} 本ある`);
  for (const [s, why, u] of bad.slice(0, 30)) console.error(`  - ${s}: ${why}\n      ${u.slice(0, 140)}`);
  console.error('直し方: Amazon は末尾に ?tag=dailyhack-22（? があれば &）。楽天は https://hb.afl.rakuten.co.jp/hgc/<src/data/shop/config.json の affiliateId>/?pc=<URL を encodeURIComponent>&m=<同じ> で包む。Yahoo! は記事を isPR: true にする');
  process.exit(1);
}
console.log('✓ check-aff-links: Amazon・楽天の商品・Yahoo! のリンクはすべて成果リンク');
