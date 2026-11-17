#!/bin/bash
# **11/17 12:00 に失敗した JAL の告知（x-blog-20261117-jal-tour・x485）を出し直す（x520）。費用 $0。**
# 利用者（2026-11-15 00:3x JST チャット）:「JALのツアーと別々の予約（宿5軒ともツアーが安い）／この投稿を17日の火曜日に予約投稿して」。今日（11/17）のうちに出す。
# 12:00 の回は、画像の説明（ALT）を入れる段で Chrome のタブが閉じられて止まった（x519: alt-text・Target page, context or browser has been closed）。何も出ていない（x_tweet_id なし・thread_results 空）ので、二重には出ない。
# x485 が置いた 1 回きりの実行役（publish-jal-tour-oneshot.sh：run-publish.sh → キューに結果を書き戻す）をそのまま走らせる。出なければ 60 秒おいてもう 1 回だけ。
POST_APPROVAL_QUOTE="この投稿を17日の火曜日に予約投稿して"
POST_APPROVAL_AT="2026-11-15 00:3x JST（チャット）"
POST_SET_KEY="blog-jal-tour-separate"
# **LLM を呼ばない（$0／回）。ハンドルと秘密は伏せる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"; L="$W/logs"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x520-retry-jal-post.md"
RUNNER="$S/publish-jal-tour-oneshot.sh"; ID="x-blog-20261117-jal-tour"
tid() { "$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);const e=rows.find(x=>x&&x.id===process.argv[2]);console.log(e?(e.x_tweet_id||""):"NOENTRY")' "$D/post_queue.json" "$ID" 2>/dev/null; }
{
echo "# JAL の告知を出し直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
[ -f "$RUNNER" ] || { echo "実行役が無い: $RUNNER"; echo '```'; exit 0; }
T="$(tid)"; echo "出し直す前の x_tweet_id: ${T:-なし}"
if [ -n "$T" ] && [ "$T" != "NOENTRY" ]; then echo "**もう出ている。出し直さない**"; echo '```'; exit 0; fi
for n in 1 2; do
  echo "--- ${n} 回目 $(date '+%H:%M:%S')"
  /bin/bash "$RUNNER"
  tail -6 "$L/publish-jal-tour-oneshot.log" | cut -c1-260 | perl -pe 's/"SkFM[^"]*"/"<本文>"/g'
  T="$(tid)"; echo "x_tweet_id: ${T:-なし}"
  [ -n "$T" ] && [ "$T" != "NOENTRY" ] && { echo "**出た: https://x.com/heng_ji31590/status/$T**"; break; }
  [ "$n" = 1 ] && sleep 60
done
echo '```'
echo; echo "**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '出た:|もう出ている|x_tweet_id: なし' "$OUT" | tail -2
exit 0
