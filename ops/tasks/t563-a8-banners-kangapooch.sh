#!/bin/bash
# **11/1 申請で提携になった KANGAPOOCH（犬の抱っこ紐）のバナー・成果条件の証跡・リンクの確認を取る（t563）。** LLM 不使用・**$0**。
# 2026-11-06 の作戦室の更新で、A8 の提携中の一覧に入ったのを見つけた（審査待ち a8-pending.json の 1 件）。上限 120+90+60 秒（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t563-a8-banners-kangapooch-a8-links.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーのコード（t563-a8-banners-kangapooch・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000020412003 A8_OUT=a8banners-t563-a8-banners-kangapooch.json ASP_PROBE=a8banners OPS_REPORT_DIR="$RDIR" run_limited 120 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
A8_IDS=s00000020412003 ASP_PROBE=a8evidence OPS_REPORT_DIR="$RDIR" run_limited 90 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "evidence rc=$?" >> "$OUT"
A8_IDS=s00000020412003 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 60 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "linkcheck rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/a8banners.md" >> "$OUT" 2>/dev/null
cat "$RDIR/asp-probe/a8evidence.md" >> "$OUT" 2>/dev/null
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
