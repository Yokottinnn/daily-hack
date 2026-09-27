#!/bin/bash
# **`x173` で撃った発火の「結果」を取る。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `x173` は `runs 0 → 1` を見て「走った」と書いたが、**それは起動した合図であって
# 終わった合図ではない。** 待ちループが `runs` の変化で抜けたため **0 秒で抜け**、
# **走り始めた瞬間のキューを見てしまった**（`直近 20 分の comment エントリ: 0 件`）。
#
# orchestrator は試走で **16:00:55 → 16:03:56 と約 3 分** かかっている。
# **結果は後から見ないと分からない。**
#
# ### 次から間違えないための書き方
#
#   誤: `runs` が変わったら抜ける          → **起動を見ている**
#   正: **ログの終了行**が出るまで待つ、または**別のタスクで後から読む**
#
# ## 何を出すか
#
#   ① `comment-orchestrator.log` の**今日ぶんの発火をすべて**（start と結果の対応）
#   ② **キューの直近 2 時間** の comment エントリ（**一次情報**・最上位ルール 11）
#   ③ ジョブがまだ載っているか（`launchctl print`）
#   ④ 守りが働いた形跡（`text-mismatch` など。**働いたなら成功**）
#
# ## やらないこと
#
# **撃たない。設定を変えない。投稿もしない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-outcome.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
ME="heng_ji31590"
# **自分の投稿 URL は伏せない。** 確認してもらう対象そのもの
clean() { hide | sed -E "s#@<伏せ>/status#@$ME/status#g"; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# 撃った発火の結果（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 撃っていない。設定も触っていない。"
echo "> \`x173\` は \`runs\` の変化で抜けたため、**走り始めた瞬間を見ていた。** ここで取り直す。"

echo
echo "## 1. 今日の発火（**start と結果を対応させる**）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
OLOG="$L/comment-orchestrator.log"
if [ ! -f "$OLOG" ]; then
  echo "  **comment-orchestrator.log が無い**"
else
  printf '  更新 %s / %s bytes\n\n' "$(stat -f '%Sm' -t '%H:%M:%S' "$OLOG" 2>/dev/null)" "$(wc -c < "$OLOG" | tr -d ' ')"
  echo "  --- 今日の start と picked ---"
  grep -E "^\[$TODAY" "$OLOG" 2>/dev/null \
    | grep -E 'orchestrator start|picked |enqueue|posted|skip|no candidates|候補' \
    | tail -30 | cut -c1-200 | clean | sed 's/^/    /'
  echo
  echo "  --- 今日の末尾 25 行（そのまま）---"
  grep -E "^\[$TODAY" "$OLOG" 2>/dev/null | tail -25 | cut -c1-200 | clean | sed 's/^/    /'
fi
echo '```'

echo
echo "## 2. キューの直近 2 時間（**一次情報**）"
echo
echo "**ログではなくキューを見る。** \`x_tweet_id\` が在れば出ている。"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **post_queue.json が読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const since = Date.now() - 120 * 60 * 1000;
  const pick = [];
  for (const r of rows) {
    if (!r || !/comment|reply/i.test(String(r.kind || ""))) continue;
    const ts = [r.posted_at, r.created_at, r.enqueued_at, r.scheduled_at]
      .map((x) => new Date(x || 0).getTime()).filter((t) => Number.isFinite(t) && t > 0);
    const t = ts.length ? Math.max(...ts) : 0;
    if (t >= since) pick.push({ r, t });
  }
  pick.sort((a, b) => a.t - b.t);
  console.log("  直近 2 時間の comment エントリ: " + pick.length + " 件（キュー全体 " + rows.length + " 行）");
  const jst = (t) => new Date(t + 9 * 3600 * 1000).toISOString().slice(11, 19);
  let posted = 0;
  for (const { r, t } of pick) {
    const tid = r.x_tweet_id || r.tweet_id;
    if (tid) posted++;
    console.log("    " + jst(t) + "  id=" + String(r.id || "-").slice(0, 30) +
                "  status=" + String(r.status || "-"));
    console.log("      " + (tid ? "**出た**: https://x.com/heng_ji31590/status/" + tid : "**tweet_id が無い**"));
    const tx = String(r.text || r.body || "").replace(/\s+/g, " ").slice(0, 110);
    if (tx) console.log("      文: " + tx);
  }
  console.log("");
  console.log("  → **出たもの " + posted + " 件 / 積まれたもの " + pick.length + " 件**");
  if (!pick.length) console.log("  → **0 件。** 候補が無かったか、まだ届いていない");
' "$W/data/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "## 3. ジョブはまだ載っているか"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|path|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない。外れた**"
fi
echo '```'

echo
echo "## 4. 守りが働いた形跡（**働いたなら成功**）"
echo
echo '```'
for n in comment-orchestrator comment-warmup; do
  f="$L/$n.log"
  [ -f "$f" ] || { printf '  %-24s ログが無い\n' "$n"; continue; }
  printf '  %-24s wrong-page %s / no-focus %s / text-mismatch %s / x154 %s\n' \
    "$n" "$(cnt 'wrong-page' "$f")" "$(cnt 'no-focus' "$f")" \
    "$(cnt 'text-mismatch' "$f")" "$(cnt '\[x154\]' "$f")"
done
echo '```'
echo
echo "**\`text-mismatch\` が出ていたら、それは打たずに止めた成功。** 中身を見る。"

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §2 の出方 | 意味 |"
echo "| --- | --- |"
echo "| **出たもの 1 件 以上** | **再開して、実際にコメントが出た。** URL を報告する |"
echo "| 積まれたが tweet_id が無い | **積んで出ていない。** publisher 側を見る |"
echo "| **0 件** ／ §1 に \`no candidates\` | **走ったが候補が無かった。** \`MIN_LIKES=2\` / \`MAX_AGE_HOURS=18\` の条件次第。故障ではない |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'キューの直近 2 時間' "$OUT" 2>/dev/null; then
  echo "撃った発火の結果を取った / $(basename "$OUT")"
else
  echo "**取れていない。レポートを確認すること** / $(basename "$OUT")"
fi
