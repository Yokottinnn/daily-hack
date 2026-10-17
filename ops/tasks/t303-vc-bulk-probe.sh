#!/bin/bash
# **VC の一括提携ボタンの状態を読む（t303）。チェックするだけで押さない・最後にチェックを外す。** LLM 不使用・**$0**。
# t302 でチェック 1 件になったのにボタンが押せる状態にならなかった。チェック欄とボタンの HTML と表示状態を取る。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t303-vc-bulk-probe.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# VC の一括提携ボタンの状態（t303・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
JS="$RDIR/.asp-probe.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
echo '```text' >> "$OUT"
ASP_ONLY=a8,vc,moshimo OPS_REPORT_DIR="$RDIR/.sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$SYNC" > /dev/null 2>&1; echo "asp-sync rc=$?" >> "$OUT"
ASP_PROBE=vcbulk OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/vcbulk.md" >> "$OUT" 2>/dev/null
head -c 6000 "$OUT"
