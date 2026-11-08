#!/bin/bash
# **VC の案件検索で「クリック報酬（CPC）」を画面で選んで検索し、結果を読む（t587・affiliate・読むだけ）。** t586 は URL の条件で 0 件・件数の表示なしだったため。LLM 不使用・**$0**。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t587-vc-cpc.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# VC のクリック報酬（CPC）の案件（t587・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_PROBE=vccpc2 OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "vccpc2 rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/vccpc2.md" >> "$OUT" 2>/dev/null || echo "（vccpc2.md が無い）" >> "$OUT"
head -c 12000 "$OUT"
