#!/bin/bash
# x431（2026-11-07・読むだけ・$0）: 2026-11-06 08:01:27 UTC（JST 17:01）の tab-guard の全停止の原因を読む。
# 利用者がダイアログで「11/6 17:01 の全停止の原因を読む」を選んだ。17:00 は daily-supervisor が動く時刻。
# x430（再起動の直後は止めない）で防げる種類かを確かめる。**何も書き換えない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x431-read-1106-halt.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g; s#https?://(?!x\.com|127\.0\.0\.1|localhost)[^\s"]+#<URL>#g'; }
WIN='2026-11-06T07:(4[5-9]|5[0-9])|2026-11-06T08:0[0-9]|2026-11-06[ T]1(6:(4[5-9]|5[0-9])|7:0[0-9])'
{
echo "# 11/6 17:01 の全停止の原因（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## 1. tab-guard・ensure-chrome・daily-supervisor（07:45〜08:09 UTC）"; echo '```'
for b in tab-guard ensure-chrome daily-supervisor ensure-x-login chrome-cdp-heal chrome-restart-hook; do
  f="$L/$b.log"; [ -f "$f" ] || continue
  m="$(grep -E "$WIN" "$f" 2>/dev/null | tail -20)"
  [ -n "$m" ] && { echo "--- $b"; printf '%s\n' "$m" | cut -c1-220 | hide; }
done
echo '```'
echo; echo "## 2. 同じ時間帯に行が出たほかのログ（Chrome を使うジョブ）"; echo '```'
for f in "$L"/*.log; do
  b="$(basename "$f" .log)"; case "$b" in tab-guard|ensure-chrome|daily-supervisor|ensure-x-login) continue;; esac
  n="$(grep -cE "$WIN" "$f" 2>/dev/null | head -1)"; [ "${n:-0}" -gt 0 ] && echo "$b: $n 行（最後: $(grep -E "$WIN" "$f" | tail -1 | cut -c1-140 | hide)）"
done | head -25
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
