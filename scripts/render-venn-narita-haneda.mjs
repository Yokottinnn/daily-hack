#!/usr/bin/env node
/**
 * 羽田 vs 成田 直行便ベン図レンダラ（記事用インフォグラフィック）
 * Playwright は sns-templates の node_modules を借用。
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

const out = process.argv[2] || 'public/images/narita-haneda-overseas-direct-2026/venn.png';

// --- データ（JAL/ANA自社直行便・2026年7月時点・公式確認） ---
const hndOnly = ['ロンドン','パリ','ヘルシンキ','ミュンヘン','ウィーン','ミラノ','ストックホルム','イスタンブール','ドーハ','ソウル','北京','広州','深圳','青島','シドニー','ニューヨーク','ワシントンD.C.','ヒューストン'];
const both = ['香港','台北','バンコク','シンガポール','マニラ','ホーチミン','クアラルンプール','ジャカルタ','デリー','大連','上海','ホノルル','ロサンゼルス','サンフランシスコ','シアトル','シカゴ','ダラス','バンクーバー','フランクフルト'];
const nrtOnly = ['ハノイ','ベンガルール','ムンバイ','メルボルン','パース','杭州','サンディエゴ','ボストン','メキシコシティ','ブリュッセル','グアム'];

const chip = (s) => `<span class="chip">${s}</span>`;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face{font-family:'HG';src:local('Hiragino Sans'),local('Hiragino Kaku Gothic ProN');}
  *{margin:0;padding:0;box-sizing:border-box;}
  body{width:1200px;height:1320px;font-family:'Hiragino Sans','HG',sans-serif;background:linear-gradient(160deg,#FFF6FA 0%,#F3FBFD 100%);color:#2A2A33;position:relative;overflow:hidden;}
  .badge{position:absolute;top:34px;left:44px;background:#E14b86;color:#fff;font-weight:800;font-size:22px;padding:8px 20px;border-radius:999px;box-shadow:0 8px 18px -8px rgba(225,75,134,.6);}
  .head{text-align:center;padding:40px 40px 6px;}
  h1{font-size:52px;font-weight:900;letter-spacing:.5px;margin-top:44px;}
  h1 .hnd{color:#E14b86;} h1 .nrt{color:#1E9DBb;}
  .sub{font-size:20px;color:#5c5c66;margin-top:12px;font-weight:700;}
  .stage{position:relative;width:1200px;height:900px;margin-top:6px;}
  .circle{position:absolute;top:120px;width:660px;height:660px;border-radius:50%;}
  .cHND{left:30px;background:rgba(225,75,134,.12);border:4px solid rgba(225,75,134,.55);}
  .cNRT{right:30px;background:rgba(30,157,187,.12);border:4px solid rgba(30,157,187,.55);}
  .ctitle{position:absolute;font-weight:900;font-size:30px;top:56px;}
  .tHND{left:150px;color:#E14b86;text-align:center;width:300px;}
  .tNRT{right:150px;color:#1E9DBb;text-align:center;width:300px;}
  .ctitle .cnt{display:block;font-size:19px;font-weight:800;color:#7a7a83;margin-top:2px;}
  .zone{position:absolute;top:210px;display:flex;flex-direction:column;gap:9px;align-items:center;}
  .zHND{left:70px;width:300px;}
  .zBOTH{left:450px;width:300px;top:250px;}
  .zNRT{right:70px;width:300px;}
  .chip{font-size:21px;font-weight:700;line-height:1;white-space:nowrap;}
  .zHND .chip{color:#c23a72;} .zNRT .chip{color:#127e97;} .zBOTH .chip{color:#5b4b8a;}
  .zlabel{font-size:22px;font-weight:900;margin-bottom:6px;padding:5px 16px;border-radius:999px;}
  .lHND{background:#FBE3ED;color:#c23a72;} .lBOTH{background:#EAE6F6;color:#5b4b8a;} .lNRT{background:#DDF2F6;color:#127e97;}
  .tagl{position:absolute;font-weight:900;font-size:22px;}
  .tag1{top:150px;left:60px;color:#E14b86;transform:rotate(-4deg);}
  .tag2{top:150px;right:60px;color:#1E9DBb;transform:rotate(4deg);text-align:right;}
  .foot{position:absolute;bottom:26px;width:100%;text-align:center;font-size:18px;color:#7a7a83;font-weight:700;}
  .foot b{color:#E14b86;}
</style></head><body>
  <div class="badge">Daily Hack</div>
  <div class="head">
    <h1><span class="hnd">羽田</span> vs <span class="nrt">成田</span>｜直行便で行ける海外</h1>
    <div class="sub">JAL・ANA自社直行便で比較（2026年7月時点・公式確認）</div>
  </div>
  <div class="stage">
    <div class="circle cHND"></div>
    <div class="circle cNRT"></div>
    <div class="tagl tag1">✈ 欧州・北米主要は<br>ほぼ羽田！</div>
    <div class="tagl tag2">✈ 穴場路線は<br>成田に！</div>

    <div class="zone zHND">
      <span class="zlabel lHND">羽田だけ ${hndOnly.length}都市</span>
      ${hndOnly.map(chip).join('')}
    </div>
    <div class="zone zBOTH">
      <span class="zlabel lBOTH">両方 ${both.length}都市</span>
      ${both.map(chip).join('')}
    </div>
    <div class="zone zNRT">
      <span class="zlabel lNRT">成田だけ ${nrtOnly.length}都市</span>
      ${nrtOnly.map(chip).join('')}
    </div>
  </div>
  <div class="foot">出典：JAL・ANA公式（自社直行便・2026年7月時点）｜<b>Daily Hack</b> daily-hack.fieldbeside.com ｜ @heng_ji31590</div>
</body></html>`;

const tmp = path.join(os.tmpdir(), 'venn-nh.html');
fs.writeFileSync(tmp, html);
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1200, height: 1320 }, deviceScaleFactor: 2 });
const page = await ctx.newPage();
await page.goto('file://' + tmp, { waitUntil: 'networkidle' });
await page.waitForTimeout(500);
fs.mkdirSync(path.dirname(out), { recursive: true });
await page.screenshot({ path: out, clip: { x: 0, y: 0, width: 1200, height: 1320 } });
await browser.close();
console.log('saved', out);
