#!/bin/bash
# **ブログに出ている Oisix・アゴダ（遊び・体験）・たびらいのバナーが、読者の何で報酬になるのかを A8 の画面で確かめる（t530）。読むだけ・LLM 不使用・$0。**
# 2026-11-01 利用者「これらってサービスサイトのバナーだけど、ここから何をしたら私の収益に繋がるのかちゃんと教えて。お金が関わる話なのでちゃんと証跡を持って証明して」。
# ① 提携中の案件の詳細ページの本文（成果条件・否認条件・確定までの期間）② バナーを取った画面が「広告リンク作成」（セルフバックではない）か、を読む。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t530-a8-evidence.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# Oisix・アゴダ・たびらいの成果条件の証跡（t530・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000000488017,s00000022946005,s00000006576010 ASP_PROBE=a8evidence OPS_REPORT_DIR="$RDIR" run_limited 150 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "evidence rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8evidence.md" >> "$OUT" 2>/dev/null
echo '```text' >> "$OUT"
A8_IDS=s00000000488017,s00000022946005,s00000006576010 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 100 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "linkcheck rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null
head -c 12000 "$OUT"
