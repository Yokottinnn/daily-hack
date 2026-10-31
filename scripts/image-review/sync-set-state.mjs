#!/usr/bin/env node
// レビューページで付けた「投稿しない（見送り）」の印を set-status.json に写す（2026-10-31・利用者の指示）。
//
// > 投稿するつもりがないものはちゃんとチェックをつけられるようにしたい
// > そうじゃないと一生「次に出す予定のもの」に溜まっていくでしょ？
//
//   ArtifactData(action="list", url=https://claude.ai/artifact/1o7gjZZghit8kn3W4AXUdH, collection="set_state", out_dir=<dir>)
//   node scripts/image-review/sync-set-state.mjs <dir>/set_state
//
// **利用者の印が正。** 投稿済み（posted）と終了（done）の組には触らない（ページ側でも変えられない）。
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const dir = process.argv[2];
if (!dir) { console.error("usage: sync-set-state.mjs <set_state を書き出したディレクトリ>"); process.exit(2); }
const F = path.join(HERE, "set-status.json");
const st = JSON.parse(fs.readFileSync(F, "utf8"));
let changed = 0;
for (const f of fs.existsSync(dir) ? fs.readdirSync(dir).filter((x) => x.endsWith(".json")) : []) {
  const raw = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
  const v = raw.data || raw;
  const key = v.key || path.basename(f, ".json");
  const cur = st[key] || {};
  if (cur.status === "posted" || cur.status === "done") continue;
  if (v.state !== "dropped" && v.state !== "draft") continue;
  if ((cur.status || "draft") === v.state) continue;
  st[key] = Object.assign({}, cur, { status: v.state,
    note: v.state === "dropped" ? `${String(v.at || "").slice(0, 10)} 利用者がレビューページで「投稿しない」にした` : `${String(v.at || "").slice(0, 10)} 利用者がレビューページで候補に戻した` });
  console.log(`${key}: ${cur.status || "draft"} → ${v.state}`);
  changed++;
}
if (changed) fs.writeFileSync(F, JSON.stringify(st, null, 2) + "\n");
console.log(`写した印 ${changed} 件`);
