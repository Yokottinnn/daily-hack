#!/bin/bash
# **提携できたレストラン予約・コーヒー・老舗の和菓子 6 件のバナーと成果条件の証跡を取る（t542-a8-banners-food）。** LLM 不使用・**$0**。
# 2026-11-01 t538・t539 の申請で即時に提携できた 12 件のうち 6 件。
# 詳細ページから「広告リンク」の画面へ辿り、a8mat を含むコードを出す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t542-a8-banners-food-a8-links.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーのコード（t542-a8-banners-food・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000020542002,s00000000218004,s00000027754001,s00000027689001,s00000025613001,s00000021453001 A8_OUT=a8banners-t542-a8-banners-food.json ASP_PROBE=a8banners OPS_REPORT_DIR="$RDIR" run_limited 150 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
A8_IDS=s00000020542002,s00000000218004,s00000027754001,s00000027689001,s00000025613001,s00000021453001 ASP_PROBE=a8evidence OPS_REPORT_DIR="$RDIR" run_limited 110 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "evidence rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/a8banners.md" >> "$OUT" 2>/dev/null
cat "$RDIR/asp-probe/a8evidence.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
