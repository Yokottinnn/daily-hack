#!/bin/bash
# **VC の申請の入口を読むだけで調べる・3 回目（t304）。「広告素材を選ぶ」を開いて中を読み、閉じる。中のボタンは押さない。** LLM 不使用・**$0**。
# t303 で一覧の「一括提携」は LinkSwitch 用の隠れたボタンと分かった。詳細ページ側と「サイト設定」を読む。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t304-vc-modal-probe.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# VC の申請の入口・3 回目（t304・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
ASP_PROBE=vcmodal OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/vcmodal.md" >> "$OUT" 2>/dev/null
head -c 6000 "$OUT"
