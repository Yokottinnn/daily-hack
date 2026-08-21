#!/bin/bash
# SEO の定期ジョブ 2 つを launchd に戻す。
#
# CLAUDE.md には定期ジョブと書いてあるが、8/19 時点で launchctl list に無い。
# 検索流入に直接効くため、動いている前提が崩れたままにしない。
set -uo pipefail

ok=0; ng=0; msg=""
for LABEL in ai.openclaw.sitemap-autosubmit ai.openclaw.seo-health; do
  short="${LABEL##*.}"
  if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    msg="$msg ${short}=既に稼働"; ok=$((ok+1)); continue
  fi
  PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
  if [ ! -f "$PLIST" ]; then
    msg="$msg ${short}=plist無し"; ng=$((ng+1)); continue
  fi
  launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1
  sleep 3
  if launchctl list 2>/dev/null | grep -q "$LABEL"; then
    msg="$msg ${short}=ロード成功"; ok=$((ok+1))
  else
    msg="$msg ${short}=定着せず"; ng=$((ng+1))
  fi
done

echo "ok=${ok} ng=${ng}:${msg}"
[ "$ng" -eq 0 ]
