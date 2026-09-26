import sharp from "sharp";
import fs from "node:fs";
const SRC = "public/images/payid-invite/src";
const OUT = "public/images/payid-invite/photos";
fs.mkdirSync(OUT, { recursive: true });
const S = 1080;

// **ロゴや白背景を全面に使うときは、下 40% を暗くしてから文字を乗せる**
// （x-post-images スキル §3）。そうしないと白い見出しが埋もれる（実際に埋もれた）。
const scrim = Buffer.from(
  `<svg width="${S}" height="${S}"><defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
     <stop offset="0.52" stop-color="#1E1219" stop-opacity="0"/>
     <stop offset="0.78" stop-color="#1E1219" stop-opacity="0.72"/>
     <stop offset="1" stop-color="#1E1219" stop-opacity="0.92"/>
   </linearGradient></defs><rect width="${S}" height="${S}" fill="url(#g)"/></svg>`
);

async function panel(name, src, region, { bg = "#ffffff", size = 620, top = 170 } = {}) {
  const base = sharp(`${SRC}/${src}`);
  const cut = region ? base.extract(region) : base;
  const buf = await cut.resize({ width: size, fit: "inside" }).png().toBuffer();
  const m = await sharp(buf).metadata();
  await sharp({ create: { width: S, height: S, channels: 3, background: bg } })
    .composite([
      { input: buf, top, left: Math.round((S - m.width) / 2) },
      { input: scrim, top: 0, left: 0 },
    ])
    .jpeg({ quality: 92 })
    .toFile(`${OUT}/${name}.jpg`);
  console.log(`  ${name}.jpg  ${m.width}x${m.height}`);
}

// 2 枚目（あと払い）: **アイコンだけ。** 2,000万 も ジャンルも出さない（他の枚と重複させない）
await panel("p-logo", "icon.jpg", null, { size: 520, top: 210 });
// 3 枚目（品ぞろえ）: ジャンルのタイル 6 枚
await panel("p-genre", "shot2.png", { left: 16, top: 150, width: 360, height: 330 }, { size: 760, top: 150 });
// 4 枚目（規模）: 2,000万アカウント突破
await panel("p-scale", "shot1.png", { left: 150, top: 385, width: 242, height: 150 }, { size: 760, top: 250 });
