#!/bin/bash
# t602（2026-11-10・blog3・読むだけ・$0）: Mac が 11/9 02:54 から固まった理由を読む（t595 の続き）。
# 分かっていること（t595）: 9/19 から 51 日連続稼働、11/9 02:00〜11/10 00:20 にスリープ・電源断の記録なし、
# 11/10 00:20 の再起動で shutdown_stall_2026-11-10-002000_*.shutdownStall が残った。
# 利用者がダイアログで「Mac が固まった理由をもう少し読む」を選んだ。**何も書き換えない・消さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t602-why-mac-froze-1109.md"
TMPD="$W/.t602"; mkdir -p "$TMPD"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|ghp_)[A-Za-z0-9_-]+/<伏せ>/g'; }
# 素の bash で打ち切る（macOS に timeout は無い・最上位ルール 14）
limited() { local lim="$1" outf="$2"; shift 2; "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$lim" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w+1)); done
  if kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null; sleep 2; kill -KILL "$pid" 2>/dev/null; echo "（${lim} 秒で打ち切った）" >> "$outf"; fi; wait "$pid" 2>/dev/null; }
DR=/Library/Logs/DiagnosticReports
{
echo "# Mac が 11/9 に固まった理由（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. 11/8〜11/10 の診断の記録ファイル（種類と大きさ）"; echo '```'
ls -la "$DR" 2>/dev/null | grep -E 'Nov  [89]|Nov 10' | awk '{print $5, $6, $7, $8, $9}' | head -40
ls -la "$HOME/Library/Logs/DiagnosticReports" 2>/dev/null | grep -E 'Nov  [89]|Nov 10' | awk '{print $5, $6, $7, $8, $9}' | head -20
echo '```'
echo; echo "## 2. 終了処理が止まった記録（shutdownStall）の先頭と、止まっていたプロセス"; echo '```'
F="$(ls -t "$DR"/shutdown_stall_2026-11-10* 2>/dev/null | head -1)"
if [ -n "$F" ]; then
  head -c 2500 "$F" | hide
  echo; echo "--- プロセス名の出現回数（多い順・上位 20）"
  grep -oE '"(procname|name)"[[:space:]]*:[[:space:]]*"[^"]+"' "$F" 2>/dev/null | sed -E 's/.*:[[:space:]]*"//; s/"$//' | sort | uniq -c | sort -rn | head -20
  grep -oE 'Process:[[:space:]]+[^[]+' "$F" 2>/dev/null | sort | uniq -c | sort -rn | head -20
else echo "（見つからない）"; fi
echo '```'
echo; echo "## 3. 固まる前後の macOS の記録（11/9 02:40〜03:10・エラーと警告の多いプロセス）"; echo '```'
limited 150 "$TMPD/l.txt" /usr/bin/log show --style compact --start "2026-11-09 02:40:00" --end "2026-11-09 03:10:00" --predicate 'messageType == error OR messageType == fault OR eventMessage CONTAINS[c] "memory pressure" OR eventMessage CONTAINS[c] "jetsam" OR eventMessage CONTAINS[c] "watchdog" OR eventMessage CONTAINS[c] "panic" OR eventMessage CONTAINS[c] "low swap" OR eventMessage CONTAINS[c] "disk full"'
echo "行数: $(grep -vc '^Timestamp' "$TMPD/l.txt" | head -1)"
echo "--- プロセスごとの件数（上位 15）"
grep -v '^Timestamp' "$TMPD/l.txt" | awk '{print $4}' | sed -E 's/\[.*//' | sort | uniq -c | sort -rn | head -15
echo "--- メモリ・ウォッチドッグ・ディスクの行（最後の 25 行）"
grep -iE 'memory pressure|jetsam|watchdog|panic|low swap|disk full|no space' "$TMPD/l.txt" | cut -c1-220 | hide | tail -25
echo "--- 記録の最後の 15 行（ここで止まった）"
grep -v '^Timestamp' "$TMPD/l.txt" | tail -15 | cut -c1-220 | hide
echo '```'
echo; echo "## 4. いまのメモリと空き容量（比べるため）"; echo '```'
memory_pressure 2>/dev/null | tail -3
sysctl vm.swapusage 2>/dev/null
df -h / 2>/dev/null | tail -1
echo '```'
rm -rf "$TMPD"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
