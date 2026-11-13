#!/bin/bash
# **読まれている記事に合う案件を A8・VC で探す（t615・affiliate・読むだけ・申請しない）。** LLM 不使用・**$0**。
# 2026-11-13 利用者がダイアログで「読まれている記事にリンク」「案件を広げる」を選んだ。読者の多い記事（ららぽーと・アウトレット・イオンモール・
# 高輪ゲートウェイ・放送大学・チームラボ）に成果リンクがほとんど無い。合う案件と、提携の状態・報酬を書き出す。上限 70+230+90 秒。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t615-program-search.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# 読まれている記事に合う案件（t615・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SRCH="$RDIR/.asp-search.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-search.mjs > "$SRCH"
JS="$RDIR/.asp-probe.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
KW="ららぽーと,三井ショッピングパーク,アウトレット,イオン,一休,OZmall,アソビュー,チームラボ,ふるなび,ふるさと納税,通信講座,オンライン英会話,駐車場,レンタカー"
echo '```text' >> "$OUT"
ASP_ONLY=a8,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_KEYWORDS="$KW" MOSHIMO_OFF=1 OPS_REPORT_DIR="$RDIR" ASP_SEARCH_BUDGET_MS=210000 run_limited 230 "$NODE_BIN" "$SRCH" >> "$OUT" 2>&1; echo "a8 search rc=$?" >> "$OUT"
SEARCH_KWS="ららぽーと,三井,アウトレット,イオン,一休,アソビュー,ふるなび,さとふる,レストラン" ASP_PROBE=vcsearch OPS_REPORT_DIR="$RDIR" run_limited 90 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "vc search rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-search/a8.md" >> "$OUT" 2>/dev/null || echo "（a8.md が無い）" >> "$OUT"
echo >> "$OUT"; cat "$RDIR/asp-probe/vcsearch.md" >> "$OUT" 2>/dev/null || echo "（vcsearch.md が無い）" >> "$OUT"
head -c 40000 "$OUT"
