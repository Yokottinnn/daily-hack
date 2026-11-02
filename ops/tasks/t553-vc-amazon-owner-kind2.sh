#!/bin/bash
# **バリューコマースと Amazon アソシエイトの登録が「法人」か「個人」かだけを読む（読むだけ・名前や口座は出さない）（t553）。** LLM 不使用・**$0**。
# t552 は VC の候補画面が 0 件・Amazon が名前解決の失敗だった。リンクの href でも探し、Amazon はもう一度開く。
# 上限 70+120 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t553-vc-amazon-owner-kind2.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t553・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
echo '```text' >> "$OUT"
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
ASP_ONLY=vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_PROBE=ownerrecon OPS_REPORT_DIR="$RDIR" run_limited 120 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/ownerrecon.md" >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
