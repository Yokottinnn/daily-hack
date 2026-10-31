#!/usr/bin/env node
// 作戦室（マネタイズ作戦室）の「投稿準備中の下書き」に載せる中身を作る（2026-10-31・利用者の指示）。
//
// > 作戦室に常に投稿レビューページのリンクや今投稿準備中の下書きを表示させるようにして
//
// 出力は db の `xdrafts/current` 1 文書ぶんの JSON。**レビューページを publish したら、毎回これを作って書き込む**
// （x-post-copy スキル §5・docs/image-review-page.md）。
//
//   node scripts/image-review/board-drafts.mjs <出力ファイル>
//   ArtifactData(action="get", url=<作戦室>, collection="xdrafts", doc_id="current")   ← version を見る
//   ArtifactData(action="set", url=<作戦室>, collection="xdrafts", doc_id="current", file_path=<出力ファイル>, if_version=<version>)
//
// 「投稿していない組」の判定は `set-status.json`（一次情報＝キューの x_tweet_id で確かめて書く）と、
// page.html の `posted: [...]` の両方を見る。どちらかで投稿済み・見送りなら載せない。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const read = (f) => JSON.parse(fs.readFileSync(path.join(HERE, f), "utf8"));
const out = process.argv[2];
if (!out) { console.error("usage: board-drafts.mjs <出力ファイル>"); process.exit(2); }

const posts = read("posts.json");
const styles = read("set-styles.json");
const status = fs.existsSync(path.join(HERE, "set-status.json")) ? read("set-status.json") : {};
const catalog = read("styles.json");
const styleName = new Map((catalog.styles || []).map((s) => [s.id, s.name]));
let edited = new Set();
try { const d = read("drafts.json"); edited = new Set(Object.keys(d.drafts || {}).map((k) => k.split("/")[0])); } catch {}

// page.html の SETS から key・題名・画像の付け方・posted を引く
const page = fs.readFileSync(path.join(HERE, "page.html"), "utf8");
const meta = new Map();
for (const b of page.split(/\n\s*key:\s*"/).slice(1)) {
  const key = b.slice(0, b.indexOf('"'));
  const title = (b.match(/title:\s*"([^"]+)"/) || [])[1];
  const attach = (b.match(/attach:\s*"([^"]+)"/) || [])[1] || "";
  const pm = b.match(/posted:\s*\[([^\]]*)\]/);
  const posted = pm ? [...pm[1].matchAll(/"(\d+)"/g)].length > 0 : false;
  if (title && !meta.has(key)) meta.set(key, { title, attach, posted });
}

const weight = (s) => { let n = 0; for (const c of s.replace(/https?:\/\/\S+/g, "#".repeat(23))) n += c.codePointAt(0) < 0x80 ? 1 : 2; return n; };
const headOf = (t) => {
  if (weight(t) <= 275) return t;
  const lines = t.split("\n");
  const at = lines.findIndex((l, j) => l.trim().endsWith("👇") && (lines[j + 1] ?? "").trim() === "");
  if (at >= 0) return lines.slice(0, at + 1).join("\n");
  let fold = ""; for (const p of t.split(/\n\n/)) { const n = fold ? fold + "\n\n" + p : p; if (weight(n) > 275) break; fold = n; }
  return fold;
};

const drafts = [];
for (const [key, parts] of Object.entries(posts)) {
  const m = meta.get(key);
  if (!m) continue;
  const st = (status[key] && status[key].status) || "draft";
  if (m.posted || st !== "draft") continue;
  const sid = (styles[key] && styles[key].style) || "";
  drafts.push({ key, title: m.title, attach: m.attach, style: sid, styleName: styleName.get(sid) || sid,
    head: headOf(parts[0] || ""), parts, edited: edited.has(key),
    next: (status[key] && status[key].next) || null, why: (status[key] && status[key].why) || "", check: (status[key] && status[key].check) || [] });
}
drafts.sort((a, b) => (a.next || 99) - (b.next || 99));
const doc = { updatedAt: new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 19) + "+09:00", reviewUrl: "https://claude.ai/artifact/1o7gjZZghit8kn3W4AXUdH", drafts };
fs.writeFileSync(out, JSON.stringify(doc, null, 2) + "\n");
console.log(`下書き ${drafts.length} 組: ${drafts.map((d) => d.key).join(", ")}`);
