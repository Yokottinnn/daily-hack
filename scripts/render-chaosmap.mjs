#!/usr/bin/env node
/**
 * render-chaosmap.mjs — ポイントサービスの
 *   ① 4象限カオスマップ(chaosmap-matrix.png) … 各サービスを公式ロゴでプロット＋キャラ
 *   ② カテゴリー早見表(chaosmap.png) … 5分類のボックス（全チップ公式ロゴ）
 *   ③ eyecatch(eyecatch.jpg) … 早見表を取り込んだ16:9
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

// サービス名 → 公式アプリロゴ
const LOGO = {
  '楽天ポイント':'rakuten.png','PayPay':'paypay.png','dポイント':'dpoint.png','Vポイント':'vpoint.png','Ponta':'ponta.png',
  'WAON':'waon.png','nanaco':'nanaco.png','JRE POINT':'jrepoint.png','三井SP':'mitsuisp.png','丸の内':'marunouchi.png',
  'モッピー':'moppy.png','ハピタス':'hapitas.png','ポイントインカム':'pointincome.png','ちょびリッチ':'chobirich.png','ECナビ':'ecnavi.png',
  'トリマ':'torima.png','ANA Pocket':'anapocket.png','JAL Wellness':'jalwellness.png','dヘルスケア':'dhealth.png','楽天ヘルスケア':'rakutenhealth.png',
  'マクロミル':'macromill.png','楽天インサイト':'rakuteninsight.png','Powl':'powl.png','キューモニター':'cuemonitor.png',
};
const lg = (name) => LOGO[name] ? `<img class="chip-logo" src="file://${LOGO_DIR}/${LOGO[name]}" alt="">` : '';

// 5カテゴリ
const CATS = [
  { key:'A', color:'#D63E76', name:'共通ポイント', sub:'経済圏＝土台', role:'日常の支払いでほっといて貯まる主軸',
    items:['楽天ポイント','PayPay','dポイント','Vポイント','Ponta'] },
  { key:'B', color:'#7A3FBF', name:'流通・交通・電子マネー', sub:'生活圏＝第二の軸', role:'よく行く店・路線で“濃く”貯まる',
    items:['WAON','nanaco','JRE POINT','三井SP','丸の内'] },
  { key:'C', color:'#1E6EC8', name:'ポイントサイト', sub:'案件型＝増幅', role:'申込・買い物を“経由”して二重取り',
    items:['モッピー','ハピタス','ポイントインカム','ちょびリッチ','ECナビ'] },
  { key:'D', color:'#2DAF5F', name:'移動・歩数ポイ活', sub:'ついで型＝回収', role:'歩く・移動の“ついで”に小銭/マイル',
    items:['トリマ','ANA Pocket','JAL Wellness','dヘルスケア','楽天ヘルスケア'] },
  { key:'E', color:'#E6892A', name:'アンケート・スキマ', sub:'スキマ型＝回収', role:'空き時間を能動的に小銭へ',
    items:['マクロミル','楽天インサイト','Powl','キューモニター'] },
];

const FONT_FACE = `
  @font-face{font-family:"RocknRoll One";src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:400;src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:700;src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2");}
  @font-face{font-family:"Zen Maru Gothic";font-weight:900;src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2");}
  @font-face{font-family:"Bebas Neue";src:url("file://${FONTS}/bebas-neue-latin-400.woff2") format("woff2");}`;
const BG = `radial-gradient(circle at 4% 6%, #FDE4EE 0%, transparent 32%),radial-gradient(circle at 98% 96%, #FFFBEE 0%, transparent 38%),linear-gradient(135deg,#FFF5F8 0%,#FFFFFF 52%,#FFFBEE 100%)`;

function catBox(c, compact) {
  const chips = c.items.map(it => `<span class="chip${LOGO[it]?' has-logo':''}">${lg(it)}${esc(it)}</span>`).join('');
  return `
  <div class="box${c.key==='E'?' wide':''}" style="--cc:${c.color}">
    <div class="box-head"><span class="cat-badge">${c.key}</span><span class="cat-name">${esc(c.name)}<i>${esc(c.sub)}</i></span></div>
    ${compact?'':`<div class="box-role">${esc(c.role)}</div>`}
    <div class="chips">${chips}</div>
  </div>`;
}

// ===== ① カテゴリー早見表 1600x1300（5分類・全ロゴ）=====
function tableHtml() {
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;} html,body{width:1600px;height:1300px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;overflow:hidden;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:44px 54px 36px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:center;}
  .brand{display:inline-flex;align-items:center;gap:11px;background:#fff;border:2px solid #FDE4EE;padding:10px 22px 10px 15px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:19px;height:19px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:25px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:24px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);box-shadow:0 10px 22px -8px rgba(214,62,118,.55);}
  .titleband{text-align:center;margin:12px 0 6px;}
  .titleband .kk{color:#D63E76;font-weight:900;font-size:24px;}
  .titleband h1{font-family:"RocknRoll One";font-size:54px;line-height:1.08;margin-top:4px;}
  .titleband h1 .mk{position:relative;z-index:0;}.titleband h1 .mk::after{content:"";position:absolute;left:-4px;right:-4px;bottom:8px;height:20px;background:#FFEC00;z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .grid{flex:1;display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-top:10px;}
  .box{background:#fff;border:3px solid var(--cc);border-radius:22px;padding:0 0 18px;overflow:hidden;box-shadow:0 14px 32px -18px rgba(0,0,0,.26);display:flex;flex-direction:column;}
  .box.wide{grid-column:1/3;}
  .box-head{display:flex;align-items:center;gap:15px;background:var(--cc);color:#fff;padding:14px 22px;}
  .cat-badge{width:48px;height:48px;flex:0 0 48px;border-radius:13px;background:rgba(255,255,255,.22);font-family:"Bebas Neue";font-size:36px;display:flex;align-items:center;justify-content:center;}
  .cat-name{font-family:"RocknRoll One";font-size:30px;line-height:1;}
  .cat-name i{font-style:normal;font-family:"Zen Maru Gothic";font-weight:700;font-size:17px;margin-left:10px;opacity:.92;}
  .box-role{font-size:18px;font-weight:700;color:#5A4651;padding:13px 22px 2px;}
  .chips{display:flex;flex-wrap:wrap;gap:11px;padding:13px 22px 0;}
  .chip{display:inline-flex;align-items:center;gap:9px;background:#fff;border:2.5px solid var(--cc);color:var(--cc);font-weight:900;font-size:22px;padding:7px 18px 7px 7px;border-radius:999px;box-shadow:0 4px 10px -6px rgba(0,0,0,.18);}
  .chip-logo{width:38px;height:38px;border-radius:9px;object-fit:cover;flex:0 0 38px;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="titleband"><div class="kk">ポイ活、種類が多すぎ問題を解決</div><h1>ポイントサービス <span class="mk">カテゴリー早見表</span> 2026</h1></div>
    <div class="grid">${CATS.map(c=>catBox(c,false)).join('')}</div>
  </div>
  </body></html>`;
}

// ===== ② 4象限カオスマップ 1600x1240（ロゴでプロット＋キャラ中央）=====
// x:0=受動的(ほっといて貯まる) 100=能動的(動いて稼ぐ) / y:0=リターン大(上) 100=リターン小(下)
const PLOT = [
  // A 共通(magenta) 左上
  {n:'楽天ポイント',x:12,y:17,c:'#D63E76',l:'rakuten.png'},{n:'Vポイント',x:27,y:21,c:'#D63E76',l:'vpoint.png'},
  {n:'dポイント',x:15,y:29,c:'#D63E76',l:'dpoint.png'},{n:'PayPay',x:25,y:35,c:'#D63E76',l:'paypay.png'},{n:'Ponta',x:11,y:40,c:'#D63E76',l:'ponta.png'},
  // B 流通・交通(purple) 中央左
  {n:'JRE POINT',x:41,y:18,c:'#7A3FBF',l:'jrepoint.png'},{n:'WAON',x:43,y:33,c:'#7A3FBF',l:'waon.png'},
  {n:'三井SP',x:35,y:42,c:'#7A3FBF',l:'mitsuisp.png'},{n:'nanaco',x:46,y:46,c:'#7A3FBF',l:'nanaco.png'},{n:'丸の内',x:37,y:53,c:'#7A3FBF',l:'marunouchi.png'},
  // C サイト(blue) 右上
  {n:'モッピー',x:72,y:15,c:'#1E6EC8',l:'moppy.png'},{n:'ハピタス',x:83,y:23,c:'#1E6EC8',l:'hapitas.png'},
  {n:'P.インカム',x:69,y:31,c:'#1E6EC8',l:'pointincome.png'},{n:'ちょびリッチ',x:85,y:37,c:'#1E6EC8',l:'chobirich.png'},{n:'ECナビ',x:73,y:44,c:'#1E6EC8',l:'ecnavi.png'},
  // D 移動(green) 左下
  {n:'トリマ',x:17,y:66,c:'#2DAF5F',l:'torima.png'},{n:'ANA Pocket',x:31,y:60,c:'#2DAF5F',l:'anapocket.png'},
  {n:'JAL',x:40,y:71,c:'#2DAF5F',l:'jalwellness.png'},{n:'dヘルスケア',x:15,y:78,c:'#2DAF5F',l:'dhealth.png'},{n:'楽天ヘルスケア',x:28,y:85,c:'#2DAF5F',l:'rakutenhealth.png'},
  // E アンケート(orange) 右下
  {n:'マクロミル',x:73,y:65,c:'#E6892A',l:'macromill.png'},{n:'楽天インサイト',x:85,y:73,c:'#E6892A',l:'rakuteninsight.png'},
  {n:'Powl',x:69,y:82,c:'#E6892A',l:'powl.png'},{n:'キューモニター',x:83,y:87,c:'#E6892A',l:'cuemonitor.png'},
];

function matrixHtml() {
  const pins = PLOT.map(p=>`<div class="pin" style="left:${p.x}%;top:${p.y}%;--pc:${p.c}"><img src="file://${LOGO_DIR}/${p.l}" alt=""><span class="pl">${esc(p.n)}</span></div>`).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;} html,body{width:1600px;height:1240px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:40px 56px 34px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:center;}
  .brand{display:inline-flex;align-items:center;gap:11px;background:#fff;border:2px solid #FDE4EE;padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:24px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:23px;padding:9px 20px;border-radius:14px;transform:rotate(3deg);}
  .ttl{text-align:center;font-family:"RocknRoll One";font-size:46px;margin:8px 0 0;}
  .ttl .mk{position:relative;z-index:0;}.ttl .mk::after{content:"";position:absolute;left:-4px;right:-4px;bottom:5px;height:17px;background:#FFEC00;z-index:-1;border-radius:4px;}
  .plot{position:relative;flex:1;margin:96px 96px 30px;}
  .q{position:absolute;width:50%;height:50%;opacity:.55;}
  .q1{left:0;top:0;background:radial-gradient(circle at 32% 32%,#FCE2EC,transparent 72%);}
  .q2{right:0;top:0;background:radial-gradient(circle at 68% 32%,#E9E2FB,transparent 72%);}
  .q3{left:0;bottom:0;background:radial-gradient(circle at 32% 68%,#E4F5EA,transparent 72%);}
  .q4{right:0;bottom:0;background:radial-gradient(circle at 68% 68%,#FCEEDD,transparent 72%);}
  .qlabel{position:absolute;font-weight:900;font-size:21px;padding:7px 15px;border-radius:11px;color:#fff;line-height:1.25;box-shadow:0 6px 14px -8px rgba(0,0,0,.4);}
  .ql1{left:10px;top:8px;background:#D63E76;}.ql2{right:10px;top:8px;background:#1E6EC8;}
  .ql3{left:10px;bottom:8px;background:#2DAF5F;}.ql4{right:10px;bottom:8px;background:#E6892A;}
  .axis-x{position:absolute;left:-20px;right:-20px;top:50%;height:4px;background:#2A1923;transform:translateY(-50%);border-radius:2px;}
  .axis-y{position:absolute;top:-30px;bottom:-30px;left:50%;width:4px;background:#2A1923;transform:translateX(-50%);border-radius:2px;}
  .axlbl{position:absolute;font-weight:900;font-size:20px;color:#2A1923;background:#fff;padding:5px 13px;border-radius:9px;border:2.5px solid #2A1923;line-height:1.2;text-align:center;}
  .ax-left{right:calc(100% + 14px);top:50%;transform:translateY(-50%);}
  .ax-right{left:calc(100% + 14px);top:50%;transform:translateY(-50%);}
  .ax-top{left:50%;bottom:calc(100% + 16px);transform:translateX(-50%);}
  .ax-bottom{left:50%;top:calc(100% + 16px);transform:translateX(-50%);}
  .pin{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:4px;z-index:5;}
  .pin img{width:58px;height:58px;border-radius:13px;object-fit:cover;box-shadow:0 6px 14px -6px rgba(0,0,0,.42);border:3px solid var(--pc);background:#fff;}
  .pl{font-weight:900;font-size:16px;color:#2A1923;background:#fff;padding:2px 8px;border-radius:999px;box-shadow:0 3px 8px -4px rgba(0,0,0,.3);white-space:nowrap;}
  .navi{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);z-index:8;width:150px;height:150px;border-radius:50%;background:#fff;border:5px solid #D63E76;box-shadow:0 12px 28px -10px rgba(214,62,118,.6);overflow:hidden;display:flex;align-items:flex-end;justify-content:center;}
  .navi img{width:140px;height:140px;object-fit:cover;object-position:50% 18%;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="ttl">ポイントサービス <span class="mk">4象限マップ</span> 2026</div>
    <div class="plot">
      <div class="q q1"></div><div class="q q2"></div><div class="q q3"></div><div class="q q4"></div>
      <div class="qlabel ql1">A 自動で貯まる土台<br>＝共通ポイント</div>
      <div class="qlabel ql2">C 本気で稼ぐ<br>＝ポイントサイト</div>
      <div class="qlabel ql3">B/D ついで・生活圏<br>＝流通系/移動</div>
      <div class="qlabel ql4">E スキマで小銭<br>＝アンケート</div>
      <div class="axis-x"></div><div class="axis-y"></div>
      <div class="axlbl ax-left">受動的<br>ほっといて貯まる</div>
      <div class="axlbl ax-right">能動的<br>動いて稼ぐ</div>
      <div class="axlbl ax-top">リターン大</div>
      <div class="axlbl ax-bottom">リターン小</div>
      ${pins}
      <div class="navi"><img src="file://${ASSETS_T}/expr-05-smug.png" alt=""></div>
    </div>
  </div>
  </body></html>`;
}

// ===== ③ eyecatch 16:9（早見表の5ボックスを右に取り込む）=====
function eyecatchHtml() {
  const grid = CATS.map(c=>catBox(c,true)).join('');
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_FACE}
  *{margin:0;padding:0;box-sizing:border-box;} html,body{width:1600px;height:900px;}
  body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;position:relative;overflow:hidden;background:${BG};}
  .dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(214,62,118,.06) 1.6px,transparent 1.6px);background-size:30px 30px;}
  .stage{position:absolute;inset:0;padding:42px 50px 36px;display:flex;flex-direction:column;}
  .head{display:flex;justify-content:space-between;align-items:flex-start;}
  .brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid #FDE4EE;padding:9px 20px 9px 14px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
  .brand .b-dot{width:18px;height:18px;border-radius:50%;background:#D63E76;}
  .brand span{font-family:"RocknRoll One";font-size:23px;}
  .badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:23px;padding:10px 22px;border-radius:14px;transform:rotate(3deg);}
  .body{flex:1;display:flex;gap:30px;margin-top:14px;min-height:0;}
  .left{width:548px;flex:0 0 548px;display:flex;flex-direction:column;}
  .kk{color:#D63E76;font-weight:900;font-size:24px;}
  h1{font-family:"RocknRoll One";line-height:1.12;margin-top:6px;}
  h1 .l1{font-size:60px;display:block;white-space:nowrap;}h1 .l2{font-size:66px;display:block;margin-top:2px;white-space:nowrap;}
  h1 .mk{position:relative;z-index:0;}h1 .mk::after{content:"";position:absolute;left:-6px;right:-6px;bottom:8px;height:24px;background:#FFEC00;z-index:-1;border-radius:4px;transform:rotate(-1deg);}
  .sub{font-size:25px;font-weight:700;color:#5A4651;margin-top:18px;}
  .charwrap{margin-top:auto;display:flex;align-items:flex-end;gap:14px;}
  .char{width:280px;height:280px;object-fit:contain;filter:drop-shadow(0 12px 20px rgba(120,30,60,.25));}
  .speech{position:relative;background:#fff;border:2px solid #FDE4EE;border-radius:20px;padding:14px 18px;font-size:23px;font-weight:900;color:#A82959;box-shadow:0 10px 22px -12px rgba(214,62,118,.5);margin-bottom:52px;white-space:pre-line;text-align:center;}
  .speech::after{content:"";position:absolute;left:-12px;bottom:20px;border:10px solid transparent;border-right-color:#fff;}
  .right{flex:1;min-width:0;display:grid;grid-template-columns:1fr 1fr;grid-template-rows:1fr 1fr 1fr;gap:12px;}
  .box{background:#fff;border:2.5px solid var(--cc);border-radius:14px;overflow:hidden;box-shadow:0 10px 24px -16px rgba(0,0,0,.3);display:flex;flex-direction:column;min-height:0;}
  .box.wide{grid-column:1/3;}
  .box-head{display:flex;align-items:center;gap:8px;background:var(--cc);color:#fff;padding:6px 10px;}
  .cat-badge{width:24px;height:24px;flex:0 0 24px;border-radius:6px;background:rgba(255,255,255,.22);font-family:"Bebas Neue";font-size:19px;display:flex;align-items:center;justify-content:center;}
  .cat-name{font-family:"RocknRoll One";font-size:16px;line-height:1.05;}.cat-name i{display:none;}
  .chips{display:flex;flex-wrap:wrap;gap:5px;padding:7px 9px;align-content:flex-start;}
  .chip{display:inline-flex;align-items:center;gap:4px;background:#fff;border:1.5px solid var(--cc);color:var(--cc);font-weight:900;font-size:12px;padding:2px 7px 2px 2px;border-radius:999px;}
  .chip-logo{width:18px;height:18px;border-radius:4px;object-fit:cover;flex:0 0 18px;}
  </style></head><body>
  <div class="dots"></div>
  <div class="stage">
    <div class="head"><div class="brand"><span class="b-dot"></span><span>Daily Hack</span></div><div class="badge">2026 保存版</div></div>
    <div class="body">
      <div class="left">
        <div class="kk">ポイ活、種類が多すぎ問題</div>
        <h1><span class="l1">ポイントサービス</span><span class="l2">全部<span class="mk">使い倒した</span></span></h1>
        <div class="sub">5分類×4象限マップで“自分の地図”を作る</div>
        <div class="charwrap"><img class="char" src="file://${ASSETS_T}/expr-05-smug.png" alt=""><div class="speech">まず軸を\n1つ決めな</div></div>
      </div>
      <div class="right">${grid}</div>
    </div>
  </div>
  </body></html>`;
}

async function render(html, w, h, outPath, type) {
  const tmpHtml = path.join('/tmp', `chaosmap-${type}-${w}x${h}.html`);
  fs.writeFileSync(tmpHtml, html);
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 2 });
  await page.goto('file://' + tmpHtml, { waitUntil: 'networkidle' });
  await page.evaluate(async () => { if (document.fonts && document.fonts.ready) await document.fonts.ready; });
  await page.waitForTimeout(500);
  await page.screenshot(type === 'jpeg' ? { path: outPath, type: 'jpeg', quality: 92 } : { path: outPath, type: 'png' });
  await browser.close();
  console.log('rendered', outPath);
}

(async () => {
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });
  await render(matrixHtml(), 1600, 1240, path.join(OUT_DIR, 'chaosmap-matrix.png'), 'png');
  await render(tableHtml(), 1600, 1300, path.join(OUT_DIR, 'chaosmap.png'), 'png');
  await render(eyecatchHtml(), 1600, 900, path.join(OUT_DIR, 'eyecatch.jpg'), 'jpeg');
})();
