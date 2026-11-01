#!/bin/bash
# **もしも 6 件・バリューコマース 7 件に提携申請する（5 記事の題材に合うもの）（t547）。** LLM 不使用・**$0**。
# 2026-11-01 利用者が「もしも・バリューコマースでも探す」を選んだ（10/31「申請の都度の確認は要らない」）。候補は t546 で詳細を読んだ。確認画面に費用の記載があれば送らない。
# 上限 70+110+115 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t547-moshimo-vc-apply.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t547・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
MOSHIMO_IDS=7618,7330,7483,6373,6301,7792 ASP_PROBE=moshimoapply OPS_REPORT_DIR="$RDIR" run_limited 110 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "moshimo rc=$?" >> "$OUT"
VC_APPLY="2174218:Pontely Foods,2166417:1stDogCafe,2171694:＆UCHInoCO,2026062:OZmall,2162006:ヒトサラ,2151410:アクティビティジャパン,2028047:ホットペッパーグルメ" ASP_PROBE=applyvc OPS_REPORT_DIR="$RDIR" run_limited 115 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "vc rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/moshimoapply.md" "$RDIR/asp-probe/applyvc.md" >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
