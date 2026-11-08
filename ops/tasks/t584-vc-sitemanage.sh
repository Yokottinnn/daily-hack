#!/bin/bash
# **バリューコマースに X（SNS メディア）を登録しているか・サイト設定の全部の行を読む（t583 で空だったため）（t584・affiliate・読むだけ）。** LLM 不使用・**$0**。
# 2026-11-08 利用者がダイアログで「調べる」を選んだ。VC は 2025-07-16 から、YouTube・Instagram・X を登録したサイトだけに CPC（クリック報酬）のオファーを開示している
# （https://www.valuecommerce.ne.jp/topics/sns_cpc_program）。登録・申請はしない。上限 70+120 秒。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t584-vc-sns-cpc.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# VC の サイト設定の全部の行（t584・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
echo '```text' >> "$OUT"
ASP_ONLY=vc OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=60000 run_limited 70 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1; echo "sync rc=$?" >> "$OUT"
ASP_PROBE=vcsites2 OPS_REPORT_DIR="$RDIR" run_limited 120 "$NODE_BIN" "$JS" > /dev/null 2>&1; echo "vcsites2 rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/vcsites2.md" >> "$OUT" 2>/dev/null || echo "（vcsites2.md が無い）" >> "$OUT"
head -c 12000 "$OUT"
