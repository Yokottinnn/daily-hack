#!/bin/bash
# **読むだけ・$0。** 押す係を本番にする前に、各ジョブが間隔の決まり（x-action-pacer）をどう呼んでいるか（待つ長さ・取れなかったときの動き）と、
# follow-handle.js・unfollow-handle.js の受け取る引数を読む（x499）。利用者がダイアログで「押す係を本番にする」を選んだ（2026-11-15）。秘密・ハンドルは出さない。
set -uo pipefail
S="$HOME/.openclaw/workspace/scripts"; OUT="${OPS_REPORT_DIR:-/tmp}/x499-read-pacer-callers.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g'; }
{
echo "# 間隔の決まりの呼ばれ方を読む（$(date '+%F %T') JST・読むだけ・\$0）"
for f in follow-handle.js unfollow-handle.js follow-balance.js mutual-prune.js badge-followback.js competitor-follower-follow.js hashtag-follow.js incoming-reply-watcher.js reply-followers-cleanup.js; do
  echo; echo "## $f（$(wc -l < "$S/$f" 2>/dev/null | tr -d ' ') 行）"; echo '```'
  grep -n -E 'x-action-pacer|waitTake|waitFree|pacer\.|process\.argv|FOLLOW_HANDLE|UNFOLLOW_SCRIPT|follow-handle|unfollow-handle|execSync|spawnSync|MAX_|GAP_MS' "$S/$f" 2>/dev/null | cut -c1-230 | clean | head -25
  echo '```'
  # pacer を呼ぶ行の前後 6 行（取れなかったときの動き）
  n="$(grep -n 'waitTake' "$S/$f" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -n "$n" ]; then echo "前後:"; echo '```'; sed -n "$((n>4?n-4:1)),$((n+8))p" "$S/$f" | cut -c1-230 | clean; echo '```'; fi
done
echo; echo "## launchd の間隔（StartInterval / StartCalendarInterval の数）"; echo '```'
for l in badge-followback comment-warmup competitor-follower-follow hashtag-follow incoming-reply-watcher follow-balance mutual-prune reply-followers-cleanup; do
  p="$HOME/Library/LaunchAgents/ai.openclaw.$l.plist"; [ -f "$p" ] || { echo "$l: plist なし"; continue; }
  iv="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$p" 2>/dev/null)"; nc="$(grep -c '<key>Hour</key>' "$p" | head -1)"
  echo "$l: StartInterval=${iv:-なし} ／ 時刻指定 ${nc} 回"
done
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "間隔の決まりの呼ばれ方を読んだ / $(basename "$OUT")"
