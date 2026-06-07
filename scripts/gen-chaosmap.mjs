#!/usr/bin/env node
/**
 * gen-chaosmap.mjs — 「ポイントサービス カオスマップ 2026」業界地図インフォグラフィックを生成。
 * 4カテゴリのゾーンにサービスをチップ配置。HTML+Playwright(sns-templatesのchromium借用)。
 * Usage: node scripts/gen-chaosmap.mjs <out.jpg>
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import path from 'node:path';
const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');
const FONTS = SNS + '/fonts';

const ZONES = [
  { key:'A', role:'土台：日常の支払いで貯まる', title:'共通ポイント（経済圏）', color:'#D63E76', bg:'#FDE8F0',
    chips:['楽天ポイント','PayPayポイント','dポイント','Vポイント','Pontaポイント','au PAY'] },
  { key:'B', role:'増幅：申込・買い物を“経由”', title:'ポイントサイト（案件型）', color:'#1E6EC8', bg:'#E6F0FB',
    chips:['モッピー','ハピタス','ポイントインカム','ちょびリッチ','ワラウ','ECナビ'] },
  { key:'C', role:'回収：歩く・移動の“ついで”', title:'移動・歩数ポイ活', color:'#2DAF5F', bg:'#E6F6EC',
    chips:['トリマ','ANA Pocket','JAL Wellness','dヘルスケア','楽天ヘルスケア','Coke ON'] },
  { key:'D', role:'スキマ：空き時間を小銭に', title:'アンケート・スキマ系', color:'#E6892A', bg:'#FCEFE0',
    chips:['マクロミル','楽天インサイト','infoQ','リサーチパネル'] },
];

function chips(z){return z.chips.map(c=>`<span class="chip" style="--c:${z.color}">${c}</span>`).join('');}
function zone(z){return `
  <div class="zone" style="--zc:${z.color};--zbg:${z.bg}">
    <div class="z-head"><span class="z-key">${z.key}</span><div class="z-titles"><div class="z-title">${z.title}</div><div class="z-role">${z.role}</div></div></div>
    <div class="chips">${chips(z)}</div>
  </div>`;}

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:"RocknRoll One";src:url("file://${FONTS}/rocknroll-one-japanese-400.woff2") format("woff2");}
@font-face{font-family:"Zen Maru Gothic";font-weight:400;src:url("file://${FONTS}/zen-maru-gothic-japanese-400.woff2") format("woff2");}
@font-face{font-family:"Zen Maru Gothic";font-weight:700;src:url("file://${FONTS}/zen-maru-gothic-japanese-700.woff2") format("woff2");}
@font-face{font-family:"Zen Maru Gothic";font-weight:900;src:url("file://${FONTS}/zen-maru-gothic-japanese-900.woff2") format("woff2");}
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:1600px;height:1000px;}
body{font-family:"Zen Maru Gothic",sans-serif;color:#2A1923;background:linear-gradient(135deg,#FFF5F8,#FFFFFF 55%,#FFFBEE);padding:42px 48px;position:relative;}
.dots{position:absolute;inset:0;background-image:radial-gradient(circle,rgba(120,120,140,.05) 1.6px,transparent 1.6px);background-size:30px 30px;}
.head{display:flex;justify-content:space-between;align-items:center;position:relative;}
.brand{display:inline-flex;align-items:center;gap:10px;background:#fff;border:2px solid #FDE4EE;padding:8px 18px 8px 12px;border-radius:999px;box-shadow:0 8px 20px -10px rgba(214,62,118,.4);}
.brand .d{width:16px;height:16px;border-radius:50%;background:#D63E76;}
.brand span{font-family:"RocknRoll One";font-size:22px;}
h1{font-family:"RocknRoll One";font-size:50px;text-align:center;flex:1;}
.badge{background:#D63E76;color:#fff;font-family:"RocknRoll One";font-size:22px;padding:8px 18px;border-radius:12px;transform:rotate(3deg);}
.flow{text-align:center;margin:10px 0 6px;font-weight:900;font-size:22px;color:#5A4651;position:relative;}
.flow b{color:#D63E76;}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-top:14px;position:relative;}
.zone{background:var(--zbg);border:3px solid var(--zc);border-radius:22px;padding:20px 22px;min-height:340px;}
.z-head{display:flex;align-items:center;gap:14px;margin-bottom:14px;}
.z-key{width:54px;height:54px;flex:0 0 54px;border-radius:14px;background:var(--zc);color:#fff;font-family:"RocknRoll One";font-size:32px;display:flex;align-items:center;justify-content:center;}
.z-title{font-weight:900;font-size:28px;color:#2A1923;}
.z-role{font-size:16px;color:#5A4651;font-weight:700;margin-top:2px;}
.chips{display:flex;flex-wrap:wrap;gap:12px;}
.chip{background:#fff;border:2px solid var(--c);color:#2A1923;font-weight:900;font-size:22px;padding:10px 18px;border-radius:999px;box-shadow:0 6px 14px -8px rgba(0,0,0,.25);}
.foot{position:absolute;left:48px;right:48px;bottom:28px;display:flex;justify-content:space-between;align-items:center;color:#8a7a82;font-size:18px;}
.foot b{color:#D63E76;font-family:"Zen Maru Gothic";}
</style></head><body>
<div class="dots"></div>
<div class="head"><div class="brand"><span class="d"></span><span>Daily Hack</span></div><h1>ポイントサービス カオスマップ 2026</h1><div class="badge">保存版</div></div>
<div class="flow"><b>A 土台</b>（経済圏を1つ）→ <b>B 増幅</b>（サイト経由で二重取り）→ <b>C / D 回収</b>（ついで・スキマ）</div>
<div class="grid">${zone(ZONES[0])}${zone(ZONES[1])}${zone(ZONES[2])}${zone(ZONES[3])}</div>
<div class="foot"><span>※主要サービスを役割で分類（網羅ではなく代表例）。仕様・還元は変動するため最新は各公式で確認。</span><b>daily-hack.fieldbeside.com</b></div>
</body></html>`;

const out = path.resolve(process.argv[2]);
const tmp = out.replace(/\.(jpg|png)$/i,'.debug.html');
fs.mkdirSync(path.dirname(out),{recursive:true});
fs.writeFileSync(tmp,html);
const b = await chromium.launch();
const c = await b.newContext({viewport:{width:1600,height:1000},deviceScaleFactor:2});
const p = await c.newPage();
await p.goto('file://'+tmp,{waitUntil:'networkidle'});
await p.waitForTimeout(500);
const png = out.replace(/\.jpg$/i,'.png');
await p.screenshot({path:png,clip:{x:0,y:0,width:1600,height:1000}});
await b.close();
const { execSync } = require('child_process');
execSync(`python3 -c "from PIL import Image; Image.open('${png}').convert('RGB').resize((1600,1000), Image.LANCZOS).save('${out}', quality=90)"`);
fs.unlinkSync(png); fs.unlinkSync(tmp);
console.log('saved', out);
