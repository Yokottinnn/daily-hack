#!/bin/bash
# **A8 の提携申請 12 件を出す（t309・ジム・脱毛・動画・FX）。利用者が 2026-10-17 のダイアログで申請する候補として選んだ。** 申請を送る・LLM 不使用・**$0**。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t309-a8-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携申請 12 件（t309・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
echo '```text' >> "$OUT"
# まず asp-sync でログインを保つ（切れていれば Keychain で入り直す）
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
ASP_ONLY=a8 OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=80000 run_limited 90 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1
JS="$RDIR/.asp-probe.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
A8_IDS=s00000024602001,s00000020539001,s00000013449001,s00000022221001,s00000014289002,s00000024229002,s00000024593001,s00000025070001,s00000026427001,s00000020550001,s00000017962001,s00000008903001 ASP_PROBE=a8apply OPS_REPORT_DIR="$RDIR" run_limited 190 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cat "$RDIR/asp-probe/a8apply.md" >> "$OUT" 2>/dev/null; cp "$RDIR/asp-probe/a8apply.md" "$RDIR/asp-probe/a8apply-t309.md" 2>/dev/null
head -c 6000 "$OUT"
