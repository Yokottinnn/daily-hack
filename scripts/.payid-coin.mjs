import sharp from "sharp";
// **黒地が浮く**という指摘（2026-09-26）。硬貨だけを丸く抜いて、他のカードと同じ地に置く。
//
// 踏んだ穴 2 つ:
//   ① EXIF の向き情報があると metadata の幅高さと実体がずれる → 先に rotate()
//   ② **sharp は trim を composite より先に走らせる。** 同じ呼び出しに入れると
//      マスクと大きさが合わなくなる → **2 段に分ける**
const SRC = "public/images/payid-invite/src/coin1.jpg";
const OUT = "public/images/payid-invite/src/coin1-cut.png";

const base = await sharp(SRC).rotate().png().toBuffer();
const m = await sharp(base).metadata();
const r = Math.round(Math.min(m.width, m.height) / 2) - 6;   // 縁のにじみを落とす
const mask = Buffer.from(
  `<svg width="${m.width}" height="${m.height}"><circle cx="${Math.round(m.width / 2)}" cy="${Math.round(m.height / 2)}" r="${r}" fill="#fff"/></svg>`
);

// 1 段目: 円の外を透明にする
const cut = await sharp(base).composite([{ input: mask, blend: "dest-in" }]).png().toBuffer();
// 2 段目: 透明な余白を落とす
await sharp(cut).trim().png().toFile(OUT);

const m2 = await sharp(OUT).metadata();
console.log(`  ${OUT}  元 ${m.width}x${m.height} -> ${m2.width}x${m2.height}  alpha=${m2.hasAlpha}`);
