#!/bin/bash
# フォロー返し（badge-followback）を launchd に戻す。
#
# plist はあるのに launchctl に載っておらず、ログは 2026-08-09 で止まっている。
# その間フォロワーは 12 日間で +1（206→207）。内訳は disappeared=15 / new=16 で、
# **流入と同じだけ流出している。** フォローしてくれた相手に返せていないことが
# 原因である可能性が高い。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

LABEL="ai.openclaw.badge-followback"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
W="$HOME/.openclaw/workspace"

if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "既に稼働している"
  exit 0
fi

if [ ! -f "$PLIST" ]; then
  echo "plist が無い: $(ls "$HOME/Library/LaunchAgents" 2>/dev/null | grep -i followback | head -3 | tr '\n' ' ')"
  exit 1
fi

# **実行間隔を先に確認する。** 過剰に速いと X から自動化と見なされる
interval="$(plutil -extract StartInterval raw "$PLIST" 2>/dev/null || echo '不明')"
cal="$(plutil -extract StartCalendarInterval raw "$PLIST" 2>/dev/null | head -1 || echo '')"

launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>&1 | head -2
sleep 5

if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "ロード成功 / StartInterval=${interval} ${cal:+StartCalendarInterval あり}"
else
  echo "bootstrap したが定着しなかった / StartInterval=${interval}"
  exit 1
fi
