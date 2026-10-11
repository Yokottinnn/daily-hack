#!/bin/bash
# **t265 の報告（asp-probe/rakutenws.md）に出てしまった会員名の行を消す（t266）。** $0。
# 公開ブランチなので、過去の版には残る。いまの版から消す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
F="$RDIR/asp-probe/rakutenws.md"
OUT="$RDIR/t266-scrub-rakutenws-report.md"
if [ -f "$F" ]; then
  before=$(wc -l < "$F")
  /usr/bin/awk '!/Welcome|ようこそ/' "$F" > "$RDIR/asp-probe/.rakutenws-clean.md" && mv "$RDIR/asp-probe/.rakutenws-clean.md" "$F"
  after=$(wc -l < "$F")
  left=$(grep -c 'Welcome' "$F" | head -1)
  echo "rakutenws.md: $before 行 → $after 行（Welcome の行の残り: $left）" > "$OUT"
else
  echo "rakutenws.md が無い" > "$OUT"
fi
cat "$OUT"
