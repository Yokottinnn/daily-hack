#!/usr/bin/env node
/**
 * X 告知用の正方形画像 4 枚を作る（サウナ記事）。
 *
 * Jordan の指示（2026-08-30）
 *   - 1 投稿目と 2 投稿目で画像が同じだったので変える
 *   - X 用に **正方形**（1080×1080）にする
 *   - 1 枚目 … オープンする／した施設のまとめ。**記事冒頭のサマリーボックス
 *     （背景に実写を敷いたカード）を正方形の中に取り込む**
 *   - 2〜4 枚目 … **実際にオープンしたサウナの写真**（記事内のものを使う）
 *
 * ## なぜ Playwright なのか
 *
 * サマリーボックスは `src/styles/global.css` の `.event-pick` そのもの。
 * PIL で描き直すと**似て非なるもの**になる。**同じ CSS を使って描く**のが
 * いちばん確実で、記事とカードの見た目が完全に一致する。
 *
 * ## 出典を画像に焼き込む
 *
 * 施設写真は各施設の**公式サイト**から取っている（CC ではない）。
 * X に出すと画像だけが独り歩きするので、**クレジットを画像の中に入れる。**
 * 記事の figcaption と同じ出典を使う。
 *
 * 使い方:
 *   node scripts/gen-sauna-x-cards.mjs
 * 出力:
 *   public/images/sauna-openings-2026/x/1-summary.jpg 〜 4-*.jpg
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const IMG = path.join(ROOT, 'public/images/sauna-openings-2026');
const OUT = path.join(IMG, 'x');
const SIZE = 1080;

const NAVY = '#16243f';
const PINK = '#e8407d';
const url = (p) => 'file://' + path.join(IMG, p);

// ── 1 枚目に載せるカード。記事冒頭のサマリーボックスと同じ中身にする ──
const CARDS = [
  {
    badge: '総数', img: 'photos/sauna-room.jpg',
    h: '首都圏 17 施設',
    p: '新規14・既存のリニューアル3。<b>7月だけで5施設</b>が集中した。',
  },
  {
    badge: '男女', img: 'photos/sento.jpg',
    h: '男性専用8・男女8',
    p: '資料が割れるのが1。<b>女性が入れる8のうち5は大型の複合施設。</b>',
  },
  {
    badge: '料金', img: 'photos/tokyo.jpg',
    h: '550円〜3,700円',
    p: '裏の取れた7施設で<b>6.7倍</b>の開き。同じ「サウナ代」で比べても意味がない。',
  },
  {
    badge: '内訳', img: 'photos/yokohama.jpg',
    h: '東京に 10 施設',
    p: '首都圏17のうち<b>6割が東京</b>。神奈川3・千葉3・埼玉1と続く。',
  },
];

// ── 2〜4 枚目。**実際にオープンしたサウナの写真**。出典は記事の figcaption から ──
const FACILITIES = [
  {
    file: '2-maihama.jpg', img: 'facilities/maihama.jpg',
    open: '♻️ 1/15 リニューアル', name: 'スパ＆ホテル 舞浜ユーラシア',
    lead: '70人収容・<b>国内最大級の開口面積</b>の展望サウナ「グランビューサウナ」',
    specs: ['千葉・舞浜', '2,100円〜', '男女'],
    credit: '画像: スパ＆ホテル 舞浜ユーラシア 公式',
  },
  {
    file: '3-takanawa.jpg', img: 'facilities/takanawa.jpg',
    open: '2/9 オープン', name: '高輪SAUNAS',
    lead: '1,600平米超に<b>男女あわせて9つのサウナ室</b>。『サ道』タナカカツキ氏が総合プロデュース',
    specs: ['高輪ゲートウェイ直結', '3,700円', '男女'],
    credit: '画像: 高輪SAUNAS 公式',
  },
  {
    file: '4-oimachi.jpg', img: 'facilities/oimachi.jpg',
    open: '3/28 オープン', name: 'サウナメッツァ 大井町トラックス',
    lead: '<b>日本初のトラムサウナ。</b>吊り革まで再現され、窓の外を実際の電車が通る',
    specs: ['大井町 徒歩2分', '1,800円〜', '男女'],
    credit: '画像: サウナメッツァ大井町トラックス 公式',
  },
];

const BASE = `
  @font-face { font-family: NSJP; src: local('Noto Sans JP'); }
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: ${SIZE}px; height: ${SIZE}px; overflow: hidden;
    font-family: 'Noto Sans JP', sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  b { color: #ffe0e6; }
`;

// ── 1 枚目: 見出し帯 + サマリーカード 2×2 + 注記 ──
function summaryHtml() {
  const cards = CARDS.map((c) => `
    <div class="pick" style="--pick-img:url('${url(c.img)}')">
      <span class="badge">${c.badge}</span>
      <h4>${c.h}</h4>
      <p>${c.p}</p>
    </div>`).join('');

  return `<style>${BASE}
  body { background: #f7f7f9; display: flex; flex-direction: column; }
  header { background: ${NAVY}; color: #fff; padding: 46px 54px 40px; }
  .kicker { font-size: 27px; font-weight: 700; color: #9fb4d6; letter-spacing: .09em; }
  h1 { font-size: 84px; font-weight: 900; line-height: 1.1; margin-top: 10px; letter-spacing: .01em; }
  .sub { font-size: 30px; font-weight: 700; margin-top: 18px; color: #dbe4f2; }
  .sub em { font-style: normal; color: #ffd45e; }
  .rule { height: 8px; background: linear-gradient(90deg, ${PINK}, #ff8a3d 55%, #ffc043); }

  /* 記事の .event-pick と同じ作り（src/styles/global.css）。似せるのではなく揃える */
  .grid { flex: 1; display: grid; grid-template-columns: 1fr 1fr; gap: 20px; padding: 30px 40px 8px; }
  .pick {
    position: relative; overflow: hidden; border-radius: 22px;
    padding: 22px 24px 24px; color: #fff; isolation: isolate;
    box-shadow: 0 14px 30px -16px rgba(42,25,35,.55);
    display: flex; flex-direction: column; justify-content: flex-end;
  }
  .pick::before {
    content: ""; position: absolute; inset: 0; z-index: -2;
    background-image: var(--pick-img); background-size: cover; background-position: center;
  }
  .pick::after {
    content: ""; position: absolute; inset: 0; z-index: -1;
    background: linear-gradient(180deg, rgba(42,25,35,.30) 0%, rgba(42,25,35,.62) 45%, rgba(42,25,35,.90) 100%);
  }
  .badge {
    align-self: flex-start; background: ${PINK}; color: #fff;
    font-size: 20px; font-weight: 700; padding: 6px 18px; border-radius: 999px;
  }
  .pick h4 { font-size: 38px; font-weight: 900; line-height: 1.25; margin: 12px 0 8px;
             text-shadow: 0 2px 8px rgba(0,0,0,.55); }
  .pick p { font-size: 21px; font-weight: 500; line-height: 1.6;
            color: rgba(255,255,255,.95); text-shadow: 0 1px 5px rgba(0,0,0,.55); }

  .note { margin: 14px 40px 0; background: #fff6dc; border-left: 8px solid #ffc043;
          border-radius: 0 12px 12px 0; padding: 18px 24px; font-size: 23px;
          font-weight: 700; line-height: 1.6; color: #4a3b1a; }
  .note b { color: #b3560c; }
  footer { display: flex; justify-content: space-between; align-items: baseline;
           padding: 16px 46px 26px; font-size: 20px; color: #7a7f8c; font-weight: 700; }
  .brand { font-size: 30px; font-weight: 900; color: ${NAVY}; }
  </style>
  <header>
    <div class="kicker">2026年オープン ／ 東京・神奈川・千葉・埼玉</div>
    <h1>首都圏のサウナ新店</h1>
    <div class="sub">料金・最寄駅・男女別 <em>17施設まとめ</em></div>
  </header>
  <div class="rule"></div>
  <div class="grid">${cards}</div>
  <div class="note">17施設のうち<b>男性専用8・女性がそのまま入れる8でちょうど半々。</b>残る1つ（PARADISE 大手町）は資料が割れる。</div>
  <footer><span>出典: 各施設公式／東京銭湯マップ ほか</span><span class="brand">Daily Hack</span></footer>`;
}

// ── 2〜4 枚目: 実写を全面に敷き、下に施設名と出典 ──
function facilityHtml(f) {
  const specs = f.specs.map((s) => `<span>${s}</span>`).join('');
  return `<style>${BASE}
  body { position: relative; background: #000; }
  .photo { position: absolute; inset: 0; background-image: url('${url(f.img)}');
           background-size: cover; background-position: center; }
  .veil { position: absolute; inset: 0;
          background: linear-gradient(180deg, rgba(10,14,24,.55) 0%, rgba(10,14,24,.05) 30%,
                      rgba(10,14,24,.55) 62%, rgba(10,14,24,.94) 100%); }
  .top { position: absolute; top: 44px; left: 48px; right: 48px;
         display: flex; justify-content: space-between; align-items: center; }
  .open { background: ${PINK}; color: #fff; font-size: 26px; font-weight: 900;
          padding: 10px 24px; border-radius: 999px; }
  .brand { color: #fff; font-size: 26px; font-weight: 900; opacity: .95;
           text-shadow: 0 2px 8px rgba(0,0,0,.6); }
  .body { position: absolute; left: 48px; right: 48px; bottom: 44px; color: #fff; }
  h2 { font-size: 62px; font-weight: 900; line-height: 1.15;
       text-shadow: 0 3px 12px rgba(0,0,0,.7); }
  .lead { margin-top: 16px; font-size: 27px; font-weight: 500; line-height: 1.6;
          color: rgba(255,255,255,.96); text-shadow: 0 2px 8px rgba(0,0,0,.7); }
  .specs { margin-top: 22px; display: flex; gap: 12px; flex-wrap: wrap; }
  .specs span { background: rgba(255,255,255,.16); border: 2px solid rgba(255,255,255,.42);
                border-radius: 999px; padding: 9px 22px; font-size: 24px; font-weight: 700; }
  .credit { margin-top: 24px; font-size: 19px; font-weight: 500; color: rgba(255,255,255,.72); }
  </style>
  <div class="photo"></div><div class="veil"></div>
  <div class="top"><span class="open">${f.open}</span><span class="brand">Daily Hack</span></div>
  <div class="body">
    <h2>${f.name}</h2>
    <div class="lead">${f.lead}</div>
    <div class="specs">${specs}</div>
    <div class="credit">${f.credit}</div>
  </div>`;
}

const run = async () => {
  fs.mkdirSync(OUT, { recursive: true });
  // このリポジトリの playwright は npm 版と入っている Chromium の版が揃わないことがある。
  // **playwright install はしない**（環境側で用意済み）。実体を直接指す
  const bundled = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
  const browser = await chromium.launch(
    fs.existsSync(bundled) ? { executablePath: bundled } : {}
  );
  const page = await browser.newPage({
    viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1,
  });

  const jobs = [
    ['1-summary.jpg', summaryHtml()],
    ...FACILITIES.map((f) => [f.file, facilityHtml(f)]),
  ];

  // **setContent だと file:// の画像が読めない。** ページの origin が about:blank に
  // なるため Chromium がローカルファイルの下位リソースを拒む。
  // 画像と同じ階層に一時 HTML を置いて goto する
  const tmp = path.join(IMG, '.x-render.html');
  for (const [file, html] of jobs) {
    fs.writeFileSync(tmp, `<!doctype html><meta charset="utf-8">${html}`);
    await page.goto('file://' + tmp, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    // 背景画像が実際に読めたか確かめる。**読めないまま出力しない**
    const bad = await page.evaluate(() =>
      [...document.querySelectorAll('.pick, .photo')].filter((el) => {
        const u = getComputedStyle(el, el.classList.contains('pick') ? '::before' : null)
          .backgroundImage;
        return !u || u === 'none';
      }).length
    );
    if (bad) throw new Error(`${file}: 背景画像が ${bad} 個 読めていない`);
    const dst = path.join(OUT, file);
    await page.screenshot({ path: dst, type: 'jpeg', quality: 92 });
    console.log(`  ${file}  ${fs.statSync(dst).size} B`);
  }
  fs.rmSync(tmp, { force: true });

  await browser.close();
  console.log(`4 枚を ${path.relative(ROOT, OUT)} に出力した`);
};

run().catch((e) => { console.error(e); process.exit(1); });
