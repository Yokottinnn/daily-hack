#!/bin/bash
# **もしもの候補 20 件の詳細（名前・成果条件・否認条件）を読み、VC を /ad/adList?keyword= で検索する（どちらも押さない）（t546）。** LLM 不使用・**$0**。
# 2026-11-01 利用者が「もしも・バリューコマースでも探す」を選んだ。t545 でもしもの検索結果の ID と、VC の検索 URL（/ad/adList?keyword=）が分かった。
# 上限 70+165+55 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t546-moshimo-detail-vc-search.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t546・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
MOSHIMO_IDS=7618,7330,7779,7764,7241,7516,7483,7536,7509,7812,7667,3752,7165,7105,6373,6301,7144,6936,5951,7792 ASP_PROBE=moshimodetail OPS_REPORT_DIR="$RDIR" run_limited 165 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "moshimo rc=$?" >> "$OUT"
SEARCH_KWS="ドッグフード,ペット,レストラン,コーヒー,和菓子,お取り寄せ,チケット,レゴ" ASP_PROBE=vcsearch OPS_REPORT_DIR="$RDIR" run_limited 55 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "vc rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/moshimodetail.md" "$RDIR/asp-probe/vcsearch.md" >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
