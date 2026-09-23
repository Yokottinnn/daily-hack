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
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "../..");
const IMAGES = path.join(ROOT, "public/images");
const TEMPLATE = path.join(HERE, "page.html");
const OUT = process.argv[2] || path.join(ROOT, ".image-review.built.html");

// 画像を足す・差し替えるときはここと page.html の SETS を**両方** 直す
const FILES = {
  "walk-poikatsu-2026": ["1-summary.jpg", "2-waon.jpg", "3-web3.jpg", "4-mile.jpg"],
  "tokyo-discount-supermarket-2026": ["1-summary.jpg", "2-maibasket.jpg", "3-hanamasa.jpg", "4-tv.jpg"],
  // **1 枚だけ**（2026-09-22 のコメント）。版A（実写あり）が選ばれ、版B は削除した
  "morning-500-2026": ["cover-a.jpg"],
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

// 投稿文。**X の重みをここで数えて、280 を超えていたら止める**
// （超えると投稿ボタンが有効にならず、エラーらしいエラーも出ずに落ちる）
const posts = JSON.parse(fs.readFileSync(path.join(HERE, "posts.json"), "utf8"));
const weight = (s) => {
  let n = 0;
  // **URL は t.co で常に 23。** 生の長さで数えると外す
  for (const c of s.replace(/https?:\/\/\S+/g, "#".repeat(23))) n += c.codePointAt(0) < 0x80 ? 1 : 2;
  return n;
};
// **承認済みの文面が書き換わっていたら止める**（2026-09-22 に作った）。
//
// 承認済みの [1/2] を、**画像に付いたコメントを文面への指示だと読み違えて**
// 指示なく書き換え、「なんで勝手に変えたの？？」「台無しになっている」と差し戻された。
// **文書に書くだけでは防げない**（同じ根の事故が繰り返されている）のでここで止める。
// 更新してよい条件は `posts.lock.json` の `_howto` にある。
const LOCK = path.join(HERE, "posts.lock.json");
const lock = JSON.parse(fs.readFileSync(LOCK, "utf8"));
const sha = (s) => createHash("sha256").update(s, "utf8").digest("hex");
let locked = 0;
let filled = false;
for (const [k, list] of Object.entries(posts)) {
  list.forEach((t, i) => {
    const w = weight(t);
    console.log(`  ${k} [${i + 1}/${list.length}]  重み ${w} / 280（余裕 ${280 - w}）`);
    if (w > 275) throw new Error(`${k} [${i + 1}] が重み ${w}。280 以内・余裕 5 以上にする`);

    const entry = lock.locked[`${k}[${i}]`];
    if (!entry) return;
    locked++;
    // 初回だけ空のハッシュを埋める。**2 回目以降は照合する**
    if (!entry.sha256) { entry.sha256 = sha(t); filled = true; return; }
    if (entry.sha256 !== sha(t)) {
      throw new Error(
        `${k} [${i + 1}] は **${entry.approvedAt} に承認済みの文面**で、書き換わっている。\n` +
        `  承認の根拠: ${entry.reason}\n` +
        `  **利用者が「その文面を直せ」と言っていないなら、文面のほうを戻すこと。**\n` +
        `  画像へのコメント・自分の判断・整合性の都合では変えない。\n` +
        `  言われて直したのなら ${path.relative(ROOT, LOCK)} の sha256 と reason を更新する。`);
    }
  });
}
if (filled) fs.writeFileSync(LOCK, JSON.stringify(lock, null, 2) + "\n");
console.log(`承認済みの文面 ${locked} 本 を照合${filled ? "（初回なのでハッシュを記録した）" : "・一致"}`);

const src = fs.readFileSync(TEMPLATE, "utf8");
for (const slot of ["/*__IMAGES__*/{}", "/*__POSTS__*/{}"]) {
  if (!src.includes(slot)) throw new Error("page.html に差し込み口が無い: " + slot);
}
const out = src
  .replace("/*__IMAGES__*/{}", JSON.stringify(map))
  .replace("/*__POSTS__*/{}", JSON.stringify(posts));
fs.writeFileSync(OUT, out);

// **対象 N / 埋めた M を必ず両方 出す。** 合わなければここで気づける（最上位ルール 14）
const target = Object.values(FILES).flat().length;
console.log(`対象 ${target} 枚 / 埋めた ${Object.keys(map).length} 枚`);
console.log(`元 ${(raw / 1048576).toFixed(2)} MB → ページ ${(Buffer.byteLength(out) / 1048576).toFixed(2)} MB（上限 16 MB）`);
console.log(`出力: ${OUT}`);
