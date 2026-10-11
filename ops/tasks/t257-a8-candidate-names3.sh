#!/bin/bash
# **A8 の未提携の高単価候補の名前と提携方式を読む（先に asp-sync で A8 に入る）（t257）。** 画面を読むだけ・LLM 不使用・**$0**。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t257-a8-candidate-names3.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の候補の名前と提携方式（t257・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000023355003,s00000024441001,s00000026575004,s00000026575013,s00000026575008,s00000026575010,s00000015597014,s00000023297001,s00000013470008,s00000025908001,s00000017066001 A8_KEYWORDS=三井住友カード,セゾン,クレジットカード,dカード,ポイントサイト ASP_PROBE=a8 OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 3000 "$OUT"
