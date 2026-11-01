#!/bin/bash
# **もしもで 5 記事の題材のキーワード検索をし、詳細画面のボタンを読む。VC は案件を探す画面の入口を読む（どちらも押さない）（t545）。** LLM 不使用・**$0**。
# 2026-11-01 利用者が「もしも・バリューコマースでも探す」を選んだ。t544 でもしもの検索欄が words だと分かった。VC の /ad/search は「ページが表示できません」だった。
# 上限 85+130+45 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t545-moshimo-search-vc-recon.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t545・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=moshimo,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=70000 run_limited 85 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
SEARCH_KWS="ドッグフード,ペット,レストラン,コーヒー,和菓子,お取り寄せ,チケット,レゴ" ASP_PROBE=moshimosearch OPS_REPORT_DIR="$RDIR" run_limited 130 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "moshimo rc=$?" >> "$OUT"
ASP_PROBE=vcrecon OPS_REPORT_DIR="$RDIR" run_limited 45 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "vc rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/moshimosearch.md" "$RDIR/asp-probe/vcrecon.md" >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
