#!/bin/bash
# **バリューコマース 4 件に 1 件ずつ提携申請する（applyvc5・1 件ごとに結果を書き出す）（t549）。** LLM 不使用・**$0**。
# t548 は 5 件をまとめて走らせて 165 秒で打ち切られ（rc=124）、結果が 1 件も書き出されなかった。
# 上限 60+48×4 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t549-vc-apply-one-by-one.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t549・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=50000 run_limited 60 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
for item in "アクティビティジャパン|アクティビティジャパン|2151410" "OZmall|OZmall|2026062" "ヒトサラ|ヒトサラ|2162006" "Pontely Foods|クラーノ|2174218"; do
  rm -f "$RDIR/asp-probe/applyvc5.md"
  VC_LIST="$item" ASP_PROBE=applyvc5 OPS_REPORT_DIR="$RDIR" run_limited 48 "$NODE_BIN" "$JS" > /dev/null 2>&1; rc=$?
  echo "## ${item%%|*}（rc=$rc）" >> "$OUT"
  if [ -f "$RDIR/asp-probe/applyvc5.md" ]; then grep -E '申請前|申請後|⛔|押す|問いの文|見えない' "$RDIR/asp-probe/applyvc5.md" | cut -c1-200 >> "$OUT"; else echo "- 結果が書き出されなかった（打ち切り）" >> "$OUT"; fi
done
echo '```' >> "$OUT"
head -c 4000 "$OUT"
