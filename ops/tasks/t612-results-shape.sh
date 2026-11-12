#!/bin/bash
# **成果の表に Amazon と発生売上を足すため、A8 のレポートの見出しと Amazon アソシエイトのホームの並びを読む（t612・affiliate・読むだけ・数字は伏せる）。** 2026-11-12 利用者のコメント。LLM 不使用・**$0**。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t612-results-shape.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 のレポートと Amazon のホームの形（t612・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 2
  done
  wait "$pid" 2>/dev/null
}
JS="$RDIR/.asp-probe.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
echo '```text' >> "$OUT"
ASP_ONLY=a8 OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_PROBE=resultshape OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "resultshape rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/resultshape.md" >> "$OUT" 2>/dev/null || echo "（resultshape.md が無い）" >> "$OUT"
head -c 12000 "$OUT"
