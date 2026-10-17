#!/bin/bash
# **バリューコマースの提携申請・4 回目（t305）。** 利用者が 2026-10-12 に「4 社とも申請する」、2026-10-17 に「Mac に送らせる許可を出す」を選んだ（ふるなび・一休.com・じゃらんnet・Yahoo!トラベル）。LLM 不使用・**$0**。
# 公式ヘルプどおり「広告素材を選ぶ」を押し、確認の文に「提携申請」があり費用の語が無いときだけ OK。申請前後の状態を一覧で読む。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t305-vc-apply4.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# VC の提携申請・4 回目（t305・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_ONLY=a8,vc,moshimo OPS_REPORT_DIR="$RDIR/.sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$SYNC" > /dev/null 2>&1; echo "asp-sync rc=$?" >> "$OUT"
ASP_PROBE=applyvc4 OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/applyvc4.md" >> "$OUT" 2>/dev/null
head -c 6000 "$OUT"
