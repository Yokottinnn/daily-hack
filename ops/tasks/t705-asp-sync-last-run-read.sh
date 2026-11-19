#!/bin/bash
# **asp-sync の今朝の 1 回で何が出たかを読む（t705・読むだけ・$0）。**
# t704 で分かったこと: ジョブは毎朝 6:12 に起動して exit 0（runs=9）。だが reports/asp-sync/ の 5 ファイルは
# ops/heartbeat の 11/14 の版と同じ大きさで、時刻だけ 06:32（heartbeat の書き戻し）。11/15 以降、書き出していないか、
# 書いたものが push 前に消えている。最後の起動の後ろの行（ログの末尾）を伏せて出し、どちらかを分ける。
#
# 費用: 1 回 $0・1 日 $0・1 か月 $0（LLM を呼ばない）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t705-asp-sync-last-run-read.md"
mkdir -p "$RDIR"
LOG="$HOME/.openclaw/logs/asp-sync.log"
WT="$HOME/.openclaw/ops-heartbeat-wt"
mask() { sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<メール>/g; s/[^ 　「」]{1,12}様/<名前>様/g' | cut -c1-200; }

{
  echo "# asp-sync の今朝の 1 回（t705・読むだけ・\$0）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) ログの最後の起動から後ろ（伏せ字・各行 200 字まで）"
  echo ""
  echo '```'
  if [ -f "$LOG" ]; then
    n=$(grep -n '^=== ' "$LOG" | tail -2 | head -1 | cut -d: -f1)
    case "$n" in ''|*[!0-9]*) n=1 ;; esac
    tail -n +"$n" "$LOG" | head -40 | mask
  else
    echo "ログが無い"
  fi
  echo '```'
  echo ""
  for f in asp-sync.out.log asp-sync.err.log; do
    p="$HOME/.openclaw/logs/$f"
    echo "## $f"
    echo ""
    if [ -f "$p" ]; then
      echo "大きさ $(wc -c < "$p" | tr -d ' ') bytes／最終更新 $(stat -f '%Sm' "$p" 2>/dev/null)"
      echo '```'; tail -15 "$p" | mask; echo '```'
    else
      echo "無い"
    fi
    echo ""
  done
  echo "## 2) 書き出し先の決め方"
  echo ""
  echo "- launchd の環境に OPS_REPORT_DIR: $(launchctl print "gui/$(id -u)/com.dailyhack.asp-sync" 2>/dev/null | grep -c OPS_REPORT_DIR | head -1) 行"
  echo "- 既定の書き出し先: \`$WT/reports/asp-sync\`"
  echo ""
  echo '```'
  ls -la --time-style=full-iso "$WT/reports/asp-sync" 2>/dev/null || ls -laT "$WT/reports/asp-sync" 2>&1 | head -10
  echo '```'
  echo ""
  echo "## 3) /tmp などに別の asp-sync の出力が無いか（ファイル名と時刻だけ）"
  echo ""
  echo '```'
  find /tmp "${TMPDIR:-/tmp}" "$HOME/.openclaw" -maxdepth 4 -type d -name asp-sync 2>/dev/null | head -10 | while read -r d; do echo "$d"; ls -la "$d" 2>/dev/null | grep status.json; done
  echo '```'
} > "$OUT" 2>&1

cat "$OUT"
exit 0
