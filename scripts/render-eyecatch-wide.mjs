#!/usr/bin/env node
/**
 * render-eyecatch-wide.mjs — ブログ専用 ネイティブ16:9 eyecatch レンダラ
 *
 * X用サムネ(1:1)とは別物。ブログeyecatchは最初から 1600x900 横長で設計する。
 * 正方形を貼って余白で埋める方式は禁止（feedback_eyecatch_quality_gate）。
 *
 * Playwright は sns-templates の node_modules を借用（createRequire）。
 * Usage: node scripts/render-eyecatch-wide.mjs <data.json> <out.jpg>
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import path from 'node:path';

const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');

const FONTS = SNS + '/fonts';
// 透過版キャラを優先（背景の白四角を出さない）。無ければ通常assets。
const ASSETS_T = SNS + '/assets-transparent';
const ASSETS = SNS + '/assets';
function charSrc(file) {
  return fs.existsSync(path.join(ASSETS_T, file)) ? `${ASSETS_T}/${file}` : `${ASSETS}/${file}`;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function buildHtml(d) {
  const cards = d.ranking.map((r, i) => {
    const rec = r.recommended;
    return `
    <div class="rank-card${rec ? ' is-top' : ''}">
      ${rec ? `<div class="ribbon">★ コスパ◎</div>` : ''}
      <div class="rank-no${rec ? ' gold' : ''}">${i + 1}</div>
      <div class="dot" style="background:${r.color}"></div>
      <div class="rc-name">${esc(r.name)}</div>
      <div class="rc-metric">
        <span class="rc-val">${esc(r.value)}</span>
        <span class="rc-unit">${esc(r.unit)}</span>
      </div>
    </div>`;
  }).join('');

  return `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face { font-family:"RocknRoll One"; src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:400; src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:700; src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2"); }
  @font-face { font-family:"Zen Maru Gothic"; font-weight:900; src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2"); }
  @font-face { font-family:"Bebas Neue"; src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2"); }
  :root{
    --magenta:#EC5C90; --magenta-strong:#D63E76; --magenta-deep:#A82959;
    --magenta-light:#FDE4EE; --magenta-faint:#FFF5F8; --cream-light:#FFFBEE;
    --ink:#2A1923; --ink-soft:#5A4651; --neon:#FFEC00;
  }
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:900px;}
  body{
    font-family:"Zen Maru Gothic",sans-serif; color:var(--ink); position:relative; overflow:hidden;
    background:
      radial-gradient(circle at 4% 6%, var(--magenta-light) 0%, transparent 34%),
      radial-gradient(circle at 98% 96%, var(--cream-light) 0%, transparent 40%),
      linear-gradient(135deg, var(--magenta-faint) 0%, #FFFFFF 52%, var(--cream-light) 100%);
  }
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle, rgba(214,62,118,.06) 1.6px, transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:46px 56px 40px;display:flex;flex-direction:column;}
  /* header */
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid var(--magenta-light);
    padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:var(--magenta-strong);}
  .brand span{font-family:"RocknRoll One";font-size:24px;color:var(--ink);}
  .badge{background:var(--magenta-strong);color:#fff;font-family:"RocknRoll One";font-size:24px;
    padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  /* body */
  .body{flex:1;display:flex;gap:40px;align-items:stretch;margin-top:18px;}
  .left{width:600px;display:flex;flex-direction:column;position:relative;}
  .kicker{color:var(--magenta-strong);font-weight:900;font-size:26px;margin-bottom:6px;letter-spacing:.02em;}
  h1{font-family:"RocknRoll One";line-height:1.12;color:var(--ink);}
  h1 .l1{font-size:${d.title1_size || 104}px;display:block;white-space:nowrap;}
  h1 .l2{font-size:${d.title2_size || 74}px;display:block;margin-top:2px;white-space:nowrap;}
  .mark{position:relative;display:inline-block;z-index:0;}
  .mark::after{content:"";position:absolute;left:-6px;right:-6px;bottom:8px;height:26px;background:var(--neon);z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .subline{font-size:27px;font-weight:700;color:var(--ink-soft);margin-top:22px;}
  .char-wrap{margin-top:auto;display:flex;align-items:flex-end;gap:14px;}
  .char{width:300px;height:300px;object-fit:contain;filter:drop-shadow(0 12px 20px rgba(120,30,60,.25));}
  .speech{position:relative;background:#fff;border:2px solid var(--magenta-light);border-radius:20px;
    padding:16px 20px;font-size:23px;font-weight:700;color:var(--magenta-deep);box-shadow:0 10px 22px -12px rgba(214,62,118,.5);margin-bottom:60px;}
  .speech::after{content:"";position:absolute;left:-12px;bottom:22px;border:10px solid transparent;border-right-color:#fff;}
  /* right ranking */
  .right{flex:1;display:flex;flex-direction:column;justify-content:center;gap:14px;}
  .rank-card{position:relative;display:flex;align-items:center;gap:18px;background:#fff;border:2px solid var(--magenta-light);
    border-radius:20px;padding:16px 24px;box-shadow:0 10px 26px -14px rgba(120,30,60,.3);}
  .rank-card.is-top{border:3px solid #F5B81E;padding:20px 24px;box-shadow:0 16px 34px -14px rgba(245,160,20,.55);}
  .ribbon{position:absolute;top:-15px;right:18px;background:#F5B81E;color:#5A3B00;font-family:"RocknRoll One";font-size:18px;padding:4px 14px;border-radius:999px;}
  .rank-no{width:46px;height:46px;flex:0 0 46px;border-radius:50%;background:var(--magenta-light);color:var(--magenta-deep);
    font-family:"Bebas Neue";font-size:34px;display:flex;align-items:center;justify-content:center;}
  .rank-no.gold{background:#F5B81E;color:#fff;}
  .dot{width:16px;height:16px;border-radius:50%;flex:0 0 16px;}
  .rc-name{font-weight:900;font-size:32px;color:var(--ink);flex:1;}
  .rc-metric{display:flex;flex-direction:column;align-items:flex-end;line-height:1;}
  .rc-val{font-weight:900;font-size:30px;color:var(--magenta-strong);}
  .rc-unit{font-size:16px;color:var(--ink-soft);margin-top:5px;font-weight:700;}
  /* footer */
  .foot{display:flex;justify-content:space-between;align-items:center;margin-top:14px;
    background:linear-gradient(90deg,var(--magenta-strong),var(--magenta-deep));border-radius:16px;padding:14px 26px;}
  .foot .verdict{color:#fff;font-weight:900;font-size:25px;}
  .foot .verdict b{color:var(--neon);}
  .foot .handle{color:#FFD9E6;font-family:"Bebas Neue";font-size:24px;letter-spacing:.04em;}
  ${d.theme === 'alert' ? `
  /* ===== ALERT THEME（改悪・速報・警告）===== */
  body{ color:#FDECEF;
    background:
      radial-gradient(circle at 6% 4%, #5a1020 0%, transparent 36%),
      radial-gradient(circle at 96% 98%, #3a0a16 0%, transparent 42%),
      linear-gradient(135deg, #1c0a10 0%, #2a0d16 52%, #1a0810 100%); }
  .dots{ background-image:radial-gradient(circle, rgba(255,80,90,.07) 1.6px, transparent 1.6px); }
  .brand{ background:#1c0a10; border-color:#7a2330; }
  .brand .b-dot{ background:#FF3B4E; }
  .brand span{ color:#FDECEF; }
  .badge{ background:#FF3B4E; color:#1c0a10; }
  .kicker{ color:#FF6470; }
  h1{ color:#FFFFFF; }
  .mark::after{ background:#FF3B4E; }
  .subline{ color:#E7B9C2; }
  .speech{ background:#2a0d16; border-color:#7a2330; color:#FFD9DE; }
  .speech::after{ border-right-color:#2a0d16; }
  .rank-card{ background:#26101a; border:2px solid #5a1a28; box-shadow:0 10px 26px -14px rgba(0,0,0,.5); }
  .rank-no{ background:#5a1a28; color:#FFB3BC; }
  .rc-name{ color:#FFFFFF; }
  .rc-val{ color:#FF6470; }
  .rc-unit{ color:#C99AA4; }
  .foot{ background:linear-gradient(90deg,#FF3B4E,#A8121F); }
  .foot .verdict b{ color:#FFE34D; }
  ` : ''}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head">
      <div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div>
      <div class="badge">${esc(d.badge)}</div>
    </div>
    <div class="body">
      <div class="left">
        <div class="kicker">${esc(d.kicker)}</div>
        <h1><span class="l1">${esc(d.title1)}</span><span class="l2">${d.title2_html}</span></h1>
        <div class="subline">${esc(d.subline)}</div>
        <div class="char-wrap">
          <img class="char" src="file://${charSrc(d.character)}" alt="">
          <div class="speech">${esc(d.speech)}</div>
        </div>
      </div>
      <div class="right">${cards}</div>
    </div>
    <div class="foot">
      <div class="verdict">${d.verdict_html}</div>
      <div class="handle">${esc(d.handle)}</div>
    </div>
  </div>
  </body></html>`;
}

async function main() {
  const [, , dataArg, outArg] = process.argv;
  const data = JSON.parse(fs.readFileSync(dataArg, 'utf8'));
  const html = buildHtml(data);
  const outAbs = path.resolve(outArg);
  const tmpHtml = outAbs.replace(/\.(jpg|png|jpeg)$/i, '.debug.html');
  fs.mkdirSync(path.dirname(outAbs), { recursive: true });
  fs.writeFileSync(tmpHtml, html);

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto('file://' + tmpHtml, { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const pngPath = outAbs.replace(/\.jpg$/i, '.png');
  await page.screenshot({ path: pngPath, clip: { x: 0, y: 0, width: 1600, height: 900 } });
  await browser.close();

  // 2x PNG → 1600x900 JPG に縮小（web最適）
  const sharp = (() => { try { return require('sharp'); } catch { return null; } })();
  if (sharp) {
    await sharp(pngPath).resize(1600, 900).jpeg({ quality: 90 }).toFile(outAbs);
    fs.unlinkSync(pngPath);
  } else {
    // sharp無し: PIL で 1600x900 JPG に縮小
    const { execSync } = require('child_process');
    execSync(`python3 -c "from PIL import Image; Image.open('${pngPath}').convert('RGB').resize((1600,900), Image.LANCZOS).save('${outAbs}', quality=90)"`);
    fs.unlinkSync(pngPath);
  }
  fs.unlinkSync(tmpHtml);
  console.log('saved', outAbs);
}
main();
