#!/bin/bash
# **題材に合うバナーが 1 枚以下の 5 記事（ドッグパーク・ブルーライトアップ・ドラえもん・500円モーニング・佃島）に合う案件を、A8・もしも・バリューコマースで探す（2026-11-01 利用者が選んだ）（t537）。** LLM 不使用・**$0**。
# 本体は scripts/asp/asp-search.mjs（origin/main から取り出す）。ログインは asp-sync が保っている Chrome を使う。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t537-asp-search-weak5.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# 記事に当てる広告を探す（t537・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
# 先に asp-sync で入り直しておく（楽天は外す）
SYNC="$RDIR/.asp-sync.mjs"; SEARCH="$RDIR/.asp-search.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
git -C "$REPO" show origin/main:scripts/asp/asp-search.mjs > "$SEARCH"
echo '```text' >> "$OUT"
ASP_ONLY=a8,moshimo,vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=70000 run_limited 85 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1
KW="ペット,ドッグ,ペット保険,ドッグフード,チケット,美術館,レストラン予約,ディナー,グルメ,カフェ,お取り寄せ,和菓子,佃煮,映画"
ASP_KEYWORDS="$KW" ASP_OUT_SUFFIX="-weak5" OPS_REPORT_DIR="$RDIR" ASP_SEARCH_BUDGET_MS=200000 run_limited 210 "$NODE_BIN" "$SEARCH" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"
echo "- 詳細: \`reports/asp-search/\`（a8.md・moshimo.md・vc.md）" >> "$OUT"
echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
head -c 1500 "$OUT"
