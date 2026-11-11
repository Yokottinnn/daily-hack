#!/bin/bash
# x469（2026-11-11・読むだけ・$0）: x463 で夕方のフォロー 2 つを 20:15・20:45 にずらした。11/11 のその回が読めたかを見る。
set -uo pipefail
L="$HOME/.openclaw/workspace/logs"; OUT="${OPS_REPORT_DIR:-/tmp}/x469-read-evening-follow-1111.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 夕方のフォロー（11/11・$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo; echo "## follow-balance（11:15 UTC 以降）"; echo '```'
grep -hE '^\[2026-11-11T1[1-2]' "$L/follow-balance.log" 2>/dev/null | awk '!s[$0]++' | grep -E 'start|フォロー中|しか読めない|=== 外した|空' | cut -c1-200 | hide
echo '```'
echo; echo "## competitor-follower-follow（11:40 UTC 以降）"; echo '```'
grep -hE '^\[2026-11-11T1[1-2]' "$L/competitor-follower-follow.log" 2>/dev/null | awk '!s[$0]++' | grep -E 'start|scraped|new targets|end:' | cut -c1-200 | hide
echo '```'
} > "$OUT" 2>&1
grep -E 'フォロー中|scraped' "$OUT" | head -2 | cut -c1-120
exit 0
