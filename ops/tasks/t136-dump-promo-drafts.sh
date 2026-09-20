#!/bin/bash
# **キューに残っている告知の草案を、そのまま持ち帰る（t136）。**
#
# 2026-09-20、利用者から「歩いてポイ活の 1 投稿目の文章が全然違う」と指摘された。
# **前に出した草案がリポジトリにも会話の記録にも残っていない。**
# 画像は PR #561 / #563 / #564 / #582 で残っているのに、**文面だけ残していなかった。**
# CLAUDE.md 最上位ルール 3「会話の中だけに状況を残さない」を踏んでいる。
#
# キューに `awaiting_approval` で積んであるなら、**文面はそこに在る。**
# ここで丸ごと出して、リポジトリに残す。
#
# **投稿しない。削除しない。承認もしない。** 読むだけ。
# **秘密は出さない**（トークン・API キーは触らない）。LLM 不使用・$0/回・$0/日・$0/月

set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t136-promo-drafts.md"
QJSON="$W/data/post_queue.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /opt/homebrew/bin/node)"

{
  echo "# キューに残っている告知の草案（t136）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

if [ ! -f "$QJSON" ]; then
  echo "⚠️ **キューが無い。** \`$QJSON\`" >> "$OUT"
  cat "$OUT"; exit 0
fi
if [ ! -x "$NODE_BIN" ]; then
  echo "⚠️ **node が見つからない。**" >> "$OUT"
  cat "$OUT"; exit 0
fi

"$NODE_BIN" -e '
const fs = require("fs");
const q = process.argv[1];
let d;
try { d = JSON.parse(fs.readFileSync(q, "utf8")); }
catch (e) { console.log("⚠️ **キューが JSON として読めない。** " + String(e.message).slice(0, 120)); process.exit(0); }
const rows = Array.isArray(d) ? d : (d.entries || d.queue || d.items || []);
console.log("キュー全体: **" + rows.length + " 件**\n");

// **記事の告知だけを見る。** 返信・トレンドは対象外
const want = /walk-poikatsu|tokyo-discount-supermarket|hoso-daigaku|blog-promo/i;
const hit = rows.filter(r => want.test(JSON.stringify(r.id || "") + " " + JSON.stringify(r.slug || "")));
console.log("告知らしいもの: **" + hit.length + " 件**\n");

// 新しい順に 12 件だけ出す（レポートが長くなりすぎないように）
hit.sort((a, b) => String(b.created_at || b.at || "").localeCompare(String(a.created_at || a.at || "")));
for (const r of hit.slice(0, 12)) {
  console.log("## `" + (r.id || "(id なし)") + "`\n");
  console.log("- status: **" + (r.status || "?") + "** / posted: " + (r.posted === true ? "**true**" : String(r.posted)));
  console.log("- 作成: " + (r.created_at || r.at || "?"));
  if (r.x_tweet_id || r.tweet_id) console.log("- **x_tweet_id: `" + (r.x_tweet_id || r.tweet_id) + "`**");
  if (r.image_path) console.log("- 画像: `" + String(r.image_path).slice(0, 200) + "`");
  console.log("");
  // **本文は加工せずそのまま出す。** 要約も整形もしない
  const parts = [];
  if (r.text) parts.push(["text", r.text]);
  if (Array.isArray(r.thread_chain)) {
    r.thread_chain.forEach((t, i) => parts.push(["thread_chain[" + i + "]", (t && (t.text || t.body)) || ""]));
  }
  if (Array.isArray(r.thread)) {
    r.thread.forEach((t, i) => parts.push(["thread[" + i + "]", (t && (t.text || t.body)) || t]));
  }
  for (const [k, v] of parts) {
    if (!v) continue;
    console.log("### " + k + "\n");
    console.log("```");
    console.log(String(v));
    console.log("```\n");
  }
  if (parts.length === 0) console.log("**本文のフィールドが無い。** キーの一覧: `" + Object.keys(r).join(", ") + "`\n");
}
' "$QJSON" >> "$OUT" 2>&1

cat "$OUT"
