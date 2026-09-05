#!/usr/bin/env node
/**
 * X 告知用の正方形画像（1080×1080）をまとめて作る。
 *
 * 使い方:
 *   node scripts/gen-x-cards.mjs ops/data/x-cards/<slug>.json
 *
 * 仕様と設計の理由は `.claude/skills/x-post-images/SKILL.md` を読むこと。
 * **記事ごとにスクリプトを増やさない。** JSON を足すだけで作れるようにしてある。
 *
 * ## 作るもの
 *
 *   1 枚目  cover  … 濃紺の帯 ＋ カード格子 ＋ 注記 ＋ 出典
 *   2 枚目〜 photo  … 実写を全面に敷き、下に名前・売り・スペック・出典
 *
 * cover のカードは記事の `.event-pick`（src/styles/global.css）と同じ作り。
 * **PIL で描き直さない。** 同じ CSS を Chromium で撮るから記事と完全に一致する。
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SIZE = 1080;

/**
 * **帯の配色はブログのトークンから引く。**
 *
 * 2026-09-05 の指摘:
 *   > そもそも画像上部の紺色の帯はブログのカラーと合ってないから変更して欲しい。
 *   > 毎回同じ色じゃなくて、いくつかパターンを作ってほしい
 *
 * 紺 `#16243f` は `src/styles/global.css` の `:root` に**存在しない色**だった。
 * ブログは **ピンク＋クリーム＋黄、地は濃いプラム `--ink: #2A1923`**。
 *
 * ここの値はすべて `:root` のトークンそのまま。**勝手な色を足さない。**
 *   pink-500 #EC5C90 / pink-600 #D63E76 / pink-700 #A82959
 *   cream-100 #FFF1C8 / cream-200 #FCE5A4 / yellow-500 #F5C518
 *   ink #2A1923 / ink-3 #9A8791 / line #F1DCE5 / pink-50 #FFF5F8
 */
const THEMES = {
  // 濃いプラム。ブログの本文色そのもの。落ち着いた既定
  plum:  { bg: 'linear-gradient(135deg, #2A1923 0%, #46293A 100%)',
           kicker: '#C9A9B8', text: '#FFFFFF', sub: '#F1DCE5', em: '#F5C518',
           rule: 'linear-gradient(90deg, #EC5C90, #F5C518 55%, #FCE5A4)', brand: '#2A1923' },
  // 濃いローズ。food・お得系で映える
  berry: { bg: 'linear-gradient(135deg, #A82959 0%, #D63E76 100%)',
           kicker: '#FCE5A4', text: '#FFFFFF', sub: '#FFE9F1', em: '#F5C518',
           rule: 'linear-gradient(90deg, #F5C518, #FCE5A4 55%, #FFF1C8)', brand: '#A82959' },
  // 明るいピンク。軽い話題向け
  rose:  { bg: 'linear-gradient(135deg, #D63E76 0%, #EC5C90 100%)',
           kicker: '#FFF1C8', text: '#FFFFFF', sub: '#FFF5F8', em: '#F5C518',
           rule: 'linear-gradient(90deg, #2A1923, #A82959 55%, #F5C518)', brand: '#D63E76' },
  // クリーム地に濃いプラム字。**反転パターン**。並べたとき一枚だけ明るくなる
  cream: { bg: 'linear-gradient(135deg, #FFF1C8 0%, #FCE5A4 100%)',
           kicker: '#A82959', text: '#2A1923', sub: '#5A4651', em: '#D63E76',
           rule: 'linear-gradient(90deg, #D63E76, #EC5C90 55%, #F5C518)', brand: '#A82959' },
  // ほぼ黒。数字・比較で締めたいとき
  ink:   { bg: 'linear-gradient(135deg, #1E1219 0%, #2A1923 100%)',
           kicker: '#9A8791', text: '#FFFFFF', sub: '#F1DCE5', em: '#EC5C90',
           rule: 'linear-gradient(90deg, #EC5C90, #D63E76 55%, #F5C518)', brand: '#2A1923' },
};
const THEME_KEYS = Object.keys(THEMES);
const PINK = '#EC5C90';

const specPath = process.argv[2];
if (!specPath) {
  console.error('使い方: node scripts/gen-x-cards.mjs ops/data/x-cards/<slug>.json');
  process.exit(1);
}
const spec = JSON.parse(fs.readFileSync(path.resolve(ROOT, specPath), 'utf8'));
const IMGBASE = path.resolve(ROOT, spec.imageBase);
const OUT = path.resolve(ROOT, spec.out);
const url = (p) => 'file://' + path.join(IMGBASE, p);

/**
 * テーマの決め方。**毎回 同じ色にしない。**
 *   1. `cover.theme` に名前があればそれ
 *   2. 無ければ slug の文字コード和で選ぶ（記事ごとに散り、同じ記事では毎回 同じ）
 */
const pickTheme = () => {
  const named = spec.cover && spec.cover.theme;
  if (named && THEMES[named]) return { name: named, t: THEMES[named] };
  if (named) console.warn(`  ⚠ theme "${named}" は無い。使えるのは: ${THEME_KEYS.join(' / ')}`);
  const key = String(spec.slug || specPath);
  let h = 0;
  for (const ch of key) h = (h * 31 + ch.charCodeAt(0)) % 100000;
  const name = THEME_KEYS[h % THEME_KEYS.length];
  return { name, t: THEMES[name] };
};
const { name: THEME_NAME, t: TH } = pickTheme();
// キャラ画像は記事ごとのフォルダではなく public/images 直下にある（expr-*.png / mascot-*.png）
const mascotUrl = (p) =>
  'file://' + (p.startsWith('/') ? path.join(ROOT, 'public', p) : path.join(ROOT, 'public/images', p));

/**
 * 温泉マーク（♨）。**画像を取りに行かず SVG で描く。**
 *
 * Wikimedia Commons はこのセッションの egress ポリシーで塞がれている
 * （`commons.wikimedia.org:443 connect_rejected`）。
 * 記号そのものは JIS の地図記号で、形に著作権は無い。**描いたほうが確実で、
 * 透過も解像度も自由**（ビットマップを拾うと縁が出る・ライセンス表記が要る）。
 */
const ONSEN_MARK = `
  <svg class="mark" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
    <circle cx="50" cy="50" r="48" fill="currentColor" fill-opacity=".12"/>
    <!-- 湯船 -->
    <path d="M18 62 h64 a0 0 0 0 1 0 0 v3 a17 17 0 0 1 -17 17 H35 a17 17 0 0 1 -17 -17 z"
          fill="#ffd45e"/>
    <!-- 湯気 3 本 -->
    <g stroke="#ffd45e" stroke-width="7" stroke-linecap="round" fill="none">
      <path d="M34 52 c0 -8 -7 -10 -7 -18 c0 -8 7 -10 7 -17"/>
      <path d="M50 52 c0 -9 -8 -11 -8 -20 c0 -9 8 -11 8 -19"/>
      <path d="M66 52 c0 -8 -7 -10 -7 -18 c0 -8 7 -10 7 -17"/>
    </g>
  </svg>`;

const BASE = `
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    width: ${SIZE}px; height: ${SIZE}px; overflow: hidden;
    font-family: 'Noto Sans JP', sans-serif; -webkit-font-smoothing: antialiased;
  }
  b { color: #ffe0e6; }
`;

/**
 * 1 枚目。カードは 2 種類を同じ骨格で描く。
 *   desc あり … 数字カード（総数・料金 など）
 *   desc なし … 施設カード（開業日・施設名・場所）。**枚数が増えるので文字を詰める**
 */
function coverHtml(c) {
  const cols = c.columns || 2;
  const rows = Math.ceil(c.cards.length / cols);
  const dense = rows >= 3; // 3 段以上は文字を小さくしないと入らない
  // 透かしの濃さ。JSON の cover.mascotOpacity（0〜1）。既定 0.38
  const mascotOpacity = Number.isFinite(c.mascotOpacity) ? c.mascotOpacity : 0.38;
  /** **キャラの大きさ。** 2026-09-05 の指摘「もう少し大きくして。いまサイズが中途半端」。
   *  帯の高さは padding とテキストで **おおよそ 233px**（dense）。そこに 168px を置くと
   *  上下に 30px ずつ余って、**帯に収まりきらないのでも埋めきるのでもない**中途半端さになる。
   *  **帯より少し大きく取って、はみ出た分は header 側で切る。**
   *  下端は mask で消えているので、切り口は見えない。`cover.mascotHeight` で上書き可。 */
  const mascotH = Number.isFinite(c.mascotHeight) ? c.mascotHeight : (dense ? 262 : 286);

  /** **見出しは 1 行に収める。** 2026-09-05 の指摘:
   *    「一行でまとめて。文字サイズを少し小さくすればいい。透過した画像の上に乗ってもいい」
   *  文字数から自動で縮める。長いときは幅の上限も外し、**透かしのキャラに重ねる。**
   *  `cover.titleSize` を書けばその値を使う（自動計算より優先）。 */
  const titlePlain = String(c.title || '').replace(/<[^>]*>/g, '');
  const wide = titlePlain.length >= 11;
  const autoSize = Math.max(48, Math.min(dense ? 68 : 78,
                     Math.floor((dense ? 930 : 960) / Math.max(titlePlain.length, 1))));
  const h1Size = Number.isFinite(c.titleSize) ? c.titleSize : autoSize;
  // 短い見出しはキャラを避ける。長い見出しは**重ねてよい**ので画面幅いっぱいまで使う
  const h1Max = wide ? (dense ? 960 : 972) : (dense ? 700 : 690);

  const cards = c.cards.map((k) => `
    <div class="pick" style="--pick-img:url('${url(k.img)}')">
      <span class="badge">${k.badge}</span>
      <h4>${k.title}</h4>
      ${k.desc ? `<p>${k.desc}</p>` : ''}
      ${k.meta ? `<div class="meta">${k.meta}</div>` : ''}
    </div>`).join('');

  return `<style>${BASE}
  body { background: #f7f7f9; display: flex; flex-direction: column; }
  header .kicker, header h1, header .sub { position: relative; z-index: 1; }
  /* **overflow: hidden は必須。** キャラを帯より大きく取っているので、
     これが無いと下のカード格子の上に裾がはみ出す。 */
  header { background: ${TH.bg}; color: ${TH.text}; padding: ${dense ? 36 : 46}px 54px ${dense ? 30 : 40}px;
           position: relative; overflow: hidden; }
  .kicker { font-size: 26px; font-weight: 700; color: ${TH.kicker}; letter-spacing: .08em; }
  /* 透かしの上に乗るので、可読性のため薄い影を足す */
  h1 { font-size: ${h1Size}px; font-weight: 900; line-height: 1.1; margin-top: 8px;
       white-space: nowrap; text-shadow: 0 2px 10px rgba(0,0,0,.18); }
  .sub { font-size: 29px; font-weight: 700; margin-top: 14px; color: ${TH.sub}; }
  /* 右上のキャラとマーク。**見出しに被らない**よう幅を確保して右端に置く */
  /* **帯の中で上下中央に置く。** 2026-09-05 の指摘「位置をもう少し下に、帯の中で中央に」。
     上端に貼り付けると帯の下半分が空いて、透かしとして浮いて見える。 */
  .hero { position: absolute; top: 0; bottom: 0; right: 40px; z-index: 0;
          display: flex; align-items: center; gap: 10px; }
  .hero .mark { width: ${dense ? 96 : 108}px; height: ${dense ? 96 : 108}px; }
  /* **透かしとして置く。** 2026-09-05 の指摘:
       「キャラの画像はもっと透過させて。顔の部分とかはうっすら帯に表示されているような」
     全体の不透明度を下げ、下端は帯に溶かす（元画像はバストアップで裾が真横に切れている）。
     濃さは cover.mascotOpacity（0〜1）で変えられる。既定 0.38。 */
  .hero .mascot { height: ${mascotH}px;
                  opacity: ${mascotOpacity};
                  -webkit-mask-image: linear-gradient(to bottom, #000 62%, rgba(0,0,0,0) 96%);
                  mask-image: linear-gradient(to bottom, #000 62%, rgba(0,0,0,0) 96%); }
  /* **見出しを右上のクラスタに被せない。** 幅を先に確保しておく */
  header .sub, header .kicker { max-width: ${dense ? 700 : 690}px; }
  header h1 { max-width: ${h1Max}px; }
  .sub em { font-style: normal; color: ${TH.em}; }
  .rule { height: 8px; background: ${TH.rule}; }

  /* 記事の .event-pick と同じ骨格。似せるのではなく揃える */
  .grid { flex: 1; display: grid; grid-template-columns: repeat(${cols}, 1fr);
          gap: ${dense ? 14 : 20}px; padding: ${dense ? 20 : 30}px 40px 6px; }
  .pick { position: relative; overflow: hidden; border-radius: ${dense ? 18 : 22}px;
          padding: ${dense ? 14 : 22}px ${dense ? 16 : 24}px ${dense ? 16 : 24}px;
          color: #fff; isolation: isolate;
          box-shadow: 0 14px 30px -16px rgba(42,25,35,.55);
          display: flex; flex-direction: column; justify-content: flex-end; }
  .pick::before { content: ""; position: absolute; inset: 0; z-index: -2;
                  background-image: var(--pick-img); background-size: cover; background-position: center; }
  .pick::after { content: ""; position: absolute; inset: 0; z-index: -1;
                 background: linear-gradient(180deg, rgba(42,25,35,.28) 0%,
                             rgba(42,25,35,.60) 45%, rgba(42,25,35,.90) 100%); }
  .badge { align-self: flex-start; background: ${PINK}; color: #fff;
           font-size: ${dense ? 18 : 20}px; font-weight: 700;
           padding: ${dense ? 4 : 6}px ${dense ? 14 : 18}px; border-radius: 999px; }
  .pick h4 { font-size: ${dense ? 28 : 38}px; font-weight: 900; line-height: 1.22;
             margin: ${dense ? 8 : 12}px 0 ${dense ? 4 : 8}px;
             text-shadow: 0 2px 8px rgba(0,0,0,.6); }
  .pick p { font-size: 21px; font-weight: 500; line-height: 1.6;
            color: rgba(255,255,255,.95); text-shadow: 0 1px 5px rgba(0,0,0,.55); }
  .pick .meta { font-size: ${dense ? 19 : 22}px; font-weight: 700;
                color: rgba(255,255,255,.88); text-shadow: 0 1px 5px rgba(0,0,0,.6); }

  .note { margin: ${dense ? 10 : 14}px 40px 0; background: #fff6dc; border-left: 8px solid #ffc043;
          border-radius: 0 12px 12px 0; padding: ${dense ? 14 : 18}px 24px;
          font-size: ${dense ? 21 : 23}px; font-weight: 700; line-height: 1.55; color: #4a3b1a; }
  .note b { color: #b3560c; }
  footer { display: flex; justify-content: space-between; align-items: baseline;
           padding: ${dense ? 12 : 16}px 46px ${dense ? 20 : 26}px;
           font-size: 20px; color: #7a7f8c; font-weight: 700; }
  .brand { font-size: 30px; font-weight: 900; color: ${TH.brand}; }
  </style>
  <header>
    <div class="hero">
      ${c.mark === false ? '' : ONSEN_MARK}
      ${c.mascot ? `<img class="mascot" src="${mascotUrl(c.mascot)}" alt="">` : ''}
    </div>
    <div class="kicker">${c.kicker}</div>
    <h1>${c.title}</h1>
    <div class="sub">${c.sub}</div>
  </header>
  <div class="rule"></div>
  <div class="grid">${cards}</div>
  ${c.note ? `<div class="note">${c.note}</div>` : ''}
  <footer><span>${c.source || ''}</span><span class="brand">Daily Hack</span></footer>`;
}

/** 2 枚目以降。実写を全面に敷き、下に情報帯。**どれか一目で分かること**が要件 */
function photoHtml(f) {
  const specs = (f.specs || []).map((s) => `<span>${s}</span>`).join('');
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
  h2 { font-size: 62px; font-weight: 900; line-height: 1.15; text-shadow: 0 3px 12px rgba(0,0,0,.7); }
  .lead { margin-top: 16px; font-size: 27px; font-weight: 500; line-height: 1.6;
          color: rgba(255,255,255,.96); text-shadow: 0 2px 8px rgba(0,0,0,.7); }
  .specs { margin-top: 22px; display: flex; gap: 12px; flex-wrap: wrap; }
  .specs span { background: rgba(255,255,255,.16); border: 2px solid rgba(255,255,255,.42);
                border-radius: 999px; padding: 9px 22px; font-size: 24px; font-weight: 700; }
  .credit { margin-top: 24px; font-size: 19px; font-weight: 500; color: rgba(255,255,255,.72); }
  </style>
  <div class="photo"></div><div class="veil"></div>
  <div class="top"><span class="open">${f.badge}</span><span class="brand">Daily Hack</span></div>
  <div class="body">
    <h2>${f.name}</h2>
    ${f.lead ? `<div class="lead">${f.lead}</div>` : ''}
    <div class="specs">${specs}</div>
    <div class="credit">${f.credit}</div>
  </div>`;
}

const run = async () => {
  fs.mkdirSync(OUT, { recursive: true });
  // npm 版 playwright と入っている Chromium の版が揃わないことがある。
  // **playwright install はしない**（環境側で用意済み）。実体を直接指す
  const bundled = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
  const browser = await chromium.launch(
    fs.existsSync(bundled) ? { executablePath: bundled } : {}
  );
  const page = await browser.newPage({
    viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1,
  });

  const jobs = [
    [spec.cover.file || '1-cover.jpg', coverHtml(spec.cover)],
    ...spec.photos.map((f) => [f.file, photoHtml(f)]),
  ];

  // **setContent だと file:// の画像が読めない。** ページの origin が about:blank に
  // なるため Chromium がローカルの下位リソースを拒む。**灰色のまま黙って出力される。**
  // 画像と同じ階層に一時 HTML を置いて goto する
  const tmp = path.join(IMGBASE, '.x-render.html');
  for (const [file, html] of jobs) {
    fs.writeFileSync(tmp, `<!doctype html><meta charset="utf-8">${html}`);
    await page.goto('file://' + tmp, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    // 背景画像が実際に読めたか確かめる。**読めないまま出力しない**
    const bad = await page.evaluate(() =>
      [...document.querySelectorAll('.pick, .photo')].filter((el) => {
        const u = getComputedStyle(el, el.classList.contains('pick') ? '::before' : null).backgroundImage;
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
  console.log(`${jobs.length} 枚を ${path.relative(ROOT, OUT)} に出力した`);
  console.log('**Read で全部開いて自分の目で見ること。** サイズが増えただけでは確認にならない');
};

run().catch((e) => { console.error(e); process.exit(1); });
