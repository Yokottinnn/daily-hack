#!/bin/bash
# **A8 で即時提携した WOWOWオンデマンド（2026-10-19 に審査が通った）の広告リンクのコードを読む。t324 は CDP 接続の一時エラー（shared_worker の assert）で落ちたので 3 回まで再試行する（t325）。読むだけ・LLM 不使用・**$0**。**
# 詳細ページから「広告リンク」の画面へ辿り、a8mat を含むコードを出す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t325-a8-links.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 の広告リンクのコード（t325・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=a8 OPS_REPORT_DIR="$RDIR/.sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$SYNC" > /dev/null 2>&1; echo "asp-sync rc=$?" >> "$OUT"
for TRY in 1 2 3; do A8_IDS=s00000025070001 ASP_PROBE=a8links OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" > "$RDIR/.t325.log" 2>&1; PRC=$?; echo "probe try=$TRY rc=$PRC" >> "$OUT"; [ $PRC -eq 0 ] && break; tail -3 "$RDIR/.t325.log" >> "$OUT"; sleep 15; done
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/a8links.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
