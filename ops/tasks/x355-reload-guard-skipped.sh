#!/bin/bash
# **x352 で「動いている最中」だったため読み込み直せなかったジョブに、関所（NODE_OPTIONS）を効かせる（x355）。$0。**
# 対象は X に触る reply-followers-cleanup（夜中に外す）。動いている最中ならまた触らない。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x355-reload-guard.md"
UIDN=$(id -u)
{
echo "# 関所の読み込み直し（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
for L in ai.openclaw.reply-followers-cleanup; do
  P="$HOME/Library/LaunchAgents/$L.plist"
  st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^[[:space:]]*state = ' | awk '{print $3}')
  if [ "$st" = "running" ]; then echo "$L: まだ動いている。触らない"; continue; fi
  launchctl bootout "gui/$UIDN/$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1
  launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -q 'x-action-guard.cjs' && echo "$L: 関所あり" || echo "$L: **関所が出ない**"
done
echo '```'
} > "$OUT" 2>&1
echo "x355 / $(basename "$OUT")"
