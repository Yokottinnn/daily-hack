#!/bin/bash
# **11/1 に足した A8 のバナー 14 件のリンクが Daily hack のサイトで作られ、記事の a8mat と一致するかを確かめる（t543）。** LLM 不使用・**$0**。
# 2026-11-01 利用者がダイアログで「ほかのバナーも同じように証跡を取る」「記事ごとに題材に合う案件を探して置き換える」を選んだ。
# 14 件で 1 画面ずつ（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t543-a8-evidence.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# 11/1 に足した A8 のバナー 9 件の成果条件の証跡（t543・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
echo '```' >> "$OUT"
echo '```text' >> "$OUT"
A8_IDS=s00000012993002,s00000023026002,s00000000458006,s00000021939002,s00000000458037,s00000025349001,s00000017753002,s00000000458020,s00000020542002,s00000000218004,s00000027754001,s00000027689001,s00000025613001,s00000021453001 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "linkcheck rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null
head -c 12000 "$OUT"
