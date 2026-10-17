#!/bin/bash
# **バリューコマースの提携申請・6 回目（t314・4 社）。** 利用者が 2026-10-12「4 社とも申請する」、2026-10-17「自分でやって」。LLM 不使用・**$0**。
# t313 で「いいえ／はい」のダイアログが出たが問いの文が読めず押さなかった。「はい」の周りから問いの文を読み、「提携」があり費用の語が無いときだけ押す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t314-vc-apply6.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# VC の提携申請・6 回目（t314・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
VC_LIST="一休.com|一休|179,じゃらんnet|じゃらん|2021810,Yahoo!トラベル|Yahoo!トラベル|2026983,ふるなび|ふるなび|2142798" ASP_PROBE=applyvc5 OPS_REPORT_DIR="$RDIR" run_limited 230 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"

cat "$RDIR/asp-probe/applyvc5.md" >> "$OUT" 2>/dev/null
head -c 6000 "$OUT"
