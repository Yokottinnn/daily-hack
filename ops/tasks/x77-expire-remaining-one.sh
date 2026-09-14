#!/bin/bash
# **x76 が取りこぼした 1 件を失効させる。投稿しない。費用 $0。**
#
# ## x76 のバグ（**私のミス**）
#
#   → 失効させる（7 日 超え）: **19 件**
#   打った: **18 件** / 成功 18 件 / 失敗 0 件
#
# **対象リストを `join("\n")` で書いたため、末尾に改行が無かった。**
# `while IFS= read -r id` は**最後の改行が無い行を読み飛ばす。**
# 失敗ではなく、**そもそも打っていない。** rc は全部 0 なので気づけない形だった。
#
# 取りこぼし: `grok-comment-20260907-1502-1`（2026-09-07 15:02・7 日 超え）
#
# ## 直し方（このタスク）
#
# 1 件だけなのでループを使わず、**直接 打つ。**
# 打った後に**承認待ちの残りを数え直して**、TTL 内の 4 件だけになることを確かめる。
#
# ## 次から踏まないために
#
#   - リストを書くときは**末尾に改行を付ける**（`join("\n") + "\n"`）
#   - あるいは `while IFS= read -r x || [ -n "$x" ]; do` にする
#
# `CLAUDE.md` の最上位ルール 14 に追記した。
#
# ## やらないこと
#
# **投稿しない。削除しない。TTL 内の 4 件に触らない。LLM を呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/expire-remaining-one.md"
NODE_BIN="/usr/local/bin/node"
Q="$D/post_queue.json"
QM="$S/queue-manager.js"
TARGET="grok-comment-20260907-1502-1"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# x76 が取りこぼした 1 件を失効させる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **対象 19 件 のうち 18 件 しか打っていなかった。**"
echo "> 原因はリストの末尾に改行が無く、\`while read\` が最後の 1 行を読み飛ばしたこと。"
echo "> **失敗ではなく、そもそも打っていない。rc は全部 0 なので気づけない形だった。**"
echo
echo "**1 件だけなのでループを使わず直接 打つ。**"

# ═══════════ 0. 打つ前 ═══════════
echo
echo "## 0. 打つ前（**対象の実物**）"
echo
echo '```'
if [ ! -f "$Q" ]; then
  echo "  **$Q が無い。**"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const x = q.find((e) => e && e.id === process.argv[2]);
if (!x) { console.log("  **" + process.argv[2] + " が見つからない。**"); process.exit(0); }
const stamp = x.drafted_at || x.created_at || "";
const days = stamp ? ((Date.now() - Date.parse(stamp)) / 86400000).toFixed(1) : "?";
console.log("  id     : " + x.id);
console.log("  打刻   : " + String(stamp).slice(0, 19) + "（" + days + " 日前）");
console.log("  状態   : " + (x.status || "?"));
console.log("  出たか : " + (x.x_tweet_id || x.tweet_id ? "**出ている。触らない**" : "出ていない"));
console.log("  本文   : " + String(x.text || "").replace(/\n/g, " / ").slice(0, 160));
' "$Q" "$TARGET" 2>&1 | clean
fi
echo '```'

# ═══════════ 1. 退避して打つ ═══════════
echo
echo "## 1. 打つ"
echo
echo '```'
if [ ! -f "$Q" ] || [ ! -f "$QM" ]; then
  echo "  **対象か queue-manager.js が無い。** 何もしない"
else
  SAFE="$("$NODE_BIN" -e '
const fs=require("fs");
const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const x=(j.queue||[]).find(e=>e&&e.id===process.argv[2]);
if(!x){console.log("missing");process.exit(0);}
if(x.x_tweet_id||x.tweet_id){console.log("posted");process.exit(0);}
if(!/awaiting/i.test(String(x.status||""))){console.log("not-awaiting");process.exit(0);}
const s=x.drafted_at||x.created_at||"";
if(!s){console.log("no-stamp");process.exit(0);}
console.log(((Date.now()-Date.parse(s))/86400000) > 7 ? "ok" : "within-ttl");
' "$Q" "$TARGET" 2>/dev/null)"
  echo "  事前判定: $SAFE"
  if [ "$SAFE" != "ok" ]; then
    echo "  **条件を満たさないので打たない。**（出ている／TTL 内／打刻が無い／見つからない）"
  else
    cp "$Q" "$Q.bak-$STAMP" && echo "  退避: $(basename "$Q").bak-$STAMP"
    if R="$("$NODE_BIN" "$QM" mark-skipped "$TARGET" "expired_ttl_7d_cleanup" 2>&1)"; then
      echo "  ✅ $TARGET  $(printf '%s' "$R" | head -1 | cut -c1-80)"
    else
      echo "  ❌ $TARGET  $(printf '%s' "$R" | head -1 | cut -c1-120)"
    fi
  fi
fi
echo '```'

# ═══════════ 2. 結果 ═══════════
echo
echo "## 2. 結果（**状態で確かめる**・ルール 13）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const awaiting = q.filter((x) => x && !(x.x_tweet_id || x.tweet_id) && /awaiting/i.test(String(x.status || "")));
const cleaned = q.filter((x) => x && /expired_ttl_7d_cleanup/.test(String(x.status || "")));
console.log("  キュー全体          : " + q.length + " 件");
console.log("  承認待ちのまま残った: **" + awaiting.length + " 件**");
const now = Date.now();
for (const x of awaiting) {
  const s = x.drafted_at || x.created_at || "";
  const d = s ? ((now - Date.parse(s)) / 86400000).toFixed(1) : "?";
  console.log("    " + String(s).slice(0, 16) + "  " + d + " 日前  " + x.id);
}
console.log("");
console.log("  今回の掃除で印が付いた合計: **" + cleaned.length + " 件**");
console.log("");
console.log(awaiting.length === 4
  ? "  → **想定どおり。** 残りは TTL 内の trend 4 件 だけ"
  : "  → **想定と違う。** 残りが 4 件 になっていない。bak から戻せる");
' "$Q" 2>&1 | clean
fi
echo '```'

# ═══════════ 3. 次から踏まないために ═══════════
echo
echo "## 3. 次から踏まないために"
echo
echo "| やってしまったこと | 直し方 |"
echo "| --- | --- |"
echo "| \`join(\"\\\\n\")\` でリストを書いた | **末尾に改行を付ける**（\`join(\"\\\\n\") + \"\\\\n\"\`） |"
echo "| \`while IFS= read -r x; do\` | \`while IFS= read -r x \\|\\| [ -n \"\\\$x\" ]; do\` にする |"
echo "| 打った件数を対象件数と突き合わせなかった | **「対象 N 件 / 打った M 件」を必ず両方 出す** |"
echo
echo "**rc は全部 0 だった。** 失敗ではなく「打っていない」ので、"
echo "**rc を見ている限り永遠に気づけない**（最上位ルール 13 と同じ根）。"
echo "\`CLAUDE.md\` の最上位ルール 14 に追記した。"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**印を 1 つ 付けるだけ。投稿しない。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "取りこぼした 1 件の失効 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
