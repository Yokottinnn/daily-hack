#!/bin/bash
# **記事の題材に合う A8 の提携中の案件 10 件のバナーのコードを集める（t534）。読むだけ・LLM 不使用・$0。**
# 2026-11-01 利用者がダイアログで「記事ごとに題材に合う案件を探して置き換える」を選んだ。お金の記事に FP 相談、湾岸のイベントに国内ホテル・高速バス・レンタカー、湾岸の暮らしに引越し・光回線・家事代行、男性脱毛にスキンケア。
# 詳細ページから「広告リンク」の画面へ辿り、a8mat を含むコードを出す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t534-a8-links.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーのコード（t534・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000027294001,s00000026218001,s00000001343020,s00000001343021,s00000014755001,s00000004657001,s00000020949005,s00000000040018,s00000016106001,s00000020317001 A8_OUT=a8banners-t534.json ASP_PROBE=a8banners OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/a8banners.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
