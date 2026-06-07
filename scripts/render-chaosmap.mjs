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
const LOGO_DIR = OUT_DIR + '/logos';

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// サービス名 → 公式アプリロゴ（iTunes取得・logos/配下）
const LOGO = {
  '楽天ポイント':'rakuten.png','PayPayポイント':'paypay.png','dポイント':'dpoint.png','Vポイント':'vpoint.png','Pontaポイント':'ponta.png',
  'モッピー':'moppy.png','ハピタス':'hapitas.png','ポイントインカム':'pointincome.png','ちょびリッチ':'chobirich.png',
  'トリマ':'torima.png','ANA Pocket':'anapocket.png','JAL Wellness':'jalwellness.png','dヘルスケア':'dhealth.png','楽天ヘルスケア':'rakutenhealth.png',
  'マクロミル':'macromill.png',
};
const logoImg = (name) => LOGO[name] ? `<img class="chip-logo" src="file://${LOGO_DIR}/${LOGO[name]}" alt="">` : '';

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
  const chips = c.items.map(it => `<span class="chip${LOGO[it] ? ' has-logo' : ''}">${logoImg(it)}${esc(it)}</span>`).join('');
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
  .chips{display:flex;flex-wrap:wrap;gap:13px;padding:16px 24px 0;}
  .chip{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2.5px solid var(--cc);color:var(--cc);font-weight:900;font-size:25px;padding:8px 20px;border-radius:999px;box-shadow:0 4px 10px -6px rgba(0,0,0,.18);}
  .chip.has-logo{padding-left:8px;}
  .chip-logo{width:40px;height:40px;border-radius:9px;object-fit:cover;flex:0 0 40px;}
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
  .chips{display:flex;flex-wrap:wrap;gap:7px;padding:9px 11px;align-content:flex-start;}
  .chip{display:inline-flex;align-items:center;gap:5px;background:#fff;border:2px solid var(--cc);color:var(--cc);font-weight:900;font-size:15px;padding:3px 9px;border-radius:999px;}
  .chip.has-logo{padding-left:3px;}
  .chip-logo{width:22px;height:22px;border-radius:5px;object-fit:cover;flex:0 0 22px;}
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

// ===== ③ 四象限マトリックス（各サービスをロゴでプロット）1600x1200 =====
// x: 0=受動的(ほっといて貯まる) 〜 100=能動的(動いて稼ぐ)
// y: 0=リターン大(まとまる/上) 〜 100=リターン小(コツコツ/下)
const PLOT = [
  // A 共通ポイント（受動・大）= 左上
  { n:'楽天ポイント', x:16, y:20, c:'#D63E76', logo:'rakuten.png' },
  { n:'Vポイント', x:33, y:26, c:'#D63E76', logo:'vpoint.png' },
  { n:'dポイント', x:24, y:33, c:'#D63E76', logo:'dpoint.png' },
  { n:'PayPay', x:31, y:40, c:'#D63E76', logo:'paypay.png' },
  { n:'Ponta', x:20, y:44, c:'#D63E76', logo:'ponta.png' },
  // B ポイントサイト（能動・大）= 右上
  { n:'モッピー', x:74, y:18, c:'#1E6EC8', logo:'moppy.png' },
  { n:'ハピタス', x:82, y:27, c:'#1E6EC8', logo:'hapitas.png' },
  { n:'ポイントインカム', x:70, y:33, c:'#1E6EC8', logo:'pointincome.png' },
  { n:'ちょびリッチ', x:84, y:40, c:'#1E6EC8', logo:'chobirich.png' },
  // C 移動・歩数（受動寄り・小）= 左下
  { n:'ANA Pocket', x:41, y:60, c:'#2DAF5F', logo:'anapocket.png' },
  { n:'トリマ', x:28, y:66, c:'#2DAF5F', logo:'torima.png' },
  { n:'JAL Wellness', x:45, y:71, c:'#2DAF5F', logo:'jalwellness.png' },
  { n:'dヘルスケア', x:24, y:76, c:'#2DAF5F', logo:'dhealth.png' },
  { n:'楽天ヘルスケア', x:32, y:82, c:'#2DAF5F', logo:'rakutenhealth.png' },
  // D アンケート（能動・小）= 右下
  { n:'マクロミル', x:76, y:70, c:'#E65A1E', logo:'macromill.png' },
  { n:'楽天インサイト', x:83, y:79, c:'#E65A1E', logo:null },
];

function quadrantHtml() {
  const pins = PLOT.map(p => `
    <div class="pin" style="left:${p.x}%;top:${p.y}%;--pc:${p.c}">
      ${p.logo ? `<img src="file://${LOGO_DIR}/${p.logo}" alt="">` : `<span class="nologo">${esc(p.n[0])}</span>`}
      <span class="pin-label">${esc(p.n)}</span>
    </div>`).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;}
  html,body{width:1600px;height:1200px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:40px 50px 30px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:center;}
  .brand{display:inline-flex;align-items:center;gap:11px;background:#fff;border:2px solid #FDE4EE;padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:24px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:23px;padding:9px 20px;border-radius:14px;transform:rotate(3deg);}
  .ttl{text-align:center;font-family:"RocknRoll One";font-size:50px;margin:10px 0 6px;}
  .ttl .mk{position:relative;z-index:0;}.ttl .mk::after{content:"";position:absolute;left:-4px;right:-4px;bottom:6px;height:18px;background:#FFEC00;z-index:-1;border-radius:4px;}
  .plot{position:relative;flex:1;margin:30px 70px 56px;}
  /* 4象限の地色 */
  .q{position:absolute;width:50%;height:50%;opacity:.5;}
  .q1{left:0;top:0;background:radial-gradient(circle at 30% 30%,#FCE2EC,transparent 70%);}
  .q2{right:0;top:0;background:radial-gradient(circle at 70% 30%,#E2EEFB,transparent 70%);}
  .q3{left:0;bottom:0;background:radial-gradient(circle at 30% 70%,#E4F5EA,transparent 70%);}
  .q4{right:0;bottom:0;background:radial-gradient(circle at 70% 70%,#FCEBDD,transparent 70%);}
  .qlabel{position:absolute;font-weight:900;font-size:22px;padding:6px 14px;border-radius:10px;color:#fff;}
  .ql1{left:14px;top:12px;background:#D63E76;}
  .ql2{right:14px;top:12px;background:#1E6EC8;}
  .ql3{left:14px;bottom:12px;background:#2DAF5F;}
  .ql4{right:14px;bottom:12px;background:#E65A1E;}
  /* 軸 */
  .axis-x{position:absolute;left:0;right:0;top:50%;height:4px;background:#2A1923;transform:translateY(-50%);border-radius:2px;}
  .axis-y{position:absolute;top:0;bottom:0;left:50%;width:4px;background:#2A1923;transform:translateX(-50%);border-radius:2px;}
  .axis-x::after,.axis-y::before{content:"";position:absolute;}
  .axlbl{position:absolute;font-weight:900;font-size:21px;color:#2A1923;background:#fff;padding:4px 12px;border-radius:8px;border:2px solid #2A1923;}
  .ax-left{left:-58px;top:50%;transform:translateY(-50%);}
  .ax-right{right:-64px;top:50%;transform:translateY(-50%);}
  .ax-top{left:50%;top:-46px;transform:translateX(-50%);}
  .ax-bottom{left:50%;bottom:-46px;transform:translateX(-50%);}
  .pin{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:4px;z-index:5;}
  .pin img{width:62px;height:62px;border-radius:14px;object-fit:cover;box-shadow:0 6px 14px -6px rgba(0,0,0,.4);border:3px solid var(--pc);background:#fff;}
  .pin .nologo{width:62px;height:62px;border-radius:14px;background:var(--pc);color:#fff;font-family:"RocknRoll One";font-size:30px;display:flex;align-items:center;justify-content:center;border:3px solid var(--pc);}
  .pin-label{font-weight:900;font-size:18px;color:#2A1923;background:#fff;padding:2px 9px;border-radius:999px;box-shadow:0 3px 8px -4px rgba(0,0,0,.3);white-space:nowrap;}
  .foot{text-align:center;font-weight:700;color:#5A4651;font-size:19px;}
  .foot b{color:#D63E76;}
  .hd{position:absolute;right:50px;bottom:30px;font-family:"Bebas Neue";font-size:22px;color:#b08;opacity:.8;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="ttl">ポイントサービス <span class="mk">4象限マップ</span> 2026</div>
    <div class="plot">
      <div class="q q1"></div><div class="q q2"></div><div class="q q3"></div><div class="q q4"></div>
      <div class="qlabel ql1">自動で貯まる土台<br>＝共通ポイント</div>
      <div class="qlabel ql2">本気で稼ぐ<br>＝ポイントサイト</div>
      <div class="qlabel ql3">ついでに小銭<br>＝移動・歩数</div>
      <div class="qlabel ql4">スキマで小銭<br>＝アンケート</div>
      <div class="axis-x"></div><div class="axis-y"></div>
      <div class="axlbl ax-left">受動的<br>ほっといて貯まる</div>
      <div class="axlbl ax-right">能動的<br>動いて稼ぐ</div>
      <div class="axlbl ax-top">リターン大</div>
      <div class="axlbl ax-bottom">リターン小</div>
      ${pins}
    </div>
    <div class="foot">縦=1回/月で得られるリターンの大きさ ／ 横=どれだけ自分から動く必要があるか。<b>まず左上（共通ポイント）を軸に、右上（ポイントサイト）で二重取り</b>が王道。</div>
    <div class="hd">@heng_ji31590</div>
  </div>
  </body></html>`;
}

(async () => {
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });
  await render(chaosMapHtml(), 1600, 1180, path.join(OUT_DIR, 'chaosmap.png'), 'png');
  await render(quadrantHtml(), 1600, 1200, path.join(OUT_DIR, 'chaosmap-matrix.png'), 'png');
  await render(eyecatchHtml(), 1600, 900, path.join(OUT_DIR, 'eyecatch.jpg'), 'jpeg');
})();
