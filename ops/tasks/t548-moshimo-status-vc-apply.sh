#!/bin/bash
# **もしも 6 件の申請状態を「基本情報」から読み直し、バリューコマース 5 件は実績のある applyvc5 で申請し直す（t548）。** LLM 不使用・**$0**。
# t547 は、もしもは押したあとの状態がサイドバーのリンクと混ざって読めず、VC は adDetail に「新規提携」が見えず送れなかった。
# 上限 70+60+165 秒（5 分以内）。VC は 1 件 25 秒前後かかるので 5 件に絞った（＆UCHInoCO・ホットペッパーは次回）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t548-moshimo-status-vc-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t548・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=moshimo,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
MOSHIMO_IDS=7618,7330,7483,6373,6301,7792 ASP_PROBE=moshimostatus OPS_REPORT_DIR="$RDIR" run_limited 60 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "moshimo rc=$?" >> "$OUT"
VC_LIST="Pontely Foods|クラーノ|2174218,1stDogCafe|1stdogcafe|2166417,OZmall|OZmall|2026062,ヒトサラ|ヒトサラ|2162006,アクティビティジャパン|アクティビティジャパン|2151410" ASP_PROBE=applyvc5 OPS_REPORT_DIR="$RDIR" run_limited 165 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "vc rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/moshimostatus.md" "$RDIR/asp-probe/applyvc5.md" >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
