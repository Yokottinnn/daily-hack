#!/bin/bash
# **月次のアクセス分析の元データを取る**（ops/tasks から呼ぶ）。読むだけ・LLM 不使用・$0。
#
#   bash run-gsc-dump.sh 2026-10
#
# main の scripts/gsc-dump.py と weekly-blog-report.py を取り出して走らせ、
# $OPS_REPORT_DIR/gsc-monthly-<YYYY-MM>.json に書く（ops/heartbeat に push される）。
# macOS で使えない構文（timeout / sed -i / date -d / stat -c）は使わない。180 秒で打ち切る。
set -uo pipefail
MONTH="${1:-}"
case "$MONTH" in [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;; *) echo "⚠️ 月の指定が無い（YYYY-MM）"; exit 0 ;; esac
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/gsc-monthly-$MONTH.md"
JSON="$RDIR/gsc-monthly-$MONTH.json"
WORK="${TMPDIR:-/tmp}/gsc-dump-$MONTH"
mkdir -p "$RDIR" "$WORK"
{ echo "# 月次の検索データ（$MONTH・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
for f in gsc-dump.py weekly-blog-report.py; do
  git -C "$REPO" show "origin/main:scripts/$f" > "$WORK/$f" 2>/dev/null || { echo "⚠️ **$f を取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }
done
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ **Python 3.10 以上が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

"$PY" "$WORK/gsc-dump.py" --month "$MONTH" --out "$JSON" > "$WORK/res.md" 2>&1 &
pid=$!; t0=$(date +%s); RC=0
while kill -0 "$pid" 2>/dev/null; do
  [ $(( $(date +%s) - t0 )) -ge 180 ] && { kill "$pid" 2>/dev/null; RC=124; break; }
  sleep 3
done
[ "$RC" = 124 ] || { wait "$pid" 2>/dev/null; RC=$?; }
{ echo "終了コード **$RC**"; echo; echo "| 取ったもの | 窓 | 行数 |"; echo "| --- | --- | --- |"; cat "$WORK/res.md"; echo; } >> "$OUT"
# **rc では判断しない。** JSON を読み直す（最上位ルール 13）
if [ -s "$JSON" ] && "$PY" -c 'import json,sys;json.load(open(sys.argv[1]))' "$JSON" 2>/dev/null; then
  echo "✅ \`gsc-monthly-$MONTH.json\` **$(wc -c < "$JSON" | tr -d ' ') bytes**・JSON として読める" >> "$OUT"
else
  echo "⚠️ **JSON が無いか、読めない**" >> "$OUT"
fi
rm -rf "$WORK"
echo "" >> "$OUT"; echo "LLM 不使用。GSC API は無料枠。**\$0/回・\$0/月。**" >> "$OUT"
cat "$OUT"
