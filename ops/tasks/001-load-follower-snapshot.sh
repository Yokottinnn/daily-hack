#!/bin/bash
# follower-snapshot を launchd に戻す。
#
# フォロワー数の推移が記録されていないと、どの施策が効いたのか永久に分からない。
# 施策の効果測定の土台なので最優先で戻す。
#
# **秘密を出力しないこと。** 結果は公開リポジトリの heartbeat.json に載る。
set -uo pipefail

LABEL="ai.openclaw.follower-snapshot"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "既に稼働している"
  exit 0
fi

if [ ! -f "$PLIST" ]; then
  # plist が無いなら、名前違いの候補を挙げて終わる。**当て推量で作らない。**
  echo "plist が無い: $(ls "$HOME/Library/LaunchAgents" 2>/dev/null | grep -i follow | head -3 | tr '\n' ' ')"
  exit 1
fi

launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>&1 | head -2
sleep 5
if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  echo "ロード成功"
else
  echo "bootstrap したが定着しなかった"
  exit 1
fi
