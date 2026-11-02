#!/bin/bash
# **11/1 に申請して審査中だった A8 の 6 件と VC の Pontely Foods の状態を読む（読むだけ）（t551）。** LLM 不使用・**$0**。
# 利用者が「審査の結果を明日見て足す」を選んだ（11/1）。もしもは 11/2 に「放置する」と決まったので読まない。
# 上限 70+90+60 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t551-a8-vc-status.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# もしも・バリューコマースの「案件を探す」画面（t551・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=a8,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
A8_IDS=s00000025349002,s00000021939003,s00000020412003,s00000011565001,s00000026742001,s00000025742001 ASP_PROBE=a8status OPS_REPORT_DIR="$RDIR" run_limited 90 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "a8 rc=$?" >> "$OUT"
SEARCH_KWS="クラーノ,Pontely" ASP_PROBE=vcsearch OPS_REPORT_DIR="$RDIR" run_limited 60 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "vc rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8status.md" >> "$OUT" 2>/dev/null
grep -E '^## VC|2174218' "$RDIR/asp-probe/vcsearch.md" | cut -c1-260 >> "$OUT" 2>/dev/null
head -c 3000 "$OUT"
