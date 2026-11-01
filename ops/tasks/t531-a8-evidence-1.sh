#!/bin/bash
# **記事に出している A8 のバナー全 51 件のうち 1〜17 件目について、読者の何で報酬になるのか（成果条件・否認条件・確定率）と、リンクが「広告リンク作成」で作ったものかを A8 の画面で確かめる（t531）。読むだけ・LLM 不使用・$0。**
# 2026-11-01 利用者がダイアログで「ほかのバナーも同じように証跡を取る」を選んだ（t530 の 3 件と同じ読み方）。
# 1 件 4〜6 秒。17 件で詳細と広告リンク作成の 2 画面を読む（5 分以内）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t531-a8-evidence.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# A8 のバナーの成果条件の証跡（1/3）（t531・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
A8_IDS=s00000017718004,s00000016370001,s00000019044001,s00000017718046,s00000021621001,s00000013511010,s00000017718005,s00000017675001,s00000023067001,s00000024224001,s00000016921003,s00000014546024,s00000000218001,s00000023244001,s00000004570004,s00000013798001,s00000001343016 ASP_PROBE=a8evidence OPS_REPORT_DIR="$RDIR" run_limited 160 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "evidence rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8evidence.md" >> "$OUT" 2>/dev/null
echo '```text' >> "$OUT"
A8_IDS=s00000017718004,s00000016370001,s00000019044001,s00000017718046,s00000021621001,s00000013511010,s00000017718005,s00000017675001,s00000023067001,s00000024224001,s00000016921003,s00000014546024,s00000000218001,s00000023244001,s00000004570004,s00000013798001,s00000001343016 ASP_PROBE=a8linkcheck OPS_REPORT_DIR="$RDIR" run_limited 130 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "linkcheck rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8linkcheck.md" >> "$OUT" 2>/dev/null
head -c 12000 "$OUT"
