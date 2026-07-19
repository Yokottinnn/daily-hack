#!/usr/bin/env node
/**
 * 羽田 vs 成田 直行便 比較インフォグラフィック（Daily Hackオリジナル・v3）
 * ※参照元(itsukaichi)は「2円ベン図＋国旗タイル」。本図は円ベンをやめ、
 *   空港の搭乗案内風「3ゲート・ボーディングパス型パネル」で全く異なる形に。
 * データは JAL/ANA 公式確認済み（2026年7月時点）。
 * Usage: node scripts/render-venn-narita-haneda.mjs <out.png>
 */
import { createRequire } from 'module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const SNS = '/Users/ny_taxa/projects/anta-baka-x/sns-templates';
const require = createRequire(SNS + '/');
const { chromium } = require('playwright');
const MASCOT = '/Users/ny_taxa/projects/anta-baka-x/blog/public/images/expr-05-smug.png';
const mascotB64 = 'data:image/png;base64,' + fs.readFileSync(MASCOT).toString('base64');

const out = process.argv[2] || 'public/images/narita-haneda-overseas-direct-2026/venn.png';

// --- データ（JAL/ANA自社直行便・2026年7月時点・公式確認）※エリア別 ---
const hnd = [
  ['欧州', 'ロンドン・パリ・ヘルシンキ・ミュンヘン・ウィーン・ミラノ・ストックホルム・イスタンブール'],
  ['中東', 'ドーハ'],
  ['アジア', 'ソウル・北京・広州・深圳・青島'],
  ['オセアニア', 'シドニー'],
  ['北米', 'ニューヨーク・ワシントンD.C.・ヒューストン'],
];
const both = [
  ['アジア', '香港・台北・バンコク・シンガポール・マニラ・ホーチミン・クアラルンプール・ジャカルタ・デリー・大連・上海'],
  ['北米', 'ロサンゼルス・サンフランシスコ・シアトル・シカゴ・ダラス・バンクーバー'],
  ['欧州', 'フランクフルト'],
  ['ハワイ', 'ホノルル'],
];
const nrt = [
  ['アジア', 'ハノイ・ベンガルール・ムンバイ・杭州'],
  ['オセアニア', 'メルボルン・パース'],
  ['北米・中南米', 'サンディエゴ・ボストン・メキシコシティ'],
  ['欧州', 'ブリュッセル'],
  ['リゾート', 'グアム'],
];
const rows = (arr, tone) => arr.map(([r, c]) =>
  `<div class="row"><span class="rg rg-${tone}">${r}</span><span class="rc">${c}</span></div>`).join('');

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box;}
  body{width:1240px;height:890px;font-family:'Hiragino Sans',sans-serif;
    background:linear-gradient(165deg,#EAF4FF 0%,#F4F0FA 60%,#FFF 100%);color:#25252d;position:relative;overflow:hidden;}
  .board{margin:32px 40px 0;background:linear-gradient(90deg,#14243d,#223a58);border-radius:18px;padding:20px 28px;display:flex;align-items:center;gap:16px;box-shadow:0 14px 30px -14px rgba(20,36,61,.55);}
  .board .pin{font-size:32px;}
  .board h1{color:#fff;font-size:39px;font-weight:900;line-height:1.1;}
  .board h1 .a{color:#FF7DAe;} .board h1 .b{color:#5FD0EC;}
  .board .sub{color:#b7c5da;font-size:16.5px;font-weight:700;margin-top:4px;}
  /* 3ゲート・パネル */
  .gates{display:flex;gap:18px;align-items:flex-start;margin:26px 34px 0;}
  .panel{flex:1;background:#fff;border-radius:18px;box-shadow:0 16px 34px -20px rgba(30,40,70,.35);overflow:hidden;border:1px solid #eee;}
  .panel.mid{flex:1.18;box-shadow:0 22px 40px -18px rgba(120,90,190,.45);transform:translateY(-10px);border:2px solid #b7a6e6;}
  .ptop{padding:16px 18px 13px;color:#fff;position:relative;}
  .t-H{background:linear-gradient(135deg,#F0619A,#E14b86);} .t-B{background:linear-gradient(135deg,#8f7fd6,#6f5cc0);} .t-N{background:linear-gradient(135deg,#3FC0E4,#1596b6);}
  .ptop .g{font-size:14px;font-weight:800;letter-spacing:2px;opacity:.9;}
  .ptop .ttl{font-size:27px;font-weight:900;margin-top:1px;}
  .ptop .cnt{position:absolute;right:16px;top:14px;font-size:15px;font-weight:900;background:rgba(255,255,255,.22);padding:5px 12px;border-radius:999px;}
  .ptop .plane{position:absolute;right:16px;bottom:-14px;font-size:30px;filter:drop-shadow(0 3px 3px rgba(0,0,0,.15));}
  .pbody{padding:20px 18px 22px;display:flex;flex-direction:column;gap:13px;}
  .row{line-height:1.4;}
  .rg{display:inline-block;font-size:12.5px;font-weight:900;color:#fff;padding:2px 9px;border-radius:6px;margin-right:7px;vertical-align:2px;}
  .rg-H{background:#EA76A6;} .rg-B{background:#8877c9;} .rg-N{background:#3bb6d6;}
  .rc{font-size:17px;font-weight:700;color:#32323c;}
  .mid .midbadge{display:inline-block;background:#efe9fb;color:#5b4b8a;font-size:13px;font-weight:900;padding:3px 12px;border-radius:999px;margin:0 0 4px;}
  .conn{position:absolute;top:230px;font-size:34px;color:#9a8fc7;font-weight:900;}
  .connL{left:388px;} .connR{right:388px;}
  /* マスコット */
  .mascot{position:absolute;bottom:70px;left:40px;width:172px;}
  .mascot img{width:172px;height:auto;display:block;}
  .bubble{position:absolute;bottom:174px;left:230px;background:#fff;border:3px solid #6f5cc0;border-radius:18px;padding:13px 20px;font-size:21px;font-weight:900;color:#5b4b8a;box-shadow:0 12px 24px -12px rgba(111,92,192,.5);max-width:640px;line-height:1.45;}
  .bubble:after{content:'';position:absolute;left:-16px;bottom:24px;border:9px solid transparent;border-right-color:#6f5cc0;}
  .foot{position:absolute;bottom:34px;width:100%;text-align:center;font-size:16.5px;color:#7a7a83;font-weight:700;}
  .foot b{color:#E14b86;}
</style></head><body>
  <div class="board">
    <span class="pin">🛫</span>
    <div><h1><span class="a">羽田</span> vs <span class="b">成田</span>｜直行便で行ける海外</h1>
    <div class="sub">JAL・ANA自社直行便で比較｜2026年7月時点・公式確認（都市ベース）</div></div>
  </div>

  <div class="gates">
    <div class="panel">
      <div class="ptop t-H"><div class="g">GATE HND</div><div class="ttl">羽田だけ</div><div class="cnt">18都市</div><div class="plane">🛫</div></div>
      <div class="pbody">${rows(hnd, 'H')}</div>
    </div>
    <div class="panel mid">
      <div class="ptop t-B"><div class="g">HANEDA ∩ NARITA</div><div class="ttl">両方いける</div><div class="cnt">19都市</div></div>
      <div class="pbody"><span class="midbadge">どっちの空港からもOK</span>${rows(both, 'B')}</div>
    </div>
    <div class="panel">
      <div class="ptop t-N"><div class="g">GATE NRT</div><div class="ttl">成田だけ</div><div class="cnt">11都市</div><div class="plane">🛫</div></div>
      <div class="pbody">${rows(nrt, 'N')}</div>
    </div>
  </div>
  <div class="conn connL">▸</div>
  <div class="conn connR">◂</div>

  <div class="bubble">欧州＆北米主要は“羽田だけ”、穴場は“成田だけ”に集中！<br>まず「どの都市へ行くか」で空港を選ぶのが正解よ。</div>
  <div class="mascot"><img src="${mascotB64}" alt=""></div>
  <div class="foot">出典：JAL・ANA公式（自社直行便・2026年7月時点）｜<b>Daily Hack</b> daily-hack.fieldbeside.com ｜ @heng_ji31590</div>
</body></html>`;

const tmp = path.join(os.tmpdir(), 'gates-nh.html');
fs.writeFileSync(tmp, html);
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1240, height: 890 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('file://' + tmp, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);
fs.mkdirSync(path.dirname(out), { recursive: true });
await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1240, height: 890 } });
await browser.close();
console.log('saved', out);
