#!/usr/bin/env node
/**
 * 羽田 vs 成田 直行便ベン図（Daily Hackオリジナル・v2）
 * ※参照元(itsukaichi)のフラッグ敷き詰め図とは別デザイン：
 *   マスコット登場／エリア別グルーピング／都市粒度／独自配色・出発案内風ヘッダー。
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
const MASCOT = '/Users/ny_taxa/projects/anta-baka-x/blog/public/images/expr-04-cheer.png';
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
const grp = (arr, tone) => arr.map(([r, c]) =>
  `<div class="grp"><span class="gr gr-${tone}">${r}</span><span class="gc">${c}</span></div>`).join('');

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0;box-sizing:border-box;}
  body{width:1200px;height:1430px;font-family:'Hiragino Sans',sans-serif;
    background:radial-gradient(120% 80% at 50% 0%,#EAF6FF 0%,#F7F1FB 55%,#FFF 100%);color:#26262E;position:relative;overflow:hidden;}
  /* 出発案内風ヘッダー */
  .board{margin:34px 44px 0;background:linear-gradient(90deg,#14243d,#20344f);border-radius:20px;padding:22px 30px;
    display:flex;align-items:center;gap:18px;box-shadow:0 14px 30px -14px rgba(20,36,61,.6);}
  .board .pin{font-size:34px;}
  .board h1{color:#fff;font-size:40px;font-weight:900;letter-spacing:.5px;line-height:1.1;}
  .board h1 .a{color:#FF7DAe;} .board h1 .b{color:#5FD0EC;}
  .board .sub{color:#b9c6da;font-size:17px;font-weight:700;margin-top:4px;}
  .dep{position:absolute;top:38px;right:60px;color:#FFD36A;font-weight:900;font-size:16px;text-align:right;line-height:1.5;}
  /* ベン本体 */
  .stage{position:relative;width:1200px;height:940px;margin-top:12px;}
  .circle{position:absolute;top:150px;width:700px;height:700px;border-radius:50%;filter:drop-shadow(0 20px 30px rgba(0,0,0,.06));}
  .cH{left:14px;background:radial-gradient(circle at 40% 35%,rgba(255,125,174,.20),rgba(255,125,174,.10));border:4px solid #FF7DAe;}
  .cN{right:14px;background:radial-gradient(circle at 60% 35%,rgba(95,208,236,.22),rgba(95,208,236,.10));border:4px solid #33BFE0;}
  .cap{position:absolute;top:66px;font-weight:900;font-size:31px;display:flex;flex-direction:column;align-items:center;}
  .capH{left:150px;color:#E14b86;width:280px;} .capN{right:150px;color:#1596b6;width:280px;}
  .cap .n{font-size:17px;color:#8a8a93;font-weight:800;margin-top:2px;}
  .cap .em{font-size:22px;margin-bottom:2px;}
  .zone{position:absolute;display:flex;flex-direction:column;gap:12px;}
  .zH{top:250px;left:48px;width:300px;} .zN{top:250px;right:48px;width:300px;} .zB{top:300px;left:452px;width:296px;}
  .zhd{font-size:21px;font-weight:900;padding:6px 16px;border-radius:999px;align-self:center;}
  .zhH{background:#FBE0EC;color:#c23a72;} .zhB{background:#E7E1F5;color:#5b4b8a;} .zhN{background:#D6F2F8;color:#0f88a5;}
  .grp{line-height:1.35;}
  .gr{display:inline-block;font-size:13px;font-weight:900;color:#fff;padding:2px 9px;border-radius:6px;margin-right:6px;vertical-align:middle;}
  .gr-H{background:#E884Ac;} .gr-B{background:#8f7fc0;} .gr-N{background:#43b8d3;}
  .gc{font-size:17.5px;font-weight:700;color:#33333c;}
  .zB .gc{font-size:17px;}
  /* マスコット吹き出し */
  .mascot{position:absolute;bottom:8px;left:20px;width:210px;}
  .mascot img{width:210px;height:auto;display:block;}
  .bubble{position:absolute;bottom:150px;left:150px;background:#fff;border:3px solid #E14b86;border-radius:18px;
    padding:14px 20px;font-size:22px;font-weight:900;color:#c23a72;box-shadow:0 12px 24px -12px rgba(225,75,134,.5);max-width:430px;line-height:1.4;}
  .bubble:after{content:'';position:absolute;left:-16px;bottom:26px;border:9px solid transparent;border-right-color:#E14b86;}
  .foot{position:absolute;bottom:34px;width:100%;text-align:center;font-size:17px;color:#7a7a83;font-weight:700;}
  .foot b{color:#E14b86;}
</style></head><body>
  <div class="board">
    <span class="pin">✈️</span>
    <div><h1><span class="a">羽田</span> vs <span class="b">成田</span>｜直行便で行ける海外</h1>
    <div class="sub">JAL・ANA自社直行便で比較｜2026年7月時点・公式確認（都市ベース）</div></div>
  </div>

  <div class="stage">
    <div class="circle cH"></div>
    <div class="circle cN"></div>
    <div class="cap capH"><span class="em">🩷</span>羽田(HND)<span class="n">18都市</span></div>
    <div class="cap capN"><span class="em">💙</span>成田(NRT)<span class="n">11都市</span></div>

    <div class="zone zH">
      <span class="zhd zhH">羽田だけ</span>
      ${grp(hnd, 'H')}
    </div>
    <div class="zone zB">
      <span class="zhd zhB">両方いける（19都市）</span>
      ${grp(both, 'B')}
    </div>
    <div class="zone zN">
      <span class="zhd zhN">成田だけ</span>
      ${grp(nrt, 'N')}
    </div>

    <div class="bubble">欧州＆北米主要は“羽田だけ”、<br>穴場は“成田だけ”に出るのよ！</div>
    <div class="mascot"><img src="${mascotB64}" alt=""></div>
  </div>
  <div class="foot">出典：JAL・ANA公式（自社直行便・2026年7月時点）｜<b>Daily Hack</b> daily-hack.fieldbeside.com ｜ @heng_ji31590</div>
</body></html>`;

const tmp = path.join(os.tmpdir(), 'venn-nh2.html');
fs.writeFileSync(tmp, html);
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1200, height: 1430 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('file://' + tmp, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);
fs.mkdirSync(path.dirname(out), { recursive: true });
await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1200, height: 1430 } });
await browser.close();
console.log('saved', out);
