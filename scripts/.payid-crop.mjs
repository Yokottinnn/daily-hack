import sharp from "sharp";
import fs from "node:fs";
const SRC = "public/images/payid-invite/src";
<<<<<<< HEAD
const C = "public/images/payid-invite/cards";
const P = "public/images/payid-invite/photos";
fs.mkdirSync(C, { recursive: true }); fs.mkdirSync(P, { recursive: true });

// 2026-09-26 のコメント 4 件で作り直した。
//  2-atobarai「ロゴだけだとわかりづらいから文字の部分も切り取って入れて」
//  3-shops   「アップストアのやつだと思うけど文字も入れて」   → 見出しごと切る
//  4-rating  「一部しか映っていなくてデザインが変」          → 端で切らない
//  1-summary 「この文章のところいらない。余白をうまく使って」 → note を外す

// カードは 1000×560。**下半分に文字が来る**ので絵は上側に置く
async function card(name, src, region, { bg = "#ffffff", top = 14, maxH = 300, maxW = 1000, trim = false } = {}) {
  let cut = region ? sharp(`${SRC}/${src}`).extract(region) : sharp(`${SRC}/${src}`);
  // **ロゴの余白を落とす。** 改変ではない（x-post-images スキル §3・最上位ルール 17）。
  // アイコンは 512 角のうち図形が中央の一部しかなく、そのまま置くと小さく見える
  if (trim) cut = cut.trim();
  const buf = await cut.resize({ width: maxW, height: maxH, fit: "inside" }).png().toBuffer();
  const m = await sharp(buf).metadata();
  await sharp({ create: { width: 1000, height: 560, channels: 3, background: bg } })
    .composite([{ input: buf, top, left: Math.round((1000 - m.width) / 2) }])
    .jpeg({ quality: 92 }).toFile(`${C}/${name}.jpg`);
  console.log(`  card ${name}.jpg  ${m.width}x${m.height}`);
}

// 全面は 1080×1080。**下 40% を暗くしてから文字を乗せる**（白背景だと見出しが埋もれる）
const S = 1080;
const scrim = Buffer.from(
  `<svg width="${S}" height="${S}"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
     <stop offset="0.52" stop-color="#1E1219" stop-opacity="0"/>
     <stop offset="0.78" stop-color="#1E1219" stop-opacity="0.72"/>
     <stop offset="1" stop-color="#1E1219" stop-opacity="0.92"/>
   </linearGradient></defs><rect width="${S}" height="${S}" fill="url(#g)"/></svg>`);

// **上に寄せて小さく置かない。** 表紙の 4 カードと同じ考え方で、全面いっぱいに置く
// （下半分の文字と少し被るが、それでよいと指示された・2026-09-26）
async function panel(name, src, region, { bg = "#ffffff", maxW = 1000, maxH = 880, top = 60 } = {}) {
  const cut = region ? sharp(`${SRC}/${src}`).extract(region) : sharp(`${SRC}/${src}`);
  const buf = await cut.resize({ width: maxW, height: maxH, fit: "inside" }).png().toBuffer();
  const m = await sharp(buf).metadata();
  await sharp({ create: { width: S, height: S, channels: 3, background: bg } })
    .composite([{ input: buf, top, left: Math.round((S - m.width) / 2) }, { input: scrim, top: 0, left: 0 }])
    .jpeg({ quality: 92 }).toFile(`${P}/${name}.jpg`);
  console.log(`  panel ${name}.jpg  ${m.width}x${m.height}`);
}

// ロゴ＋ワードマーク＋「かんたん決済」＋Powered by BASE まで入れる
const LOGO = { left: 36, top: 24, width: 320, height: 350 };
// 見出し「幅広いジャンル こだわりのショップが出店」ごと切る
const GENRE = { left: 14, top: 40, width: 364, height: 440 };
// 端で切らない。丸ごとと、その下の画面まで
const SCALE = { left: 64, top: 368, width: 328, height: 320 };

// **カードいっぱいに置く。** 上に寄せて小さく置くのをやめた
// （下半分の文字と少し被るが、それでよいと指示された）
// 2026-09-26「500円玉の画像を大きく表示して」→ 余白を落としてカードいっぱいに
await card("c-intro", "icon.jpg", null, { maxH: 400, maxW: 900, top: 70, trim: true });
await card("c-pay", "shot1.png", LOGO, { maxH: 540, top: 10 });
await card("c-genre", "shot2.png", GENRE, { maxH: 540, top: 10 });
await card("c-scale", "shot1.png", SCALE, { maxH: 540, top: 10 });

await panel("p-logo", "shot1.png", LOGO, { maxH: 880, top: 60 });
await panel("p-genre", "shot2.png", GENRE, { maxH: 880, top: 50 });
await panel("p-scale", "shot1.png", SCALE, { maxH: 860, top: 60 });
=======
const OUT = "public/images/payid-invite/cards";
fs.mkdirSync(OUT, { recursive: true });

// カードは 1000×560。**下半分に濃いグラデーションと文字が来る**ので、絵は上側に置く
// （x-post-images スキル §3）。横も cover で左右が切れるため中央寄りに収める。
const W = 1000, H = 560;

async function card(name, src, region, { bg = "#ffffff", top = 18, maxH = 300 } = {}) {
  const img = sharp(`${SRC}/${src}`);
  const cut = region ? img.extract(region) : img;
  const buf = await cut.resize({ height: maxH, fit: "inside" }).png().toBuffer();
  const meta = await sharp(buf).metadata();
  await sharp({ create: { width: W, height: H, channels: 3, background: bg } })
    .composite([{ input: buf, top, left: Math.round((W - meta.width) / 2) }])
    .jpeg({ quality: 92 })
    .toFile(`${OUT}/${name}.jpg`);
  console.log(`  ${name}.jpg  ${meta.width}x${meta.height} を上から ${top}px に置いた`);
}

// ① 500円分 → アプリのアイコン（商標。改変しない・余白を落とすだけ）
await card("c-intro", "icon.jpg", null, { maxH: 260, top: 40 });
// ② あと払い → PAY ID のロゴと「かんたん決済」の帯
await card("c-pay", "shot1.png", { left: 40, top: 20, width: 312, height: 340 }, { maxH: 300, top: 14 });
// ③ 品ぞろえ → ジャンルのタイル 6 枚
await card("c-genre", "shot2.png", { left: 16, top: 160, width: 360, height: 310 }, { maxH: 300, top: 14 });
// ④ 規模 → 「2,000万アカウント突破」
await card("c-scale", "shot1.png", { left: 150, top: 385, width: 242, height: 150 }, { maxH: 250, top: 40 });
>>>>>>> origin/main
