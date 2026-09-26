import sharp from "sharp";
import fs from "node:fs";
const SRC = "public/images/payid-invite/src";
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
