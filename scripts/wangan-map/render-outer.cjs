// 湾岸の外の路線と札（駅名・地名・名所・路線名）を画像に焼く（2026-11-07 利用者「地図の動かない部分を画像にする」を選んだ）。
// スマホ相当で測ると、この約 400 個の部品だけでドラッグ中の描画が 52 → 39 回／秒に落ちていた。
// 路線は render-base.cjs の地図の画像に入れた（2026-11-07）。
// 出力: public/images/wangan-map/outer-labels-far.png・outer-labels-mid.png（色数 64 の PNG。WebP より小さかった）（札・引いたときだけ表示）、outer.json（置く範囲）。
// 外側のデータ（src/data/wangan-outer-labels.json）や地図の範囲を変えたら作り直してコミットする:
//   npm run build && npx http-server dist -p 4329 -s &  →  node scripts/wangan-map/render-outer.cjs http://localhost:4329/wangan-map-bake/
const { chromium } = require('playwright');
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const URL = process.argv[2] || 'http://localhost:4329/wangan-map-bake/';
const PX = 1.6;      // 地図の 1 単位あたりの画素
// 札は 2 段階に焼く: far は拡大率 0.6 に（いちばん引いたとき・z < 0.8 で出す）、mid は 1.0 に（0.8 ≦ z < 1.2 で出す）。前の部品の札と同じ見え方になる
const OUT = path.join(__dirname, '../../public/images/wangan-map');
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1200, height: 900 } });
  await p.goto(URL, { waitUntil: 'networkidle' });
  await p.evaluate(() => document.fonts.ready);
  const pan = await p.evaluate(() => JSON.parse(document.querySelector('[data-wmap-data]').textContent).pan);
  const W = Math.round(pan.w * PX), H = Math.round(pan.h * PX);
  for (const [layer, keepSel, z] of [['labels-far', '.wm-outer', 0.6], ['labels-mid', '.wm-outer', 1.0]]) {
    await p.evaluate(({ pan, W, H, keep, z }) => {
      const svg = document.querySelector('.wmap-svg');
      svg.pauseAnimations();
      const clone = svg.cloneNode(true);
      // 焼く層と、図の定義（defs）だけを残す
      [...clone.children].forEach((c) => { if (c.tagName.toLowerCase() !== 'defs' && !c.matches(keep)) c.remove(); });
      clone.setAttribute('viewBox', `${pan.x} ${pan.y} ${pan.w} ${pan.h}`);
      clone.setAttribute('width', W); clone.setAttribute('height', H);
      clone.style.cssText = `position:fixed;left:0;top:0;width:${W}px;height:${H}px;background:transparent;z-index:99999;--wm-z:${z}`;
      clone.id = 'wm-bake';
      document.body.innerHTML = ''; document.body.style.background = 'transparent'; document.documentElement.style.background = 'transparent';
      document.querySelector('.wmap')?.remove();
      const host = document.createElement('div'); host.className = 'wmap'; host.style.cssText = `--wm-z:${z}`; host.appendChild(clone); document.body.appendChild(host);
    }, { pan, W, H, keep: keepSel, z });
    await p.setViewportSize({ width: W, height: H });
    await p.waitForTimeout(500);
    const png = await p.screenshot({ omitBackground: true, clip: { x: 0, y: 0, width: W, height: H } });
    await sharp(png).png({ palette: true, colors: 64, compressionLevel: 9, effort: 10, dither: 0.5 }).toFile(path.join(OUT, `outer-${layer}.png`));
    console.log(layer, W, H, fs.statSync(path.join(OUT, `outer-${layer}.png`)).size);
    await p.goto(URL, { waitUntil: 'networkidle' }); await p.evaluate(() => document.fonts.ready); await p.setViewportSize({ width: 1200, height: 900 });
  }
  fs.writeFileSync(path.join(OUT, 'outer.json'), JSON.stringify({ generated: new Date().toISOString(), pan, px: PX, labelZ: { far: 0.6, mid: 1.0 } }, null, 1) + '\n');
  await b.close();
})();
