#!/bin/bash
# **t261 の報告（asp-probe/vc2.md）に出てしまった会社名・契約 ID の行を消す（t262）。** $0。
# 公開ブランチなので、過去の版には残る。いまの版から消す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
F="$RDIR/asp-probe/vc2.md"
OUT="$RDIR/t262-scrub-vc2-report.md"
if [ -f "$F" ]; then
  before=$(wc -l < "$F")
  /usr/bin/awk '!/合同会社|有限会社|株式会社.*（[0-9]|value=[0-9][0-9][0-9][0-9][0-9]/' "$F" > "$RDIR/asp-probe/.vc2-clean.md" && mv "$RDIR/asp-probe/.vc2-clean.md" "$F"
  after=$(wc -l < "$F")
  left=$(grep -c '合同会社' "$F" | head -1)
  echo "vc2.md: $before 行 → $after 行（合同会社を含む行の残り: $left）" > "$OUT"
else
  echo "vc2.md が無い" > "$OUT"
fi
cat "$OUT"
