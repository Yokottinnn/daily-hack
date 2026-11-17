#!/bin/bash
# **ASP 4 社の提携状況（com.dailyhack.asp-sync・毎日 6:12）が 11/14 19:54 の読み取りのまま止まっている理由を読む（t704・読むだけ）。**
# 作戦室の毎日の更新（2026-11-18）で、reports/asp-sync/status.json の generated が 4 日前のままだった。
# ジョブは heartbeat の一覧には載っている。走っているのか・走って失敗しているのか・書いたのに push されていないのかを分ける。
#
# 費用: 1 回 $0・1 日 $0・1 か月 $0（LLM を呼ばない。1 回だけ読む）
#
# **ログの本文はそのまま出さない**（ログインが要るページの文字が混ざりうる）。出すのは
# 起動の行（=== …）と、エラーらしい行の先頭 160 字だけ。メールアドレスと「様」の前は伏せる。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t704-asp-sync-stale-diag.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.asp-sync"
LOG="$HOME/.openclaw/logs/asp-sync.log"
WTR="$HOME/.openclaw/ops-heartbeat-wt/reports/asp-sync"

mask() { sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/<メール>/g; s/[^ 　「」]{1,12}様/<名前>様/g' | cut -c1-160; }

{
  echo "# ASP の同期が止まっている理由（t704・読むだけ・\$0）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "## 1) launchd の状態（launchctl print）"
  echo ""
  echo '```'
  launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E 'state =|runs =|last exit code|path =|program =|Hour|Minute|Weekday|=> ' | head -30
  echo '```'
  echo ""
  echo "## 2) plist の時刻"
  echo ""
  P="$HOME/Library/LaunchAgents/$LABEL.plist"
  if [ -f "$P" ]; then
    echo '```'
    plutil -extract StartCalendarInterval json -o - "$P" 2>&1 | head -5
    echo '```'
  else
    echo "plist が無い: \`$P\`（.disabled か確かめる）"
    ls -la "$HOME/Library/LaunchAgents/" 2>/dev/null | grep -i asp-sync
  fi
  echo ""
  echo "## 3) ログ（起動の行とエラーらしい行だけ・最後の 60 行の範囲）"
  echo ""
  if [ -f "$LOG" ]; then
    echo "ログの大きさ: $(wc -c < "$LOG" | tr -d ' ') bytes／最終更新: $(stat -f '%Sm' "$LOG" 2>/dev/null)"
    echo ""
    echo '```'
    grep -n -E '^=== |rror|失敗|時間切れ|imeout|ECONN|refused|exit|Killed|abort|取り出せ|本体' "$LOG" | tail -60 | mask
    echo '```'
  else
    echo "ログが無い: \`$LOG\`"
  fi
  echo ""
  echo "## 4) 書き出し先のファイルの時刻（push 前の作業場所）"
  echo ""
  echo '```'
  ls -la "$WTR" 2>&1 | head -20
  echo '```'
  echo ""
  echo "## 5) シム"
  echo ""
  B="$HOME/.openclaw/bin/asp-sync-boot.sh"
  if [ -x "$B" ]; then echo "在る（実行可）: \`$B\`"; else echo "無い／実行できない: \`$B\`"; fi
} > "$OUT" 2>&1

cat "$OUT"
exit 0
