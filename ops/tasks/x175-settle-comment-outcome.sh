#!/bin/bash
# **コメントが出たかを、落ち着いてから確定させる。読むだけ。費用 $0。**
#
# ## なぜ 3 本目になったか
#
# **同じ間違いを 2 回 した。「走行中のスナップショットを結果として読んだ」。**
#
#   `x173`  `runs` の変化で待ちを抜けた → **起動直後**のキューを見た（0 件）
#   `x174`  待たずに読んだ            → **picked の 2 秒後**を見た（`pending` 1 件）
#
# どちらも「まだ終わっていない時点」を見ている。**今回は終わるまで待つ。**
#
# ## 終わったことの条件（**これを待つ**）
#
#   直近 2 時間の comment エントリに **`pending` が 1 件も無い**
#   （comment は承認不要で即時投稿される。`pending` は投稿待ちの印）
#
# 最大 210 秒 待つ。**`timeout` は使わない**（Mac に無い・最上位ルール 14）。
# **待っても残るなら「残った」と書く。** 推測で「出たはず」と書かない（最上位ルール 11）。
#
# ## やらないこと
#
# **撃たない。設定を変えない。投稿もしない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
L="$W/logs"
Q="$W/data/post_queue.json"
UID_N="$(id -u)"
LABEL="ai.openclaw.comment-warmup"
OUT="${OPS_REPORT_DIR:-/tmp}/comment-settled.md"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide | sed -E "s#@<伏せ>/status#@$ME/status#g"; }

# 直近 2 時間の comment エントリのうち pending の数を返す
pending_n() {
  node -e '
    const fs = require("fs");
    // **`node -e` のトップレベルで `return` は使えない**（Illegal return statement）。
    // 使うと毎回 構文エラーになり、数えられないまま待ち続ける
    let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
    catch (e) { process.stdout.write("-1"); process.exit(0); }
    const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
    if (!Array.isArray(rows)) { process.stdout.write("-1"); process.exit(0); }
    const since = Date.now() - 120 * 60 * 1000;
    let n = 0;
    for (const r of rows) {
      if (!r || !/comment|reply/i.test(String(r.kind || ""))) continue;
      const ts = [r.posted_at, r.created_at, r.enqueued_at, r.scheduled_at]
        .map((x) => new Date(x || 0).getTime()).filter((t) => Number.isFinite(t) && t > 0);
      const t = ts.length ? Math.max(...ts) : 0;
      if (t < since) continue;
      if (/^(pending|queued|publishing|awaiting_publish)$/i.test(String(r.status || ""))) n++;
    }
    process.stdout.write(String(n));
  ' "$Q" 2>/dev/null
}

{
echo "# コメントが出たか（確定・$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 撃っていない。**\`pending\` が無くなるまで待ってから読む。**"

echo
echo "## 1. 落ち着くまで待つ"
echo
echo '```'
WT=0
P="$(pending_n)"; [ -n "$P" ] || P=-1
printf '  はじめの pending: %s 件\n' "$P"
while [ "$WT" -lt 210 ]; do
  P="$(pending_n)"; [ -n "$P" ] || P=-1
  [ "$P" = "0" ] && break
  [ "$P" = "-1" ] && break
  sleep 10
  WT=$((WT + 10))
done
P="$(pending_n)"; [ -n "$P" ] || P=-1
printf '  待った秒数: %s\n' "$WT"
printf '  いまの pending: %s 件 %s\n' "$P" \
  "$( [ "$P" = "0" ] && echo '← **落ち着いた**' || echo '← **まだ残っている**' )"
[ "$P" = "-1" ] && echo "  **キューが読めない**"
echo '```'

echo
echo "## 2. 出たもの（**一次情報：キューの \`x_tweet_id\`**）"
echo
echo '```json'
node -e '
  const fs = require("fs");
  let j; try { j = JSON.parse(fs.readFileSync(process.argv[1], "utf8")); }
  catch (e) { console.log("  **読めない: " + e.message + "**"); process.exit(0); }
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
  const jst = (t) => new Date(t + 9 * 3600 * 1000).toISOString().slice(11, 19);
  let posted = 0, stuck = 0;
  console.log("  直近 2 時間の comment エントリ: " + pick.length + " 件（キュー全体 " + rows.length + " 行）");
  console.log("");
  for (const { r, t } of pick) {
    const tid = r.x_tweet_id || r.tweet_id;
    if (tid) posted++; else stuck++;
    console.log("  " + jst(t) + "  status=" + String(r.status || "-") +
                "  id=" + String(r.id || "-").slice(0, 30));
    console.log("    " + (tid ? "**出た**: https://x.com/heng_ji31590/status/" + tid
                              : "**tweet_id が無い**"));
    const tx = String(r.text || r.body || "").replace(/\s+/g, " ").slice(0, 120);
    if (tx) console.log("    文: " + tx);
    console.log("");
  }
  console.log("  → **出た " + posted + " 件 / 出ていない " + stuck + " 件**");
' "$Q" 2>&1 | clean
echo '```'

echo
echo "## 3. 今日の発火の一覧（**picked と出た数が合うか**）"
echo
echo '```'
TODAY="$(date '+%Y-%m-%d')"
OLOG="$L/comment-orchestrator.log"
if [ -f "$OLOG" ]; then
  grep -E "^\[$TODAY" "$OLOG" 2>/dev/null | grep -E 'orchestrator start|picked ' \
    | sort -u | cut -c1-160 | clean | sed 's/^/  /'
else
  echo "  comment-orchestrator.log が無い"
fi
echo '```'
echo
echo "**\`picked N\` と §2 の件数がずれていたら、そこに落ちている分が在る。**"

echo
echo "## 4. ジョブと次の発火"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null \
    | grep -E '^[[:space:]]+(state|runs|last exit code) ' | sed 's/^/    /'
  echo "    → **載っている**"
else
  echo "    → **載っていない**"
fi
echo
echo "  発火: 12:00 / 16:00 / 19:00 / 22:00"
printf '  いま: %s JST\n' "$(date '+%H:%M')"
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §1・§2 の出方 | 意味 |"
echo "| --- | --- |"
echo "| \`pending 0\` ＋ **出た が 1 件 以上** | **コメントは出ている。** URL を報告する |"
echo "| \`pending\` が残ったまま 210 秒 | **投稿側で止まっている。** publisher を見る |"
echo "| 出た 0 件 ／ §3 に \`from 0 candidates\` | **候補が無かっただけ。** 故障ではない |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '落ち着くまで待つ' "$OUT" 2>/dev/null; then
  echo "コメントが出たかを確定させた / $(basename "$OUT")"
else
  echo "**確定できていない。レポートを確認すること** / $(basename "$OUT")"
fi
