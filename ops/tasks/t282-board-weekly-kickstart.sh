#!/bin/bash
# **収益化作戦室の週次ジョブの初回を、launchd から走らせ直す（t282）。** LLM 不使用・**$0**。
# t280 は初回を nohup で裏に回したが、タスクの子として扱われ、タスクの終了と一緒に落とされた
# （t281: boot の 1 行だけで止まり、gsc.log は空）。launchd の kickstart ならタスクの子にならない。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t282-board-weekly-kickstart.md"
LABEL=com.dailyhack.board-weekly
D="gui/$(id -u)/$LABEL"
{
  echo "# 週次ジョブ board-weekly を launchd から走らせる（t282・**\$0**）"; echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo
  echo '```text'
  launchctl kickstart "$D" 2>&1; echo "kickstart rc=$?"
  sleep 5
  launchctl print "$D" 2>&1 | grep -E "state|runs|pid|last exit" | head -6
  echo "--- board-weekly.log（末尾 5 行）"
  tail -5 "$HOME/.openclaw/logs/board-weekly.log" 2>&1 | cut -c1-200
  echo '```'
  echo
  echo "結果は 10 分ほどで \`reports/board/mac-weekly-status.json\` に出る（heartbeat が push する）。"
} > "$OUT" 2>&1
cat "$OUT"
