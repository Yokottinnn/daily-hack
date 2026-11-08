#!/bin/bash
# **ブログに貼れるクリック報酬の案件が A8・VC にどれだけあるかを読む（t585・affiliate・読むだけ）。** LLM 不使用・**$0**。2026-11-08 利用者がダイアログで「調べる」を選んだ。申請はしない。上限 70+200 秒。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t585-click-programs.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8・VC のクリック報酬の案件（t585・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=a8,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_PROBE=clicksearch OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "clicksearch rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/clicksearch.md" >> "$OUT" 2>/dev/null || echo "（clicksearch.md が無い）" >> "$OUT"
head -c 12000 "$OUT"
