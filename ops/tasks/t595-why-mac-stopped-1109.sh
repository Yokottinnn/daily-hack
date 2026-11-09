#!/bin/bash
# t595（2026-11-10・blog3・読むだけ・$0）: Mac の heartbeat が 11/9 02:54 から 23:59 JST まで 21 時間止まった理由を読む。
# 分かっていること: 02:54 の heartbeat が最後で、23:59 に再開した（その時点のジョブは 28 本 → 00:22 に 80 本）。
# 利用者がダイアログで「Mac が止まった原因も調べる」を選んだ。**何も書き換えない・載せ直さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t595-why-mac-stopped-1109.md"
TMPD="$W/.t595"; mkdir -p "$TMPD"
# 素の bash で打ち切る（macOS に timeout は無い・最上位ルール 14）
limited() { local lim="$1" outf="$2"; shift 2; "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$lim" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w+1)); done
  if kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null; echo "（${lim} 秒で打ち切った）" >> "$outf"; fi; wait "$pid" 2>/dev/null; }
{
echo "# Mac が 11/9 02:54〜23:59 に止まった理由（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. 起動した時刻・再起動・ログイン"; echo '```'
echo "boottime: $(sysctl -n kern.boottime 2>/dev/null)"
last -15 2>/dev/null | grep -E 'reboot|shutdown|console' | head -10
echo '```'
echo; echo "## 2. スリープ・復帰・電源断（11/9 02:00〜11/10 00:30）"; echo '```'
pmset -g log 2>/dev/null | grep -E '^2026-11-(09|10) ' | grep -E ' (Sleep|Wake|DarkWake|Shutdown|Restart|Start|Failure) ' | awk '$1=="2026-11-09" && $2>="02:00" || $1=="2026-11-10" && $2<="00:30"' | cut -c1-160 | head -40
echo '```'
echo; echo "## 3. 前回の電源断の理由（shutdown cause）"; echo '```'
limited 120 "$TMPD/sd.txt" /usr/bin/log show --style compact --start "2026-11-09 02:30:00" --end "2026-11-10 00:10:00" --predicate 'eventMessage CONTAINS "Previous shutdown cause" OR eventMessage CONTAINS "kernel panic" OR eventMessage CONTAINS "Shutdown cause"'
grep -v '^Timestamp' "$TMPD/sd.txt" | cut -c1-200 | tail -10
echo '```'
echo; echo "## 4. パニック・電源の記録ファイル（11/9 のもの）"; echo '```'
ls -la /Library/Logs/DiagnosticReports/ 2>/dev/null | grep -E 'Nov  9|Nov 10' | grep -iE 'panic|shutdown|sleep|power' | head -10
echo "（無ければ空）"
echo '```'
echo; echo "## 5. 電源の設定（自動スリープ・停電後の再起動）"; echo '```'
pmset -g 2>/dev/null | grep -E 'sleep|autorestart|womp|powernap|standby' | head -12
pmset -g batt 2>/dev/null | head -3
echo '```'
rm -rf "$TMPD"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
