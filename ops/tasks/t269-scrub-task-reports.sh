#!/bin/bash
# **t261 / t265 のタスク報告（本文の写し）にも残っていた会社名・会員名の行を消す（t269）。** $0。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t269-scrub-task-reports.md"
: > "$OUT"
for n in t261-vc-adlist t265-rakuten-ws-dump; do
  F="$RDIR/$n.md"
  [ -f "$F" ] || { echo "$n.md が無い" >> "$OUT"; continue; }
  before=$(wc -l < "$F")
  /usr/bin/awk '!/合同会社|Welcome|ようこそ|value=[0-9][0-9][0-9][0-9][0-9]/' "$F" > "$RDIR/.scrub-$n.md" && mv "$RDIR/.scrub-$n.md" "$F"
  echo "$n.md: $before 行 → $(wc -l < "$F") 行" >> "$OUT"
done
cat "$OUT"
