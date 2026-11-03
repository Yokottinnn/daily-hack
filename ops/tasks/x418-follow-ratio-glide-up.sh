#!/bin/bash
# x418（2026-11-04・$0）: 利用者が「認証済みは守り、目標を上げる」を選んだ。
# 認証済みの相互（約 384 件）だけで比率 0.56 になり、目標 0.426 に届かない（x406・x417）。
# follow-balance の比率の目標（FOLLOW_RATIO_GLIDE）を 500:0.62,700:0.60,1000:0.55,1500:0.50 に変える。
# 認証済みへのフォロー返し・外す条件・間隔は変えない。走らせない（次の定時から効く）。LLM を呼ばない（$0）。
set -uo pipefail
P="$HOME/Library/LaunchAgents/ai.openclaw.follow-balance.plist"; L="gui/$(id -u)/ai.openclaw.follow-balance"
OUT="${OPS_REPORT_DIR:-/tmp}/x418-follow-ratio-glide-up.md"
NEW="500:0.62,700:0.60,1000:0.55,1500:0.50"
{
echo "# 比率の目標を引き上げる（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo '```'
echo "前: $(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:FOLLOW_RATIO_GLIDE' "$P" 2>&1)"
cp "$P" "$P.bak-x418"
/usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:FOLLOW_RATIO_GLIDE $NEW" "$P" 2>&1
echo "後: $(/usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:FOLLOW_RATIO_GLIDE' "$P" 2>&1)"
st="$(launchctl print "$L" 2>/dev/null | grep -E '^\s*state = ' | head -1 | sed -E 's/.*state = //')"
echo "いまの状態: $st"
if [ "$st" = "running" ]; then echo "走っている最中なので載せ直さない（終わったあと次の定時に、新しい値で載せ直すまで旧い値のまま）。次の heartbeat で x418b を出す"; else
  launchctl bootout "$L" 2>/dev/null; launchctl bootstrap "gui/$(id -u)" "$P" 2>&1; echo "bootstrap rc=$?"
fi
launchctl print "$L" >/dev/null 2>&1 && echo "**載っている**" || echo "**載っていない**"
launchctl print "$L" 2>/dev/null | grep -A1 'FOLLOW_RATIO_GLIDE' | head -2
echo '```'
echo "**LLM を呼ばない（1 回 \$0・1 日 \$0・1 か月 \$0）。認証済みへのフォロー返し・外す条件・間隔は変えていない。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
