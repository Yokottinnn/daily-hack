#!/bin/bash
# **記事の広告の横に置く A8 のバナー（300×250 など）のコードを集める（2026-10-31 利用者がダイアログで「提携済み ASP のバナー」を選んだ）（t483・3 回目：15:35 の回は A8 の「ログイン再認証」で止まった。Keychain で入り直す処理を足した）。読むだけ・LLM 不使用・**$0**。**
# 2026-10-31 に新しく提携した案件のうち、記事の題材（旅行・航空券・格安SIM・光回線・ふるさと納税・宅配食・防災・ギフトなど）に合う 26 件のバナーを集める。
# 詳細ページから「広告リンク」の画面へ辿り、a8mat を含むコードを出す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t483-a8-links.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーのコード（t483・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
JS="$RDIR/.asp-probe.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
echo '```text' >> "$OUT"
ASP_ONLY=a8 OPS_REPORT_DIR="$RDIR/.sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$SYNC" > /dev/null 2>&1; echo "asp-sync rc=$?" >> "$OUT"
A8_IDS=s00000023934001,s00000025743001,s00000020819010,s00000017634001,s00000000488028,s00000000488017 A8_OUT=a8banners-t483.json ASP_PROBE=a8banners OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/a8banners.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
