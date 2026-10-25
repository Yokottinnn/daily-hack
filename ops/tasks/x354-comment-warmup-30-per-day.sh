#!/bin/bash
# **返信を 1 日 30 件にする（x354）。起動 4 回 → 6 回（8・10・12・16・19・22 時）、1 回 6 件 → 5 件。**
# 利用者（2026-10-26）が費用を見たうえで「30 件にする」を選んだ。推定 1 日 約 $0.101・1 か月 約 $3.04（いま 約 $2.43 から +$0.61・Haiku）。
# 返信の間隔は x352 の関所（60 秒・30 分 12 回）が守る。1 回 5 件なので 30 分 12 回に収まる。LLM はこのタスクでは呼ばない（$0）。
set -uo pipefail
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
L=ai.openclaw.comment-warmup
OUT="${OPS_REPORT_DIR:-/tmp}/x354-comment-warmup-30.md"
PB=/usr/libexec/PlistBuddy
UIDN=$(id -u)
{
echo "# 返信を 1 日 30 件に（$(date '+%Y-%m-%d %H:%M:%S') JST）"
echo '```'
st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^\s*state = ' | awk '{print $3}')
if [ "$st" = "running" ]; then echo "動いている最中なので触らない。次の周回で x355 を出す"; else
cp -p "$P" "$P.bak-x354"
$PB -c "Delete :StartCalendarInterval" "$P"
$PB -c "Add :StartCalendarInterval array" "$P"
i=0; for h in 8 10 12 16 19 22; do
  $PB -c "Add :StartCalendarInterval:$i dict" "$P"
  $PB -c "Add :StartCalendarInterval:$i:Hour integer $h" "$P"
  $PB -c "Add :StartCalendarInterval:$i:Minute integer 0" "$P"
  i=$((i+1)); done
$PB -c "Set :EnvironmentVariables:MAX_PICKS_PER_FIRE 5" "$P"
plutil -lint "$P"
launchctl bootout "gui/$UIDN/$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>&1
launchctl print "gui/$UIDN/$L" 2>&1 | grep -E 'state =|MAX_PICKS|NODE_OPTIONS|Hour|Minute' | head -20
plutil -p "$P" | grep -E 'MAX_PICKS|Hour'
fi
echo '```'
} > "$OUT" 2>&1
echo "x354 / $(basename "$OUT")"
