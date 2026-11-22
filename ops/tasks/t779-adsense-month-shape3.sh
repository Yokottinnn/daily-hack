#!/bin/bash
# **AdSense のレポートを「今月」に切り替えて読めるかを、形だけで確かめる・3 回目（t779・affiliate・読むだけ・数字は # に伏せる）。** LLM 不使用・**$0**。
# 2026-11-22 利用者が作戦室の AdSense の行を「今月にそろえる」を選んだ。直した asp-results.mjs はまだ main に入れていないので、
# t777 は「今月」を押せなかった（Playwright の filter({visible}) が Mac の版で効かない）。DOM で押し、選ばれている期間を確かめるように直した版を試す。
# t778 は「今月」のチップ（material-chip role=radio）を押せたが、選ばれた期間の読み方が合っていなかった。aria-checked で読む版を試す。
# ブランチ affiliate/adsense-month から取り出して、RESULTS_MODE=shape・RESULTS_ONLY=adsense で走らせる（公開の md は数字が伏せてある）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t779-adsense-month-shape.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# AdSense のレポートを「今月」に切り替えて読めるか（t779・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin affiliate/adsense-month 2>/dev/null || true
JS="$RDIR/.asp-results-month.mjs"
git -C "$REPO" show FETCH_HEAD:scripts/asp/asp-results.mjs > "$JS" 2>/dev/null || git -C "$REPO" show origin/affiliate/adsense-month:scripts/asp/asp-results.mjs > "$JS" 2>/dev/null
[ -s "$JS" ] || { echo "⚠️ ブランチの asp-results.mjs が取り出せない" >> "$OUT"; exit 0; }
mkdir -p "$RDIR/t779"
( export RESULTS_MODE=shape RESULTS_ONLY=adsense OPS_REPORT_DIR="$RDIR/t779"; "$NODE_BIN" "$JS" ) > /dev/null 2>&1; echo "- rc=$?" >> "$OUT"
cat "$RDIR/t779/asp-results/shape.md" >> "$OUT" 2>/dev/null || echo "（shape.md が無い）" >> "$OUT"
rm -f "$JS"
echo "t779 / $(basename "$OUT")"
