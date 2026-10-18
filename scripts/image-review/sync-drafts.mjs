// レビューページで利用者が**直接 書き換えた文面**（Artifact DB の drafts）を、posts.json に取り込む。
//
//   1) ArtifactData(action="list", url=<レビューページ>, collection="drafts", out_dir=<DIR>) で書き出す
//   2) node scripts/image-review/sync-drafts.mjs <DIR>/drafts
//
// ## なぜ（2026-10-18・利用者に「ここ数回発生してる。大問題」と指摘された）
//
// ページで文面を直すと drafts に入り、ページ上は直した文で表示される。だがこちらはコメント（pins）しか読まず、
// **drafts を一度も読まないまま posts.json の古い文で投稿していた。** 7 本が反映されないまま出た（フォロワー500人など）。
//
// ## やること
//
//   - drafts.json（スナップショット）を書く。syncedAt はこの取り込みの時刻
//   - 書き換えが posts.json と違えば、**posts.json を書き換えに合わせる**（利用者の文が正）
//   - ただし承認済み（posts.lock.json にある）の文面は書き換えない。食い違いとして出して止まる
//     （投稿済みで取りこぼしたものは drafts.json の acknowledged に理由つきで残す）
import fs from "node:fs";
import path from "node:path";

const HERE = path.dirname(new URL(import.meta.url).pathname);
const dir = process.argv[2];
if (!dir || !fs.existsSync(dir)) { console.error("usage: node scripts/image-review/sync-drafts.mjs <ArtifactData の out_dir>/drafts"); process.exit(1); }

const POSTS = path.join(HERE, "posts.json");
const SNAP = path.join(HERE, "drafts.json");
const posts = JSON.parse(fs.readFileSync(POSTS, "utf8"));
const lock = JSON.parse(fs.readFileSync(path.join(HERE, "posts.lock.json"), "utf8")).locked || {};
const prev = fs.existsSync(SNAP) ? JSON.parse(fs.readFileSync(SNAP, "utf8")) : {};
const acknowledged = prev.acknowledged || {};

const drafts = {};
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
  const doc = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
  const d = doc.data || doc;
  if (!d.target || typeof d.text !== "string") continue;
  drafts[d.target] = { text: d.text, updatedAt: d.updatedAt || null };
}

let applied = 0, same = 0;
const conflicts = [];
for (const [target, { text }] of Object.entries(drafts)) {
  const m = target.match(/^(.+)\/text-(\d+)$/);
  if (!m) { conflicts.push(`${target}: 形が読めない`); continue; }
  const [, key, n] = m; const i = +n - 1;
  const cur = (posts[key] || [])[i];
  if (cur === text) { same++; continue; }
  if (acknowledged[target]) continue;
  if (lock[`${key}[${i}]`]) { conflicts.push(`${target}: 承認済み（ロック済み）の文面と違う。投稿済みで取りこぼしたなら drafts.json の acknowledged に理由を書く`); continue; }
  if (!posts[key]) posts[key] = [];
  posts[key][i] = text;
  applied++;
  console.log(`  取り込んだ: ${target}`);
}
fs.writeFileSync(POSTS, JSON.stringify(posts, null, 2) + "\n");
fs.writeFileSync(SNAP, JSON.stringify({
  _doc: "レビューページの書き換え（drafts）のスナップショット。sync-drafts.mjs が書く。build.mjs と guard-post-approval.py が読む",
  syncedAt: new Date().toISOString(), drafts, acknowledged,
}, null, 2) + "\n");
console.log(`書き換え ${Object.keys(drafts).length} 本 / 取り込んだ ${applied} / もう同じ ${same} / 食い違い ${conflicts.length}`);
if (conflicts.length) { conflicts.forEach((c) => console.error("  **" + c + "**")); process.exit(2); }
