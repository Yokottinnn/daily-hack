#!/bin/bash
# **アンフォローの 2 本を 1 日 3 回にする（利用者の選択「外すペースを上げる」・2026-10-14）。費用 $0。**
#
#   follow-balance（片思い・1 回 20 件）: 11:45 / 18:45 ＋ **15:15**
#   mutual-prune（釣り合いの悪い相互・1 回 15 件）: 06:00 / 18:00 ＋ **12:30**
#   フォロー側（hashtag 10:15/17:00・competitor 11:30/18:30）と重ならない時刻を選んだ。
#   どちらも DOM 操作だけで LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-3x-daily.md"
add_time() {  # $1=label $2=hour $3=minute
  local L="$1" P="$HOME/Library/LaunchAgents/ai.openclaw.$1.plist"
  cp "$P" "$P.bak-x293"
  if plutil -extract StartCalendarInterval json -o - "$P" 2>/dev/null | grep -q "\"Hour\":$2,\"Minute\":$3\|\"Minute\":$3,\"Hour\":$2"; then echo "- $L: $2:$3 はもう在る"; return; fi
  local n; n="$(plutil -extract StartCalendarInterval json -o - "$P" | node -e 'console.log(JSON.parse(require("fs").readFileSync(0,"utf8")).length)')"
  /usr/libexec/PlistBuddy -c "Add :StartCalendarInterval:$n dict" -c "Add :StartCalendarInterval:$n:Hour integer $2" -c "Add :StartCalendarInterval:$n:Minute integer $3" "$P"
  launchctl bootout "gui/$(id -u)/ai.openclaw.$L" >/dev/null 2>&1; sleep 2
  launchctl bootstrap "gui/$(id -u)" "$P" 2>&1 | head -1
  echo "- $L: 定時 $(plutil -extract StartCalendarInterval json -o - "$P")"
  launchctl print "gui/$(id -u)/ai.openclaw.$L" 2>&1 | grep -m1 "state =" | tr -d '\t'
}
{
echo "# アンフォローを 1 日 3 回に（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
if pgrep -f "mutual-prune.js" >/dev/null 2>&1; then echo "**mutual-prune が走っているので、mutual-prune の載せ直しは次のタスクに回す**"; else add_time mutual-prune 12 30; fi
add_time follow-balance 15 15
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 戻すときは plist の .bak-x293。"
} > "$OUT" 2>&1
echo "アンフォローを 1 日 3 回にした / $(basename "$OUT")"
