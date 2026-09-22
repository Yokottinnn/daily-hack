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

/** 既定はカードの帯（1000x560）。
 *  **全面用は 1080x1080。** そのときは `size` を JSON に書く。
 *  帯の下半分はカードのグラデと文字で潰れる／全面は `darkenBottom` で自分で暗くする */
const DEFAULT_W = 1000;
const DEFAULT_H = 560;

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
  const W = (s.size && s.size[0]) || DEFAULT_W;
  const H = (s.size && s.size[1]) || DEFAULT_H;
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

  /* **ブランド名を並べたら、その左にロゴを置く**（CLAUDE.md 最上位ルール 17）。
   * `dim: true` の行は負け側。薄くして、勝者との差を見せる */
  const rows = (s.rows || []).map((r) => {
    if (!r.logo) return { ...r, src: null };
    const p = path.join(base, r.logo);
    if (!exists(p)) throw new Error(`ロゴが無い: ${p}`);
    return { ...r, src: r.logo };
  });

  const rowsHtml = rows.length ? `
    <div class="rows">
      ${rows.map((r) => `
      <div class="row${r.dim ? ' dim' : ''}${r.win ? ' win' : ''}">
        ${r.src ? `<img class="rlogo" src="${esc(r.src)}">` : '<span class="rlogo"></span>'}
        <span class="rname">${esc(r.name)}</span>
        <span class="rprice">${esc(r.price)}</span>
      </div>`).join('')}
    </div>` : '';

  const headHtml = s.headline ? `<div class="headline">${esc(s.headline)}</div>` : '';
  const noteHtml = s.note ? `<div class="snote">${esc(s.note)}</div>` : '';

  /* **表紙っぽくする 3 つの部品**（2026-09-22 にレビューページで指示された）。
   *   「この内容を表紙っぽくして整えて。他の画像は全部いらない。画像は1枚だけで良い。」
   * `band`  … 上の帯（kicker / title / sub）。`gen-x-cards.mjs` の cover と同じ骨格
   * `hero`  … 実写を角丸のパネルで置く。**元画像より大きく引き伸ばさない**こと
   * `hcard` … 1 位だけを大きく見せる札。2 位以下は `rows` に流す */
  const b = s.band;
  const bandHtml = b ? `
    <div class="band">
      ${b.kicker ? `<div class="kicker">${esc(b.kicker)}</div>` : ''}
      ${b.title ? `<div class="btitle">${esc(b.title)}</div>` : ''}
      ${b.sub ? `<div class="bsub">${esc(b.sub)}</div>` : ''}
    </div>` : '';

  const h = s.hero;
  if (h && h.file) {
    const p = path.join(base, h.file);
    if (!exists(p)) throw new Error(`実写が無い: ${p}（当て推量で作らない）`);
  }
  if (h && h.logo) {
    const p = path.join(base, h.logo);
    if (!exists(p)) throw new Error(`ロゴが無い: ${p}`);
  }
  const heroHtml = h ? `
    <div class="hero">
      <img src="${esc(h.file || h.logo)}"${h.logo ? ' class="heroLogo"' : ''}>
    </div>` : '';

  /* 1 位の札。**2 位以下の行（`rows`）と同じ見た目にする**——白いカード 1 枚に
   * ロゴも文字も写真も全部 入れる（2026-09-22 の指摘）。
   *   「松屋のカードと同じように、大きな白いカードの中にロゴや文章など全てまとめる」
   *   「カード内は色つけなくていいよ。枠線つけてるんだから白の背景で十分」
   * **地に色を敷かない。** 区別は枠線と大きさだけでつける */
  const c = s.hcard;
  if (c && c.logo) {
    const p = path.join(base, c.logo);
    if (!exists(p)) throw new Error(`ロゴが無い: ${p}`);
  }
  if (c && c.photo) {
    const p = path.join(base, c.photo.file);
    if (!exists(p)) throw new Error(`実写が無い: ${p}（当て推量で作らない）`);
  }
  const hcardHtml = c ? `
    <div class="hcard">
      <div class="hbody">
        ${c.rank ? `<div class="hrank">${esc(c.rank)}</div>` : ''}
        ${c.logo || c.brand ? `<div class="hbrand">
          ${c.logo ? `<img class="hlogo" src="${esc(c.logo)}">` : ''}
          ${c.brand ? `<span>${esc(c.brand)}</span>` : ''}
        </div>` : ''}
        ${c.name ? `<div class="hname">${esc(c.name)}</div>` : ''}
        ${c.price ? `<div class="hprice">${esc(c.price)}</div>` : ''}
        ${c.sub ? `<div class="hsub">${esc(c.sub)}</div>` : ''}
      </div>
      ${c.photo ? `<div class="hphoto"><img src="${esc(c.photo.file)}"></div>` : ''}
    </div>` : '';

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

  /* **全面用（1080x1080）は下を暗くしてから文字を乗せる。**
   * ロゴは白背景が多く、明るい画像になって白い見出しが埋もれる（スキル §3） */
  .darken { position:absolute; left:0; right:0; bottom:0; height:${(s.darkenBottom ?? 0.4) * 100}%;
            background: linear-gradient(180deg, rgba(30,18,25,0) 0%, rgba(30,18,25,.86) 58%, rgba(30,18,25,.96) 100%); }

  .headline { position:absolute; left:0; right:0; top:${s.headTop ?? 40}px; padding:0 54px;
              font:800 ${s.headSize ?? 46}px/1.28 "Noto Sans JP", system-ui, sans-serif;
              color:${s.headColor || '#1E1219'}; text-align:center; letter-spacing:-.01em; }

  /* 比較行。**ロゴは名前の左**（最上位ルール 17） */
  .rows { position:absolute; left:0; right:0; top:${s.rowsTop ?? 150}px; padding:0 ${s.rowsPad ?? 62}px;
          display:flex; flex-direction:column; gap:${s.rowGap ?? 16}px; }
  /* **1 位の札と同じ白。** 地に色を敷かない（2026-09-22 の指摘） */
  .row { display:flex; align-items:center; gap:20px;
         background:#fff; border-radius:16px;
         padding:${s.rowPad ?? 14}px 24px; box-shadow:0 2px 10px rgba(30,18,25,.10); }
  .row.dim { opacity:.62; }
  .row.win { background:#FFF1C8; box-shadow:0 6px 22px rgba(214,62,118,.28);
             outline:4px solid #D63E76; }
  .rlogo { width:${s.logoW ?? 78}px; height:${s.logoH ?? 46}px; object-fit:contain; display:block; flex:none; }
  .rname { flex:1; font:700 ${s.nameSize ?? 31}px/1.2 "Noto Sans JP", system-ui, sans-serif; color:#1E1219; }
  .rprice { font:800 ${s.priceSize ?? 40}px/1 "Noto Sans JP", system-ui, sans-serif;
            color:#A82959; font-variant-numeric:tabular-nums; white-space:nowrap; }
  .row.win .rprice { color:#D63E76; }

  .snote { position:absolute; left:0; right:0; bottom:${s.noteBottom ?? 34}px; padding:0 58px;
           font:700 ${s.noteSize ?? 27}px/1.45 "Noto Sans JP", system-ui, sans-serif;
           color:${s.noteColor || '#FFFFFF'}; text-align:center; }

  /* ---- 表紙の帯 ---- */
  .band { position:absolute; left:0; right:0; top:0; height:${b?.h ?? 276}px;
          background: linear-gradient(135deg, ${b?.bg?.[0] || '#A82959'} 0%, ${b?.bg?.[1] || '#D63E76'} 100%);
          display:flex; flex-direction:column; align-items:center; justify-content:center;
          gap:${b?.gap ?? 14}px; padding:0 46px; box-sizing:border-box; }
  .kicker { font:700 ${b?.kickerSize ?? 27}px/1.3 "Noto Sans JP", system-ui, sans-serif;
            color:#FFE9C4; letter-spacing:.02em; text-align:center; }
  .btitle { font:800 ${b?.titleSize ?? 58}px/1.2 "Noto Sans JP", system-ui, sans-serif;
            color:#fff; text-align:center; letter-spacing:-.015em;
            text-shadow:0 2px 12px rgba(30,18,25,.28); }
  .bsub { font:700 ${b?.subSize ?? 29}px/1.4 "Noto Sans JP", system-ui, sans-serif;
          color:#FFD9E6; text-align:center; }

  /* ---- 実写／ロゴのパネル ---- */
  .hero { position:absolute; top:${h?.top ?? 300}px; left:${h?.left ?? 60}px;
          width:${h?.w ?? 420}px; height:${h?.h ?? 296}px;
          border-radius:${h?.radius ?? 22}px; overflow:hidden; background:#fff;
          border:${h?.border ?? 6}px solid #fff; box-sizing:border-box;
          box-shadow:0 10px 30px rgba(30,18,25,.22); }
  /* **zoom は寄せて切るため。** 元画像の地の暗い縁を落とす用で、
   * 1.3 を超えると 384px の素材ではぼやける */
  .hero img { width:100%; height:100%; display:block;
              object-fit:cover; object-position:${h?.pos || 'center 50%'};
              transform: scale(${h?.zoom ?? 1}); transform-origin:center; }
  /* **ロゴは切らない。** 商標なので余白ごと収める（最上位ルール 17） */
  .hero img.heroLogo { object-fit:contain; padding:${h?.logoPad ?? 34}px; box-sizing:border-box; }

  /* ---- 1 位の札 ---- */
  /* **地は白。** 色で目立たせず、枠線と大きさで 2 位以下と差をつける（2026-09-22 の指摘）。
   * 中身はすべてこのカードの内側に置く。外に浮かせる要素を作らない */
  .hcard { position:absolute; top:${c?.top ?? 300}px; left:${c?.left ?? 60}px;
           width:${c?.w ?? 960}px; height:${c?.h ?? 300}px; box-sizing:border-box;
           background:#fff; border-radius:24px;
           border:${c?.border ?? 4}px solid ${c?.borderColor || '#D63E76'};
           box-shadow:0 6px 20px rgba(30,18,25,.12);
           display:flex; flex-direction:${c?.dir || 'row'};
           align-items:center; gap:${c?.gap ?? 26}px; padding:${c?.pad ?? 24}px; }
  .hbody { flex:1; min-width:0; display:flex; flex-direction:column;
           align-items:flex-start; gap:${c?.bodyGap ?? 6}px; }
  .hrank { font:800 ${c?.rankSize ?? 23}px/1 "Noto Sans JP", system-ui, sans-serif;
           color:#D63E76; letter-spacing:.04em; white-space:nowrap; }
  .hbrand { display:flex; align-items:center; gap:14px; }
  .hbrand span { font:700 ${c?.brandSize ?? 36}px/1.1 "Noto Sans JP", system-ui, sans-serif;
                 color:#1E1219; }
  .hlogo { width:${c?.logoW ?? 84}px; height:auto; display:block; object-fit:contain; flex:none; }
  .hname { font:700 ${c?.nameSize ?? 30}px/1.25 "Noto Sans JP", system-ui, sans-serif;
           color:#1E1219; }
  .hprice { font:900 ${c?.priceSize ?? 78}px/1.05 "Noto Sans JP", system-ui, sans-serif;
            color:#D63E76; font-variant-numeric:tabular-nums; }
  .hsub { font:700 ${c?.subSize ?? 22}px/1.35 "Noto Sans JP", system-ui, sans-serif;
          color:#6b5460; }
  /* カードの中に実写を収める。**外に別パネルを置かない** */
  .hphoto { flex:none; width:${c?.photo?.w ?? 400}px; height:100%;
            border-radius:${c?.photo?.radius ?? 16}px; overflow:hidden; background:#f2f2f2; }
  .hphoto img { width:100%; height:100%; display:block; object-fit:cover;
                object-position:${c?.photo?.pos || 'center 0%'};
                transform:scale(${c?.photo?.zoom ?? 1}); }
</style>
<div class="strip">
  ${photoLayer}
  ${s.darkenBottom ? '<div class="darken"></div>' : ''}
  ${bandHtml}
  ${heroHtml}
  ${hcardHtml}
  ${headHtml}
  ${rowsHtml}
  ${noteHtml}
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
const page = await browser.newPage({ deviceScaleFactor: 1 });

let made = 0;
for (const s of spec.strips) {
  const html = stripHtml(s);
  // **素材の隣に書く。** `setContent()` だと file:// の画像が読めず、
  // **灰色の空カードがエラーも出さずに出力される**（2026-08-30 に踏んだ）
  // **`out` に `/` が入りうる（`x/2-rank.jpg`）。** 一時 HTML の名前には使えないので
  // ファイル名だけ取る。**素材の隣に置くことが目的**なので base 直下でよい
  const tmp = path.join(base, `.strip-${path.basename(s.out).replace(/\.\w+$/, '')}.html`);
  fs.writeFileSync(tmp, html);
  // **サイズは 1 枚ずつ違う。** 帯は 1000x560、全面は 1080x1080
  const w = (s.size && s.size[0]) || DEFAULT_W;
  const h = (s.size && s.size[1]) || DEFAULT_H;
  await page.setViewportSize({ width: w, height: h });
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
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out, type: 'jpeg', quality: 92 });
    const bytes = fs.statSync(out).size;
    // **小さすぎる＝真っ白。** rc=0 で通ってしまうので自分で見る
    if (bytes < 4000) throw new Error(`出力が ${bytes} bytes。ほぼ空`);
    console.log(`  ${s.out.padEnd(26)} ${w}x${h}  ${Math.round(bytes / 1024)}KB`);
    made++;
  } finally {
    fs.rmSync(tmp, { force: true });
  }
}

await browser.close();
console.log(`帯 ${spec.strips.length} 本 / 作った ${made} 本`);
if (made !== spec.strips.length) process.exit(1);
