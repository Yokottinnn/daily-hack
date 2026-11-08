// イベントマップの動かない絵（海・陸・路線）を画像に焼く（2026-11-07 利用者「まだ移動が遅すぎる／根本的に設計が間違っている／ディズニーのアプリを見習って」）。
// 陸は手描きの揺れ（feTurbulence）・影・ドットのフィルターで描いていて、動かすたびにブラウザがその場で計算し直していた。
// 地図アプリと同じく、粗い 1 枚（base-lo.webp・1 単位 1 画素）と、細かいタイル（tiles/<列>-<行>.webp・256 単位四方を 1 単位 3 画素）に焼く。
// 地図の形・路線・色を変えたら作り直してコミットする:
//   npm run build && npx http-server dist -p 4329 -s &  →  node scripts/wangan-map/render-base.cjs http://localhost:4329/wangan-map-bake/
// 並びの約束（WanganEventMap.astro の updateTiles と同じ）: TILE=256・タイルの左上 = PAN の左上 + (列, 行) × 256
const { chromium } = require('playwright');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const URL = process.argv[2] || 'http://localhost:4329/wangan-map-bake/';
const TILE = 256, TILE_PX = 3, TILE_PX2 = 2, LO_PX = 1;
const OUT = path.join(__dirname, '../../public/images/wangan-map');
(async () => {
  fs.mkdirSync(path.join(OUT, 'tiles'), { recursive: true });
  for (const f of fs.readdirSync(path.join(OUT, 'tiles'))) fs.unlinkSync(path.join(OUT, 'tiles', f));
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 800, height: 800 } });
  await p.goto(URL, { waitUntil: 'networkidle' });
  await p.evaluate(() => document.fonts.ready);
  const pan = await p.evaluate(() => JSON.parse(document.querySelector('[data-wmap-data]').textContent).pan);
  // 焼く層（.wm-base）だけを見える状態にした SVG を、画面の左上に置く
  await p.evaluate(() => {
    const svg = document.querySelector('.wmap-svg');
    const orig = document.querySelector('.wmap'); // 色の変数（--wm-sea など）は .wmap に付いている。属性ごと写す
    svg.pauseAnimations();
    const clone = svg.cloneNode(true);
    clone.id = 'wm-bake';
    const st = document.createElementNS('http://www.w3.org/2000/svg', 'style');
    st.textContent = '#wm-bake{visibility:hidden} #wm-bake .wm-base, #wm-bake .wm-base *{visibility:visible} #wm-bake *{animation:none!important;transition:none!important}';
    clone.prepend(st);
    document.body.innerHTML = '';
    document.documentElement.style.background = document.body.style.background = 'transparent';
    const host = document.createElement('div'); for (const a of orig.attributes) if (a.name !== 'style' || true) host.setAttribute(a.name, a.value); host.appendChild(clone); document.body.appendChild(host);
  });
  const shoot = async (x, y, w, h, px) => {
    const W = Math.round(w * px), H = Math.round(h * px);
    await p.setViewportSize({ width: W, height: H });
    await p.evaluate(({ x, y, w, h, W, H }) => {
      const c = document.getElementById('wm-bake');
      c.setAttribute('viewBox', `${x} ${y} ${w} ${h}`); c.setAttribute('preserveAspectRatio', 'none');
      c.style.cssText = `position:fixed;left:0;top:0;width:${W}px;height:${H}px;overflow:hidden`;
    }, { x, y, w, h, W, H });
    await p.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    return p.screenshot({ clip: { x: 0, y: 0, width: W, height: H } });
  };
  const lo = await shoot(pan.x, pan.y, pan.w, pan.h, LO_PX);
  await sharp(lo).webp({ quality: 72, effort: 6 }).toFile(path.join(OUT, 'base-lo.webp'));
  console.log('base-lo', fs.statSync(path.join(OUT, 'base-lo.webp')).size);
  const cols = Math.ceil(pan.w / TILE), rows = Math.ceil(pan.h / TILE);
  // 2026-11-08: 拡大しすぎていないとき用の 2 画素（tiles2）も焼く（画素が約半分で、展開が軽い）
  for (const [dir, px] of [['tiles', TILE_PX], ['tiles2', TILE_PX2]]) {
    fs.mkdirSync(path.join(OUT, dir), { recursive: true });
    for (const f of fs.readdirSync(path.join(OUT, dir))) fs.unlinkSync(path.join(OUT, dir, f));
    let total = 0;
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const png = await shoot(pan.x + c * TILE, pan.y + r * TILE, TILE, TILE, px);
      const f = path.join(OUT, dir, `${c}-${r}.webp`);
      await sharp(png).webp({ quality: 72, effort: 6 }).toFile(f);
      total += fs.statSync(f).size;
    }
    console.log(dir, cols * rows, Math.round(total / 1024) + 'KB');
  }
  fs.writeFileSync(path.join(OUT, 'base.json'), JSON.stringify({ generated: new Date().toISOString(), pan, tile: TILE, tilePx: TILE_PX, tilePx2: TILE_PX2, loPx: LO_PX, cols, rows }, null, 1) + '\n');
  await b.close();
})();
