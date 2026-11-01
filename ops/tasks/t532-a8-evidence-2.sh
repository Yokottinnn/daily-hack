#!/bin/bash
# **記事に出している A8 のバナー全 51 件のうち 18〜34 件目について、読者の何で報酬になるのか（成果条件・否認条件・確定率）と、リンクが「広告リンク作成」で作ったものかを A8 の画面で確かめる（t532）。読むだけ・LLM 不使用・$0。**
# 2026-11-01 利用者がダイアログで「ほかのバナーも同じように証跡を取る」を選んだ（t530 の 3 件と同じ読み方）。
# 1 件 4〜6 秒。17 件で詳細と広告リンク作成の 2 画面を読む（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t532-a8-evidence.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーの成果条件の証跡（2/3）（t532・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000022946004,s00000026058001,s00000017964001,s00000027309001,s00000008091019,s00000022801001,s00000020187002,s00000023934001,s00000025743001,s00000020819010,s00000017634001,s00000000488017,s00000000488020,s00000021712001,s00000023371001,s00000020428001,s00000019409001 ASP_PROBE=a8evidence OPS_REPORT_DIR="$RDIR" run_limited 160 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "evidence rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8evidence.md" >> "$OUT" 2>/dev/null
echo '```text' >> "$OUT"
A8_IDS=s00000022946004,s00000026058001,s00000017964001,s00000027309001,s00000008091019,s00000022801001,s00000020187002,s00000023934001,s00000025743001,s00000020819010,s00000017634001,s00000000488017,s00000000488020,s00000021712001,s00000023371001,s00000020428001,s00000019409001 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 130 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "linkcheck rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null
head -c 12000 "$OUT"
