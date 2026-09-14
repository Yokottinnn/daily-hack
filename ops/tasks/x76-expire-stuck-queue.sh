#!/bin/bash
# **承認待ちのまま TTL を超えたものを失効させる。投稿しない。費用 $0。**
#
# ## なぜ（x75 の実測・2026-09-14 02:27 時点）
#
#   承認待ちのまま: 23 件
#     grok-comment 17 件（最古 54 日前）
#     grok-post     1 件（42 日前）
#     qt-past       1 件（6 日前）
#     trend         4 件（4〜5 日前）
#
# 残っている理由は **`poll-approvals` が停止中**で、失効処理（`mark-skipped`）が
# 走っていないため。`queue-manager` の TTL ガードが投稿対象から除外しているので
# **投稿される危険は無い。** 一覧が読みにくいだけ。
#
# ## 触る範囲（**7 日 を超えたものだけ**）
#
# TTL は 7 日（`APPROVAL_TTL_DAYS`）。**7 日 以内のものは触らない。**
# `trend-20260908` / `trend-20260909` / `qt-past-20260908` はまだ TTL 内なので、
# **承認されれば出る余地を残す。**
#
# 起点は `poll-approvals.js` と同じ **`drafted_at` → `created_at`** の順。
# どちらも無いものは**触らない**（判断材料が無いものを消さない）。
#
# ## 安全策
#
#   - **先に退避**（`post_queue.json.bak-<時刻>`）
#   - **1 件ずつ `queue-manager.js mark-skipped` を使う**（JSON を直接 書き換えない）
#   - 理由は `expired_ttl_7d_cleanup`（**後から grep で追える**）
#   - **投稿しない。承認しない。削除しない**（印を付けるだけ）
#
# ## やらないこと
#
# **投稿しない。LLM を呼ばない（$0）。ブラウザを触らない。**
# **7 日 以内のものに触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/expire-stuck-queue.md"
NODE_BIN="/usr/local/bin/node"
Q="$D/post_queue.json"
QM="$S/queue-manager.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
TTL_DAYS=7
LIST="$(mktemp -t x76)"
trap 'rm -f "$LIST"' EXIT

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 承認待ちのまま TTL を超えたものを失効させる"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> x75 の実測: 承認待ちのまま **23 件**（最古 54 日前）。"
echo "> 残っている理由は \`poll-approvals\` が停止中で失効処理が走っていないため。"
echo "> **\`queue-manager\` の TTL ガードが投稿対象から除外しているので、投稿の危険は無い。**"
echo
echo "**触るのは 7 日 を超えたものだけ。投稿しない。削除しない。印を付けるだけ。**"

# ═══════════ 0. 対象を選ぶ ═══════════
echo
echo "## 0. 対象（**7 日 を超えたものだけ**）"
echo
echo '```'
if [ ! -f "$Q" ]; then
  echo "  **$Q が無い。**"
elif [ ! -f "$QM" ]; then
  echo "  **$QM が無い。** 直接 書き換えないので、ここで止める"
else
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const TTL = Number(process.argv[2]);
const q = Array.isArray(j.queue) ? j.queue : [];
const now = Date.now();
const rows = [];
for (const x of q) {
  if (!x || !x.id) continue;
  if (x.x_tweet_id || x.tweet_id) continue;                 // 出たものは触らない
  if (!/awaiting/i.test(String(x.status || ""))) continue;  // 承認待ち以外は触らない
  const stamp = x.drafted_at || x.created_at || "";          // poll-approvals と同じ順
  if (!stamp) continue;                                      // 判断材料が無いものは触らない
  const days = (now - Date.parse(stamp)) / 86400000;
  rows.push({ id: x.id, days: Math.floor(days), over: days > TTL, stamp: String(stamp).slice(0, 16) });
}
const over = rows.filter((r) => r.over);
const keep = rows.filter((r) => !r.over);
console.log("  承認待ち: " + rows.length + " 件");
console.log("  → **失効させる（" + TTL + " 日 超え）: " + over.length + " 件**");
console.log("  → 触らない（TTL 内）        : " + keep.length + " 件");
console.log("");
console.log("  === 失効させるもの ===");
for (const r of over) console.log("    " + r.stamp.padEnd(17) + String(r.days).padStart(3) + " 日前  " + r.id);
console.log("");
console.log("  === 触らないもの（まだ出る余地を残す） ===");
for (const r of keep) console.log("    " + r.stamp.padEnd(17) + String(r.days).padStart(3) + " 日前  " + r.id);
fs.writeFileSync(process.argv[3], over.map((r) => r.id).join("\n"));
' "$Q" "$TTL_DAYS" "$LIST" 2>&1 | clean
fi
echo '```'

# ═══════════ 1. 退避 ═══════════
echo
echo "## 1. 退避（**先に戻せる状態にする**）"
echo
echo '```'
if [ -f "$Q" ]; then
  cp "$Q" "$Q.bak-$STAMP" && echo "  $(basename "$Q").bak-$STAMP（$(wc -c < "$Q" | tr -d ' ') bytes）"
fi
echo '```'

# ═══════════ 2. 印を付ける ═══════════
echo
echo "## 2. 印を付ける（\`queue-manager.js mark-skipped\`）"
echo
echo "**JSON を直接 書き換えない。** 既存の口を使う。"
echo "理由は \`expired_ttl_7d_cleanup\`（**後から grep で追える**）。"
echo
echo '```'
N=0; OK=0; NG=0
if [ -s "$LIST" ] && [ -f "$QM" ]; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    N=$((N + 1))
    if R="$("$NODE_BIN" "$QM" mark-skipped "$id" "expired_ttl_7d_cleanup" 2>&1)"; then
      OK=$((OK + 1))
      echo "  ✅ $id  $(printf '%s' "$R" | head -1 | cut -c1-80)"
    else
      NG=$((NG + 1))
      echo "  ❌ $id  $(printf '%s' "$R" | head -1 | cut -c1-120)"
    fi
  done < "$LIST"
  echo
  echo "  打った: $N 件 / 成功 $OK 件 / 失敗 $NG 件"
else
  echo "  対象が無い（または queue-manager.js が無い）。何もしない"
fi
echo '```'

# ═══════════ 3. 結果の状態を別の口で確かめる ═══════════
echo
echo "## 3. 結果（**\`rc=0\` ではなく状態で確かめる**・ルール 13）"
echo
echo '```'
if [ -f "$Q" ]; then
  "$NODE_BIN" -e '
const fs = require("fs");
const j = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const q = Array.isArray(j.queue) ? j.queue : [];
const awaiting = q.filter((x) => x && !(x.x_tweet_id || x.tweet_id) && /awaiting/i.test(String(x.status || "")));
const cleaned = q.filter((x) => x && /expired_ttl_7d_cleanup/.test(String(x.status || "") + String(x.skip_reason || "")));
console.log("  キュー全体          : " + q.length + " 件");
console.log("  承認待ちのまま残った: **" + awaiting.length + " 件**");
for (const x of awaiting.slice(0, 8)) {
  const stamp = x.drafted_at || x.created_at || "";
  console.log("    " + String(stamp).slice(0, 16) + "  " + x.id + "  status=" + x.status);
}
console.log("");
console.log("  今回の印が付いた    : **" + cleaned.length + " 件**");
for (const x of cleaned.slice(0, 5)) console.log("    " + x.id + "  status=" + x.status);
' "$Q" 2>&1 | clean
fi
echo '```'
echo
echo "**残った件数が「触らないもの」と一致していれば成功。**"
echo "一致していなければ、\`mark-skipped\` の印の付き方が想定と違う。"
echo "その場合は **$(basename "$Q").bak-$STAMP から戻せる。**"

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**印を付けるだけ。投稿しない。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
echo
echo "返信ループの実額は 1 回 \$0.003 ／ 1 日 上限 \$0.048 ／ 1 か月 上限 \$1.44"
echo "（\`MAX_PICKS\` は 4 のまま・2026-09-13 に利用者が判断）。"
} > "$OUT" 2>&1

echo "止まったキューの失効 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
