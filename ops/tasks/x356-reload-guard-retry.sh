#!/bin/bash
# **x355 で まだ動いていたため読み込み直せなかったジョブに、関所（NODE_OPTIONS）を効かせる（x356）。$0。**
# 対象は X に触る reply-followers-cleanup（夜中に外す）。動いている最中ならまた触らない。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x356-reload-guard.md"
UIDN=$(id -u)
{
echo "# 関所の読み込み直し（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
for L in ai.openclaw.reply-followers-cleanup; do
  P="$HOME/Library/LaunchAgents/$L.plist"
  st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^[[:space:]]*state = ' | awk '{print $3}')
  # 止まるまで最大 4 分 待つ（止めはしない。利用者「止まったら読み込み直す」）
  for k in $(seq 1 24); do [ "$st" != "running" ] && break; sleep 10; st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^[[:space:]]*state = ' | awk '{print $3}'); done
  if [ "$st" = "running" ]; then echo "$L: まだ動いている。触らない"; launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -E 'pid =|runs =|last exit'; ps -o pid,etime,command -p "$(launchctl print "gui/$UIDN/$L" 2>/dev/null | awk '/pid =/{print $3; exit}')" 2>/dev/null | cut -c1-160; continue; fi
  launchctl bootout "gui/$UIDN/$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1
  launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -q 'x-action-guard.cjs' && echo "$L: 関所あり" || echo "$L: **関所が出ない**"
done
echo '```'
} > "$OUT" 2>&1
echo "x356 / $(basename "$OUT")"
