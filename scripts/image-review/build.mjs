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
import sharp from "sharp";
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
  // **2 パターンの文面で同じ 4 枚を見てもらう**（2026-09-26 の指示）。
  // 素材は App Store 掲載素材とアイコンだけなので、出所の行が要らない
  "payid-invite": ["1-summary.jpg", "2-atobarai.jpg", "3-shops.jpg", "4-rating.jpg"],
  // **記事の告知ではない**（2026-10-03・300 フォロワーのお礼）。1 枚だけ。
  // 素材はキャラ（expr-04-cheer.png）と自作の図だけなので、出所の行が要らない
  // 2026-10-03 に 3 版目の静止画へ「とてもいいね👍」。動く版（GIF）は同じ絵に動きを付けたもの
  "follower-300": ["1-card.jpg", "1-card-ai.gif", "1-card.gif", "1-card-v2.gif"],
  // **未投稿**（2026-10-04）。1〜3 枚目は利用者が Slack で共有したアプリの画面（本人の画面・切り出しだけ）。
  // 4 枚目はロゴ（App Store のアイコン）と App Store 掲載素材の自作カード。出所の行が要らない
  "jal-2x-2026-10": ["1-notice.jpg", "2-monthly.jpg", "3-history.jpg", "4-service.jpg"],
  // **未投稿**（2026-10-05）。FUNDS の紹介（利用者の招待リンク）。素材は招待ページと funds.jp の画面だけ（公式の画面・出所の行は要らない）
  "funds-invite-2026-10": ["1-gift.jpg", "2-service.jpg", "3-fund.jpg", "4-story.jpg"],
  // **未投稿**（2026-10-11）。blog3 から依頼の告知 3 本。scripts/gen-x-panels.mjs で ops/data/x-cards/<slug>.panels.json から作る。
  // 写真は Commons の CC0 / パブリックドメイン（x/src/_manifest.json）とロゴだけなので、出所の行が要らない
  "momiji-2026-kanto": ["1-calendar.jpg", "2-takao.jpg", "3-rikugien.jpg", "4-nikko.jpg"],
  "takanawa-gateway-city-guide-2026": ["1-morning.jpg", "2-luftbaum.jpg", "3-mon.jpg", "4-access.jpg"],
  "furusato-portal-comparison-2026": ["1-ban.jpg", "2-points.jpg", "3-anapay.jpg", "4-steps.jpg"],
};

const map = {};
let raw = 0;
for (const [slug, files] of Object.entries(FILES)) {
  for (const f of files) {
    const p = path.join(IMAGES, slug, "x", f);
    let buf = fs.readFileSync(p);
    // **空でないことを見る。** 読めた rc は証拠にならない（最上位ルール 13）
    if (!buf.length) throw new Error("空のファイル: " + p);
    // **大きい GIF はページに埋める分だけ 440px に縮める**（ページの上限 16MB。2026-10-03 に GIF 2 本で超えた）。
    // 投稿に使う元のファイルは触らない。コメントの位置は割合なので縮めてもずれない
    if (f.endsWith(".gif") && buf.length > 3 * 1048576) {
      // 2026-10-11 に告知 3 本（12 枚）を足して 16.79 MB になったので 540 → 440px に下げた
      buf = await sharp(buf, { animated: true }).resize(440, 440).gif({ effort: 7, colours: 256, dither: 0.6 }).toBuffer();
    }
    raw += buf.length;
    // **拡張子で型を変える。** GIF を image/jpeg で埋めると動かないことがある
    const mime = f.endsWith(".gif") ? "image/gif" : f.endsWith(".png") ? "image/png" : "image/jpeg";
    map[`${slug}/${f}`] = `data:${mime};base64,` + buf.toString("base64");
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

// **投稿スタイル。** 各 SET がどの型で書かれたかを、書き忘れたまま出せないようにする
// （2026-10-02 に「どの投稿スタイルで投稿するかを各投稿で意図を持って選択し、
//   それが正しく反映されている状態を作りたい」と指示された）。
// 目録は styles.json、割り当ては set-styles.json。説明は x-post-copy スキル §1-B
const catalog = JSON.parse(fs.readFileSync(path.join(HERE, "styles.json"), "utf8"));
const setStyles = JSON.parse(fs.readFileSync(path.join(HERE, "set-styles.json"), "utf8"));
const styleIds = new Set(catalog.styles.map((s) => s.id));
const groupIds = new Set(catalog.groups.map((g) => g.id));
for (const s of catalog.styles) {
  if (!groupIds.has(s.group)) throw new Error(`styles.json: ${s.id} の group「${s.group}」が groups に無い`);
}
const setKeys = [...src.matchAll(/^\s*key: "([^"]+)"/gm)].map((m) => m[1]);
if (!setKeys.length) throw new Error("page.html の SETS から key が 1 つも取れない");
for (const k of setKeys) {
  const a = setStyles[k];
  if (!a || !a.style) throw new Error(`${k} に投稿スタイルが無い。set-styles.json に style と why を書く（x-post-copy スキル §1-B）`);
  if (!styleIds.has(a.style)) throw new Error(`${k} の style「${a.style}」は styles.json の目録に無い`);
  if (!a.why || !String(a.why).trim()) throw new Error(`${k} に why（なぜその型を選んだか）が無い`);
  const name = catalog.styles.find((s) => s.id === a.style).name;
  console.log(`  ${k}  スタイル: ${a.style}（${name}）`);
}
for (const k of Object.keys(setStyles)) {
  if (k.startsWith("_")) continue;
  if (!setKeys.includes(k)) throw new Error(`set-styles.json の ${k} は page.html の SETS に無い（消し忘れ）`);
}
console.log(`投稿スタイル: SET ${setKeys.length} 件 すべて指定済み（目録 ${catalog.styles.length} 型）`);

for (const slot of ["/*__IMAGES__*/{}", "/*__POSTS__*/{}", "/*__STYLES__*/{}"]) {
  if (!src.includes(slot)) throw new Error("page.html に差し込み口が無い: " + slot);
}
const out = src
  .replace("/*__IMAGES__*/{}", JSON.stringify(map))
  .replace("/*__POSTS__*/{}", JSON.stringify(posts))
  .replace("/*__STYLES__*/{}", JSON.stringify({ groups: catalog.groups, styles: catalog.styles, sets: setStyles }));
fs.writeFileSync(OUT, out);

// **対象 N / 埋めた M を必ず両方 出す。** 合わなければここで気づける（最上位ルール 14）
const target = Object.values(FILES).flat().length;
console.log(`対象 ${target} 枚 / 埋めた ${Object.keys(map).length} 枚`);
console.log(`元 ${(raw / 1048576).toFixed(2)} MB → ページ ${(Buffer.byteLength(out) / 1048576).toFixed(2)} MB（上限 16 MB）`);
console.log(`出力: ${OUT}`);
