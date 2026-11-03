#!/bin/bash
# x409（2026-11-03・$0）: x408 の「走っているか」の判定が "not running" を走っていると読み、走らせていなかった。いま 1 回走らせる。
set -uo pipefail
L="gui/$(id -u)/ai.openclaw.follow-balance"
OUT="${OPS_REPORT_DIR:-/tmp}/x409-kickstart-follow-balance.md"
{
echo "# follow-balance をいま走らせる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
st="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*state = ' | head -1 | sed -E 's/.*state = //')"
echo "いまの状態: $st"
if [ "$st" = "running" ]; then echo "走っている（重ねない）"; else launchctl kickstart "$L" 2>&1; echo "kickstart rc=$?"; fi
sleep 5
launchctl print "$L" 2>/dev/null | grep -E '^\s*(state|runs|last exit code) =' | head -3 | tr -s ' \n' ' '; echo
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
