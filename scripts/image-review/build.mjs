// X 告知画像のレビューページを組み立てる。
//
//   node scripts/image-review/build.mjs [出力先]
//   → 既定の出力先は <リポジトリ>/.image-review.built.html（commit しない）
//   → Artifact ツールでその HTML を publish する（URL は docs/image-review-page.md）
//
// **画像は data URI でページに埋め込む。相対パスで外部ファイルを読ませない。**
// 2026-09-20、`files` で画像を隣に publish して相対パス（`img/<slug>/<file>`）で
// 参照したところ、**公開後に 8 枚 とも出なかった。**
// ローカルでは 8 枚 とも読めていた（`naturalWidth` で確認）ので、
// **こちらで見ているかぎり気づけない**（最上位ルール 14 と同じ根）。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "../..");
const IMAGES = path.join(ROOT, "public/images");
const TEMPLATE = path.join(HERE, "page.html");
const OUT = process.argv[2] || path.join(ROOT, ".image-review.built.html");

// 画像を足す・差し替えるときはここと page.html の SETS を**両方** 直す
const FILES = {
  "walk-poikatsu-2026": ["1-summary.jpg", "2-waon.jpg", "3-bitwalk.jpg", "4-jal.jpg"],
  "tokyo-discount-supermarket-2026": ["1-summary.jpg", "2-trial-seiyu.jpg", "3-hanamasa.jpg", "4-tv.jpg"],
};

const map = {};
let raw = 0;
for (const [slug, files] of Object.entries(FILES)) {
  for (const f of files) {
    const p = path.join(IMAGES, slug, "x", f);
    const buf = fs.readFileSync(p);
    // **空でないことを見る。** 読めた rc は証拠にならない（最上位ルール 13）
    if (!buf.length) throw new Error("空のファイル: " + p);
    raw += buf.length;
    map[`${slug}/${f}`] = "data:image/jpeg;base64," + buf.toString("base64");
  }
}

const src = fs.readFileSync(TEMPLATE, "utf8");
if (!src.includes("/*__IMAGES__*/{}")) throw new Error("page.html に差し込み口が無い");
const out = src.replace("/*__IMAGES__*/{}", JSON.stringify(map));
fs.writeFileSync(OUT, out);

// **対象 N / 埋めた M を必ず両方 出す。** 合わなければここで気づける（最上位ルール 14）
const target = Object.values(FILES).flat().length;
console.log(`対象 ${target} 枚 / 埋めた ${Object.keys(map).length} 枚`);
console.log(`元 ${(raw / 1048576).toFixed(2)} MB → ページ ${(Buffer.byteLength(out) / 1048576).toFixed(2)} MB（上限 16 MB）`);
console.log(`出力: ${OUT}`);
