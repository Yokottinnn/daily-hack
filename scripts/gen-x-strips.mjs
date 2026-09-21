#!/usr/bin/env node
/**
 * X の告知カードに敷く「帯」（1000×560）を作る。
 *
 * ## なぜ別スクリプトなのか
 *
 * `gen-x-cards.mjs` は **JSON に書かれた帯画像を読むだけ**で、帯そのものは作らない。
 * これまでは帯を手で作っていたので、**ロゴだけが浮いた無地の帯**になっていた。
 *
 * 2026-09-21 に指摘された。
 *
 *   「まいばすけっとロゴが入った店舗の画像を透過して表示してほしい。
 *     何も背景がない形だとデザインとして目立たないので」
 *
 * ## 記事ごとにスクリプトを増やさない（最上位ルール 8）
 *
 * **JSON を 1 本 足すだけ。**
 *
 *   node scripts/gen-x-strips.mjs ops/data/x-strips/<slug>.json
 *
 * ## 帯の下半分は見えない
 *
 * カード側の `.pick::after` が **45% から下を rgba(42,25,35,.60)〜.90 で潰す**
 * うえ、見出しと本文がそこに乗る。**効かせるなら上 45%。**
 * 写真は `object-position` を上寄りにし、ロゴは上半分に置く。
 *
 * ## 出所の行は焼き込まない（最上位ルール 8・2026-09-20 の指示）
 *
 * **だから素材は CC0 / パブリックドメイン / 各社ロゴ / 自作に限る。**
 * CC BY・CC BY-SA を使うと表記が要る＝この規定と両立しない。
 * **このスクリプトは出所を描かない。** 素材側で守ること。
 *
 * ## ロゴは商標。改変しない
 *
 * 色を変えない・切り抜かない・角を丸めない（最上位ルール 17）。
 * **`filter` はロゴに掛けない。** 背景写真にだけ掛ける。
 */
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const W = 1000;
const H = 560;

const specPath = process.argv[2];
if (!specPath) {
  console.error('使い方: node scripts/gen-x-strips.mjs ops/data/x-strips/<slug>.json');
  process.exit(1);
}
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));
const base = spec.imageBase || `public/images/${spec.slug}`;

/** file:// の絶対 URL。**`page.setContent()` では file:// のサブリソースが読めない**ので、
 *  HTML を素材の隣に書いて `goto` する（`x-post-images` スキル §3）。 */
const abs = (p) => path.resolve(p);
const exists = (p) => fs.existsSync(abs(p));

const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function stripHtml(s) {
  const photo = s.photo ? path.join(base, s.photo) : null;
  if (s.photo && !exists(photo)) {
    throw new Error(`素材が無い: ${photo}（当て推量で作らない）`);
  }
  const logos = (s.logos || []).map((l) => {
    const p = path.join(base, l.file);
    if (!exists(p)) throw new Error(`ロゴが無い: ${p}`);
    return { ...l, src: l.file };   // **base からの相対。** basename だと logos/ が落ちる
  });

  /* **写真が使えないときの逃げ道。**
   * 2026-09-21、トライアル／西友の店舗写真は Commons に **CC0 / PD が 1 枚も無く**、
   * 実店舗の写真 11 件 は全部 CC BY か CC BY-SA だった（`x124` の実測）。
   * **出所の行を出さないと決まっている以上、表記が要る素材は使えない。**
   * そこで **ロゴ自体を大きく薄く敷く**（商標・識別目的。出所の行が要らない）。 */
  const wash = (s.wash || []).map((w) => {
    const p = path.join(base, w.file);
    if (!exists(p)) throw new Error(`敷くロゴが無い: ${p}`);
    return { ...w, src: w.file };   // **base からの相対**
  });

  // **写真は上 45% に効かせる。** 下は必ずカードのグラデで潰れる
  const photoLayer = photo ? `
    <div class="photo"></div>
    <div class="veil"></div>` : (wash.length ? `
    <div class="wash">
      ${wash.map((w) => `<img src="${esc(w.src)}" style="width:${w.w || 620}px; opacity:${w.opacity ?? 0.13}">`).join('\n      ')}
    </div>
    <div class="veil"></div>` : '');

  return `<!doctype html><meta charset="utf-8">
<style>
  @page { margin: 0 }
  html, body { margin: 0; padding: 0; }
  body { width:${W}px; height:${H}px; overflow:hidden; }
  .strip { position:relative; width:${W}px; height:${H}px; overflow:hidden;
           background: linear-gradient(160deg, ${s.bg?.[0] || '#f6f7f9'} 0%, ${s.bg?.[1] || '#e8eaee'} 100%); }

  /* 店舗写真。**透過して敷く** — 指摘の「透過した背景にして」 */
  .photo { position:absolute; inset:0;
           background-image:url('${s.photo || ''}');
           background-size:cover;
           /* **上寄せ。** 下 55% はカード側のグラデと文字で消える */
           background-position:${s.photoPos || 'center 28%'};
           opacity:${s.photoOpacity ?? 0.42};
           /* **写真にだけ掛ける。** ロゴは商標なので触らない（最上位ルール 17） */
           filter:saturate(${s.photoSaturate ?? 0.75}) contrast(1.02); }

  /* ロゴを大きく薄く敷く。**写真が使えないときだけ**（§ 冒頭の注記） */
  .wash { position:absolute; inset:0; display:flex; align-items:center;
          justify-content:center; gap:${s.washGap ?? 40}px;
          transform: translateY(${s.washShift ?? -18}px) rotate(${s.washRotate ?? -8}deg); }
  .wash img { display:block; height:auto; object-fit:contain; }

  /* 白いもやを重ねて、ロゴが写真に負けないようにする */
  .veil { position:absolute; inset:0;
          background: linear-gradient(180deg,
            rgba(255,255,255,${s.veilTop ?? 0.52}) 0%,
            rgba(255,255,255,${s.veilMid ?? 0.30}) 46%,
            rgba(255,255,255,0) 100%); }

  .logos { position:absolute; left:0; right:0; top:${s.logoTop ?? 46}px;
           display:flex; align-items:center; justify-content:center;
           gap:${s.gap ?? 34}px; padding:0 48px; }
  .logos img { display:block; height:auto; object-fit:contain;
               /* **ロゴは改変しない。** 影だけで浮かせる */
               filter: drop-shadow(0 2px 10px rgba(255,255,255,.95))
                       drop-shadow(0 1px 3px rgba(0,0,0,.18)); }
  .x { font: 700 30px/1 "Noto Sans JP", system-ui, sans-serif; color:#5b6470; }
</style>
<div class="strip">
  ${photoLayer}
  <div class="logos">
    ${logos.map((l, i) =>
      (i > 0 && s.joiner ? `<span class="x">${esc(s.joiner)}</span>` : '') +
      `<img src="${esc(l.src)}" style="width:${l.w || 240}px">`
    ).join('\n    ')}
  </div>
</div>`;
}

const bundled = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const browser = await chromium.launch(
  fs.existsSync(bundled) ? { executablePath: bundled } : {}
);
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });

let made = 0;
for (const s of spec.strips) {
  const html = stripHtml(s);
  // **素材の隣に書く。** `setContent()` だと file:// の画像が読めず、
  // **灰色の空カードがエラーも出さずに出力される**（2026-08-30 に踏んだ）
  const tmp = path.join(base, `.strip-${s.out.replace(/\.\w+$/, '')}.html`);
  fs.writeFileSync(tmp, html);
  try {
    await page.goto('file://' + abs(tmp), { waitUntil: 'load' });
    // **画像が本当に読めたか確かめる。** 読めていなければ止める
    const broken = await page.evaluate(() =>
      [...document.images].filter((im) => !im.complete || im.naturalWidth === 0)
        .map((im) => im.getAttribute('src')));
    if (broken.length) throw new Error(`画像が読めていない: ${broken.join(', ')}`);
    const bgOk = await page.evaluate(() => {
      const el = document.querySelector('.photo');
      if (!el) return true;                       // 写真なしの帯は素通り
      const u = getComputedStyle(el).backgroundImage;
      return u && u !== 'none';
    });
    if (!bgOk) throw new Error('背景写真が当たっていない');

    const out = path.join(base, s.out);
    await page.screenshot({ path: out, type: 'jpeg', quality: 92 });
    const bytes = fs.statSync(out).size;
    // **小さすぎる＝真っ白。** rc=0 で通ってしまうので自分で見る
    if (bytes < 4000) throw new Error(`出力が ${bytes} bytes。ほぼ空`);
    console.log(`  ${s.out.padEnd(24)} ${W}x${H}  ${Math.round(bytes / 1024)}KB`);
    made++;
  } finally {
    fs.rmSync(tmp, { force: true });
  }
}

await browser.close();
console.log(`帯 ${spec.strips.length} 本 / 作った ${made} 本`);
if (made !== spec.strips.length) process.exit(1);
