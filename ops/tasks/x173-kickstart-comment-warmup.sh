#!/bin/bash
# **`comment-warmup` をいま 1 回 撃つ。19:00 を待たない。**
#
# ## なぜ
#
# `x172` で常駐に戻した（`launchctl print` で `path` が `.plist` / `載っている` を確認済み）。
# **だが発火は 12:00 / 16:00 / 19:00 / 22:00 の 4 回。** 17:16 に戻したので、
# **放っておくと次は 19:00＝1 時間 44 分 後。**
#
# **最上位ルール 9**「待たなくていい時間を作らない」に当たる。
# `launchctl kickstart -k` で即座に走らせられるのだから、待たない。
#
# ## 気をつけること
#
# - **`kickstart` の rc=0 は「やった」証拠にならない**（最上位ルール 13）。
#   `launchctl print` の **`runs` が増えたこと**と**ログが伸びたこと**で確かめる
# - **量は変えない。** plist の `MAX_PICKS_PER_FIRE`（6）のまま撃つ
# - **`-k` は走っていれば一度 止めてから起こす。** 走っていなければそのまま起こす
#
# ## 費用（最上位ルール 2-B）
#
# **これは今日 1 回 分の追加発火である。**
#
#   1 回あたり   **最大 $0.025**（6 picks × 実測 $0.00417/件・Haiku 4.5）
#   1 日あたり   **最大 $0.025**（このタスクは 1 回しか走らない。最上位ルール 1）
#   1 か月あたり **最大 $0.025**（反復しない）
#
# **常駐ぶんとは別。** 常駐は実測 $0.081／日・約 $2.43／月（`x172` で戻した分）。
# 今日は 16:00 の試走（実測ぶん）＋ この 1 回 が乗る。
#
# ## やらないこと
#
# **設定を変えない。plist も触らない。テンプレートも文面も触らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
DOM="gui/$UID_N/$LABEL"
OUT="${OPS_REPORT_DIR:-/tmp}/kickstart-comment-warmup.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

runs_of() {
  launchctl print "$DOM" 2>/dev/null | awk '/^[[:space:]]+runs = /{gsub(/[^0-9]/,"",$0); print; exit}'
}
size_of() { [ -f "$1" ] && wc -c < "$1" | tr -d ' ' || printf '0'; }

{
echo "# comment-warmup をいま 1 回 撃つ（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **設定は変えない。** 量も plist のまま（\`MAX_PICKS_PER_FIRE=6\`）。"
echo "> **この 1 回の費用: 最大 \$0.025**（6 picks × 実測 \$0.00417/件）"

LOG="$L/comment-warmup.log"
OLOG="$L/comment-orchestrator.log"

echo
echo "## 1. 撃つ前"
echo
echo '```'
if launchctl print "$DOM" >/dev/null 2>&1; then
  R0="$(runs_of)"; [ -n "$R0" ] || R0=0
  printf '  載っている / runs = %s\n' "$R0"
  launchctl print "$DOM" 2>/dev/null | grep -E '^[[:space:]]+(state|path) ' | sed 's/^/    /'
else
  R0="-"
  echo "  **載っていない。撃てない。**"
fi
S0="$(size_of "$LOG")"; SO0="$(size_of "$OLOG")"
printf '  comment-warmup.log       %s bytes\n' "$S0"
printf '  comment-orchestrator.log %s bytes\n' "$SO0"
echo '```'
if [ "$R0" = "-" ]; then
  echo
  echo "- **載っていないので撃たない。** \`x172\` の結果を先に見る。"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 1
fi

echo
echo "## 2. 撃つ"
echo
echo '```'
KS="$(launchctl kickstart -k "$DOM" 2>&1)"; KRC=$?
printf '  kickstart -k rc=%s %s\n' "$KRC" "$(printf '%s' "$KS" | cut -c1-140)"
echo "  （**rc=0 は「やった」証拠にならない**。§3 で runs とログを見る）"
echo '```'

echo
echo "## 3. 本当に走ったか（**runs とログで見る**）"
echo
echo "**素の bash で待つ**（\`timeout\` は Mac に無い）。最大 200 秒。"
echo
echo '```'
W8=0
while [ "$W8" -lt 200 ]; do
  R1="$(runs_of)"; [ -n "$R1" ] || R1=0
  S1="$(size_of "$LOG")"; SO1="$(size_of "$OLOG")"
  if [ "$R1" != "$R0" ] || [ "$S1" != "$S0" ] || [ "$SO1" != "$SO0" ]; then break; fi
  sleep 5
  W8=$((W8 + 5))
done
R1="$(runs_of)"; [ -n "$R1" ] || R1=0
S1="$(size_of "$LOG")"; SO1="$(size_of "$OLOG")"
printf '  待った秒数: %s\n' "$W8"
printf '  runs                      %s → %s %s\n' "$R0" "$R1" "$( [ "$R1" != "$R0" ] && echo '← **増えた**' )"
printf '  comment-warmup.log        %s → %s bytes %s\n' "$S0" "$S1" "$( [ "$S1" != "$S0" ] && echo '← **伸びた**' )"
printf '  comment-orchestrator.log  %s → %s bytes %s\n' "$SO0" "$SO1" "$( [ "$SO1" != "$SO0" ] && echo '← **伸びた**' )"
echo
if [ "$R1" = "$R0" ] && [ "$S1" = "$S0" ] && [ "$SO1" = "$SO0" ]; then
  echo "  → **動いた形跡が無い。** rc=0 でも走っていない"
else
  echo "  → **走った**"
fi
echo '```'

echo
echo "## 4. 出力（**見た件数と打った件数を両方**）"
echo
echo '```'
for f in "$OLOG" "$LOG"; do
  [ -f "$f" ] || continue
  printf '  ===== %s（更新 %s）=====\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%H:%M:%S' "$f" 2>/dev/null)"
  tail -22 "$f" 2>/dev/null | cut -c1-200 | clean | sed 's/^/    /'
  echo
done
echo '```'

echo
echo "## 5. キューに積まれたか（**一次情報**）"
echo
echo "**ログではなくキューを見る**（最上位ルール 11）。"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **post_queue.json が読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const since = Date.now() - 20 * 60 * 1000;
  const recent = rows.filter((r) => {
    if (!r || !/comment|reply/i.test(String(r.kind || ""))) return false;
    const t = new Date(r.created_at || r.enqueued_at || r.posted_at || r.scheduled_at || 0).getTime();
    return Number.isFinite(t) && t >= since;
  });
  console.log("  直近 20 分の comment エントリ: " + recent.length + " 件（キュー全体 " + rows.length + " 行）");
  for (const r of recent.slice(0, 8)) {
    console.log("    id=" + String(r.id || "-").slice(0, 34) +
                " status=" + String(r.status || "-") +
                " x_tweet_id=" + String(r.x_tweet_id || r.tweet_id || "**まだ無い**"));
    const t = String(r.text || r.body || "").replace(/\s+/g, " ").slice(0, 100);
    if (t) console.log("      文: " + t);
  }
  if (!recent.length) console.log("  **0 件。** 候補が無かったか、まだ生成まで届いていない");
' "$W/data/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 / §5 の出方 | 意味 |"
echo "| --- | --- |"
echo "| runs が増え、§5 に \`x_tweet_id\` が在る | **再開して、実際にコメントが出た** |"
echo "| runs が増えたが §5 が 0 件 | **走ったが候補が無かった。** \`MIN_LIKES=2\` / \`MAX_AGE_HOURS=18\` の条件次第 |"
echo "| runs が増えない | **kickstart が効いていない。** \`rc=0\` を信じない |"
echo "| §4 に \`text-mismatch\` | **守りが働いた。** 打たずに止めたので成功 |"
echo
echo "**この 1 回の費用: 最大 \$0.025／回・\$0.025／日・\$0.025／月**（1 回しか走らない）。"
echo "**常駐ぶんは別で、実測 \$0.081／日・約 \$2.43／月。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '本当に走ったか' "$OUT" 2>/dev/null; then
  echo "comment-warmup をいま 1 回 撃った / $(basename "$OUT")"
else
  echo "**撃てていない。レポートを確認すること** / $(basename "$OUT")"
fi
