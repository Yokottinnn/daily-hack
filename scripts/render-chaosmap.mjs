#!/usr/bin/env node
/**
 * render-chaosmap.mjs — ポイントサービス カオスマップ 本体(in-article) + それを取り込んだ16:9 eyecatch を生成。
 * 参考: ポイント業界カオスマップ(Ceres)等の「カテゴリ箱×サービス配置」構成を踏襲し、Daily Hackブランド(マゼンタPOP)で再設計。
 * Playwright は sns-templates の node_modules を借用。
 * Usage: node scripts/render-chaosmap.mjs
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import path from 'node:path';

const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');
const FONTS = SNS + '/fonts';
const ASSETS_T = SNS + '/assets-transparent';
const OUT_DIR = '/Users/ny_taxa/projects/anta-baka-x/blog/public/images/point-service-complete-guide-2026';

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// 4カテゴリ（記事準拠）
const CATS = [
  { key: 'A', color: '#D63E76', name: '共通ポイント', sub: '経済圏', role: '日常の支払いで貯まる“軸”',
    items: ['楽天ポイント', 'PayPayポイント', 'dポイント', 'Vポイント', 'Pontaポイント'] },
  { key: 'B', color: '#1E6EC8', name: 'ポイントサイト', sub: '案件型', role: '申込・買い物を“経由”して上乗せ',
    items: ['モッピー', 'ハピタス', 'ポイントインカム', 'ちょびリッチ'] },
  { key: 'C', color: '#2DAF5F', name: '移動・歩数ポイ活', sub: 'ついで型', role: '歩く・移動を“ついで”に換金',
    items: ['トリマ', 'ANA Pocket', 'JAL Wellness', 'dヘルスケア', '楽天ヘルスケア'] },
  { key: 'D', color: '#E65A1E', name: 'アンケート・スキマ', sub: 'スキマ型', role: '空き時間を小銭に',
    items: ['マクロミル', '楽天インサイト', 'infoQ', 'リサーチパネル'] },
];

const FONT_FACE = `
  @font-face{font-family:"RocknRoll One";src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:400;src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:700;src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:900;src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2");}
  @font-face{font-family:"Bebas Neue";src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2");}`;

const BG = `radial-gradient(circle at 4% 6%, #FDE4EE 0%, transparent 32%),radial-gradient(circle at 98% 96%, #FFFBEE 0%, transparent 38%),linear-gradient(135deg,#FFF5F8 0%,#FFFFFF 52%,#FFFBEE 100%)`;

function catBox(c, compact) {
  const chips = c.items.map(it => `<span class="chip">${esc(it)}</span>`).join('');
  return `
  <div class="box" style="--cc:${c.color}">
    <div class="box-head">
      <span class="cat-badge">${c.key}</span>
      <span class="cat-name">${esc(c.name)}<i>${esc(c.sub)}</i></span>
    </div>
    ${compact ? '' : `<div class="box-role">${esc(c.role)}</div>`}
    <div class="chips">${chips}</div>
  </div>`;
}

// ===== ① 本体カオスマップ 1600x1180 =====
function chaosMapHtml() {
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:1180px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;overflow:hidden;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:44px 54px 36px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:center;}
  .brand{display:inline-flex;align-items:center;gap:11px;background:#fff;border:2px solid #FDE4EE;padding:10px 22px 10px 15px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:19px;height:19px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:25px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:24px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  .titleband{text-align:center;margin:14px 0 8px;}
  .titleband .kk{color:#D63E76;font-weight:900;font-size:25px;}
  .titleband h1{font-family:"RocknRoll One";font-size:62px;line-height:1.08;margin-top:4px;}
  .titleband h1 .mk{position:relative;z-index:0;}
  .titleband h1 .mk::after{content:"";position:absolute;left:-4px;right:-4px;bottom:8px;height:22px;background:#FFEC00;z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .grid{flex:1;display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;gap:26px;margin-top:8px;}
  .box{background:#fff;border:3px solid var(--cc);border-radius:24px;padding:0 0 20px;overflow:hidden;box-shadow:0 16px 36px -18px rgba(0,0,0,.28);display:flex;flex-direction:column;}
  .box-head{display:flex;align-items:center;gap:16px;background:var(--cc);color:#fff;padding:16px 22px;}
  .cat-badge{width:52px;height:52px;flex:0 0 52px;border-radius:14px;background:rgba(255,255,255,.22);font-family:"Bebas Neue";font-size:40px;display:flex;align-items:center;justify-content:center;}
  .cat-name{font-family:"RocknRoll One";font-size:34px;line-height:1;}
  .cat-name i{font-style:normal;font-family:"Zen Maru Gothic";font-weight:700;font-size:18px;margin-left:10px;opacity:.92;}
  .box-role{font-size:21px;font-weight:700;color:#5A4651;padding:16px 24px 4px;}
  .chips{display:flex;flex-wrap:wrap;gap:12px;padding:14px 24px 0;}
  .chip{background:#fff;border:2.5px solid var(--cc);color:var(--cc);font-weight:900;font-size:25px;padding:9px 20px;border-radius:999px;box-shadow:0 4px 10px -6px rgba(0,0,0,.18);}
  .foot{display:flex;justify-content:space-between;align-items:center;margin-top:24px;background:linear-gradient(90deg,#D63E76 0%,#1E6EC8 38%,#2DAF5F 70%,#E65A1E 100%);border-radius:16px;padding:16px 28px;}
  .foot .read{color:#fff;font-weight:900;font-size:26px;}
  .foot .read b{color:#FFEC00;}
  .foot .handle{color:#fff;font-family:"Bebas Neue";font-size:26px;letter-spacing:.04em;opacity:.95;}
  .char{position:absolute;right:38px;bottom:96px;width:188px;height:188px;object-fit:contain;filter:drop-shadow(0 12px 18px rgba(120,30,60,.28));z-index:3;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="titleband"><div class="kk">ポイ活、種類が多すぎ問題を解決</div><h1>ポイントサービス <span class="mk">カオスマップ</span> 2026</h1></div>
    <div class="grid">${CATS.map(c => catBox(c, false)).join('')}</div>
    <div class="foot"><div class="read"><b>A</b>=土台 → <b>B</b>=増幅 → <b>C・D</b>=取りこぼし回収</div><div class="handle">@heng_ji31590</div></div>
  </div>
  </body></html>`;
}

// ===== ② eyecatch 16:9 1600x900（カオスマップの2x2を右に取り込む）=====
function eyecatchHtml() {
  const grid = CATS.map(c => catBox(c, true)).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:900px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;overflow:hidden;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:44px 52px 38px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid #FDE4EE;padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:23px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:23px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  .body{flex:1;display:flex;gap:34px;margin-top:14px;}
  .left{width:660px;display:flex;flex-direction:column;}
  .kk{color:#D63E76;font-weight:900;font-size:25px;}
  h1{font-family:"RocknRoll One";line-height:1.1;margin-top:6px;}
  h1 .l1{font-size:78px;display:block;}
  h1 .l2{font-size:88px;display:block;margin-top:2px;}
  h1 .mk{position:relative;z-index:0;}
  h1 .mk::after{content:"";position:absolute;left:-6px;right:-6px;bottom:10px;height:30px;background:#FFEC00;z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .sub{font-size:28px;font-weight:700;color:#5A4651;margin-top:20px;}
  .charwrap{margin-top:auto;display:flex;align-items:flex-end;gap:16px;}
  .char{width:288px;height:288px;object-fit:contain;filter:drop-shadow(0 12px 20px rgba(120,30,60,.25));}
  .speech{position:relative;background:#fff;border:2px solid #FDE4EE;border-radius:20px;padding:15px 20px;font-size:25px;font-weight:900;color:#A82959;box-shadow:0 10px 22px -12px rgba(214,62,118,.5);margin-bottom:56px;white-space:pre-line;text-align:center;}
  .speech::after{content:"";position:absolute;left:-12px;bottom:20px;border:10px solid transparent;border-right-color:#fff;}
  .right{flex:1;display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr;gap:14px;}
  .box{background:#fff;border:2.5px solid var(--cc);border-radius:16px;overflow:hidden;box-shadow:0 12px 26px -16px rgba(0,0,0,.3);display:flex;flex-direction:column;}
  .box-head{display:flex;align-items:center;gap:10px;background:var(--cc);color:#fff;padding:8px 12px;}
  .cat-badge{width:30px;height:30px;flex:0 0 30px;border-radius:8px;background:rgba(255,255,255,.22);font-family:"Bebas Neue";font-size:24px;display:flex;align-items:center;justify-content:center;}
  .cat-name{font-family:"RocknRoll One";font-size:19px;line-height:1.05;}
  .cat-name i{display:none;}
  .chips{display:flex;flex-wrap:wrap;gap:6px;padding:9px 11px;align-content:flex-start;}
  .chip{background:#fff;border:2px solid var(--cc);color:var(--cc);font-weight:900;font-size:15px;padding:3px 10px;border-radius:999px;}
  .foot{display:flex;justify-content:space-between;align-items:center;margin-top:14px;background:linear-gradient(90deg,#D63E76,#A82959);border-radius:16px;padding:13px 26px;}
  .foot .v{color:#fff;font-weight:900;font-size:25px;}
  .foot .v b{color:#FFEC00;}
  .foot .h{color:#FFD9E6;font-family:"Bebas Neue";font-size:24px;letter-spacing:.04em;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="body">
      <div class="left">
        <div class="kk">ポイ活、種類が多すぎ問題</div>
        <h1><span class="l1">ポイントサービス</span><span class="l2">全部<span class="mk">整理した</span></span></h1>
        <div class="sub">カオスマップで4カテゴリに分類 → 徹底比較</div>
        <div class="charwrap">
          <img class="char" src="file://${ASSETS_T}/expr-05-smug.png" alt="">
          <div class="speech">まず軸を\n1つ決めな</div>
        </div>
      </div>
      <div class="right">${grid}</div>
    </div>
    <div class="foot"><div class="v">①軸を決める→②<b>経由で二重取り</b>→③ついで回収</div><div class="h">@heng_ji31590</div></div>
  </div>
  </body></html>`;
}

async function render(html, w, h, outPath, type) {
  // 一時HTMLを file:// で開く（setContentのabout:blank由来だと file:// 画像がブロックされるため）
  const tmpHtml = path.join('/tmp', `chaosmap-render-${type}-${w}x${h}.html`);
  fs.writeFileSync(tmpHtml, html);
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
  await page.goto('file://' + tmpHtml, { waitUntil: 'networkidle' });
  await page.evaluate(async () => { if (document.fonts && document.fonts.ready) await document.fonts.ready; });
  await page.waitForTimeout(500);
  const opts = type === 'jpeg' ? { path: outPath, type: 'jpeg', quality: 92 } : { path: outPath, type: 'png' };
  await page.screenshot(opts);
  await browser.close();
  console.log('rendered', outPath);
}

(async () => {
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });
  await render(chaosMapHtml(), 1600, 1180, path.join(OUT_DIR, 'chaosmap.png'), 'png');
  await render(eyecatchHtml(), 1600, 900, path.join(OUT_DIR, 'eyecatch.jpg'), 'jpeg');
})();
