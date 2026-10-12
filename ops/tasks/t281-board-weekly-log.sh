#!/bin/bash
# **収益化作戦室の週次ジョブ（t280 で入れた）の初回が、reports/board/ を作っていない理由を読む（t281）。**
# 読むだけ・LLM 不使用・**$0**。公開ブランチに出るので、ログは末尾だけ・長い英数字は伏せる。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t281-board-weekly-log.md"
WT="$HOME/.openclaw/ops-heartbeat-wt"
LABEL=com.dailyhack.board-weekly
mask() { sed -E 's/[A-Za-z0-9]{24,}/[伏せ]/g'; }
{
  echo "# 週次ジョブ board-weekly の初回を調べる（t281・**\$0**）"; echo
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo
  echo "## launchctl print"; echo '```text'
  launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "state|runs|last exit|pid" | head -8
  echo '```'
  echo "## 走っているか"; echo '```text'
  ps -axo pid,etime,command | grep -E "mac-weekly|board-weekly|gsc-dump|asp-probe|asp-sync" | grep -v grep | cut -c1-160 | head -8
  echo '```'
  echo "## reports/board の中身"; echo '```text'
  ls -la "$WT/reports/board" 2>&1 | head -20
  ls -la "$WT/reports/board/asp-probe" 2>&1 | head -10
  git -C "$WT" check-ignore -v reports/board/x 2>&1 | head -3
  echo '```'
  for f in board-weekly.log board-weekly.out.log board-weekly.err.log; do
    echo "## ~/.openclaw/logs/$f（末尾 40 行）"; echo '```text'
    tail -40 "$HOME/.openclaw/logs/$f" 2>&1 | mask | cut -c1-220
    echo '```'
  done
  echo "## 作業用の一時ログ（末尾 20 行ずつ）"; echo '```text'
  for f in $(ls -t "${TMPDIR:-/tmp}"/board-weekly*/*.log "${TMPDIR:-/tmp}"/board-weekly*.log 2>/dev/null | head -4); do
    echo "--- $f"; tail -20 "$f" 2>&1 | mask | cut -c1-220
  done
  echo '```'
} > "$OUT" 2>&1
head -c 3000 "$OUT"
