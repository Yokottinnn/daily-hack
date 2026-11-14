#!/bin/bash
# x478（2026-11-14・読むだけ・$0）: フォロー・解除・返信・いいねを押すスクリプトが、間隔の決まり（x-action-pacer）を通っているかを見る。
# x476 でフォローの間隔が 0 秒（badge-followback は約 10 秒おき）だった。直す前に、どこが通っていないかを読む。何も変えない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/x478-read-follow-pacer-usage.md"
{
echo "# 間隔の決まりを通っているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
for LABEL in badge-followback competitor-follower-follow comment-warmup comment-orchestrator incoming-reply-watcher hashtag-follow follow-balance mutual-prune reply-followers-cleanup; do
  P="$LA/ai.openclaw.$LABEL.plist"
  echo; echo "## $LABEL"; echo '```'
  if [ -f "$P" ]; then
    /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | tr -s ' \n' ' ' | cut -c1-200; echo
  else echo "plist なし"; fi
  for f in $(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null | grep -oE '/[^ ]+\.(js|cjs|sh)' | head -3); do
    [ -f "$f" ] || continue
    echo "--- $f（$(wc -l < "$f" | tr -d ' ') 行）"
    grep -nE 'x-action-pacer|waitTake|waitFree|follow-handle|post-comment|setTimeout|sleep|\.click\(' "$f" 2>/dev/null | head -12 | cut -c1-170
    for g in $(grep -oE '[A-Za-z0-9_-]+\.(js|cjs)' "$f" | sort -u | head -8); do
      gf="$S/$g"; [ -f "$gf" ] || continue
      n="$(grep -cE 'x-action-pacer|waitTake|waitFree' "$gf" | head -1)"; echo "    呼んでいる $g: pacer の行 ${n:-0}"
    done
  done
  echo '```'
done
} > "$OUT" 2>&1
grep -cE 'pacer の行 0' "$OUT" | head -1
exit 0
