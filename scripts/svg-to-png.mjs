// **SVG を PNG にする。** Chromium で描いて切り出す。
//
// **Mac では変換できない。** `rsvg-convert` も `inkscape` も `magick` も
// `cairosvg` も入っていない（docs/mac-environment.md に実測）。
// **Pillow も SVG を開けない。** だから `ops/tasks` は SVG をそのまま持ち帰り、
// ここで PNG にする。
//
//   node scripts/svg-to-png.mjs path/to/logo.svg ...
//
// playwright-core が見つからないときは、その場で入れて使う:
//   npm i --no-save playwright-core
import fs from 'node:fs';
import path from 'node:path';

let chromium;
for (const m of ['playwright-core', 'playwright']) {
  try { ({ chromium } = await import(m)); break; } catch { /* 次を試す */ }
}
if (!chromium) {
  console.error('playwright-core が無い。`npm i --no-save playwright-core` を先に打つこと。');
  process.exit(1);
}

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('使い方: node scripts/svg-to-png.mjs <file.svg> ...');
  process.exit(1);
}

// クラウドの実行環境に同梱の Chromium があればそれを使う
const bundled = '/opt/pw-browsers/chromium';
const b = await chromium.launch(fs.existsSync(bundled) ? { executablePath: bundled } : {});
for (const f of files) {
  const svg = fs.readFileSync(f, 'utf8');
  const p = await b.newPage({ viewport: { width: 1200, height: 1200 }, deviceScaleFactor: 2 });
  // **width / height を持たない SVG がある。** そのままだと大きさ 0 で
  // 「element is not visible」になり、30 秒 待たされた末に落ちる（実際に踏んだ）。
  // **CSS で必ず大きさを与える。**
  await p.setContent(
    `<html><head><style>
       body { margin: 0; display: inline-block; }
       svg { width: 600px !important; height: auto !important; display: block !important; }
     </style></head><body>${svg}</body></html>`);
  const out = f.replace(/\.svg$/, '.png');
  try {
    const el = await p.$('svg');
    if (!el) throw new Error('svg 要素が無い');
    const box = await el.boundingBox();
    if (!box || box.width < 1 || box.height < 1) throw new Error('大きさが 0');
    // **透過のまま出す。** 白抜きのロゴは CSS の `on-dark` で枠を暗くして使う
    await el.screenshot({ path: out, omitBackground: true, timeout: 8000 });
    console.log(`✅ ${path.basename(out)} / ${Math.round(box.width)}x${Math.round(box.height)}`);
  } catch (e) {
    // **1 枚 失敗しても残りを続ける。** 落ちると全部 やり直しになる
    console.log(`✗ ${path.basename(f)} … ${String(e.message).slice(0, 60)}`);
  }
  await p.close();
}
await b.close();
