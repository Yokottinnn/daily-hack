#!/bin/bash
# **11/1 に審査が通った A8 の 7 件（t526 で提携中になったもの）の名前・報酬を読み、続けてバナーを集める（t527）。読むだけ・LLM 不使用・$0。**
# 2026-10-31 の申請で提携中が 310 件に増えた（237 件が即時に提携）。新しく提携した案件の名前を読み、記事に合うバナーを選ぶ材料にする。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t527-a8-new-partnered.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（11/1 に審査が通った 7 件）（t527・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
echo '```text' >> "$OUT"
# まず asp-sync でログインを保つ（切れていれば Keychain で入り直す）
SYNC="$RDIR/.asp-sync.mjs"; git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$SYNC"
ASP_ONLY=a8 OPS_REPORT_DIR="$RDIR" ASP_SYNC_BUDGET_MS=80000 run_limited 90 "$NODE_BIN" "$SYNC" >> "$OUT" 2>&1
JS="$RDIR/.asp-probe.mjs"
git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$JS"
A8_IDS=s00000026698001,s00000024877008,s00000027806001,s00000025908001,s00000017066001,s00000020637001,s00000014177001 ASP_PROBE=a8partnered OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cp "$RDIR/asp-probe/a8partnered.json" "$RDIR/asp-probe/a8partnered-t527.json" 2>/dev/null

echo '' >> "$OUT"; echo '## バナー（a8banners）' >> "$OUT"; echo '```text' >> "$OUT"
A8_IDS=s00000026698001,s00000024877008,s00000027806001,s00000025908001,s00000017066001,s00000020637001,s00000014177001 A8_OUT=a8banners-t527.json ASP_PROBE=a8banners OPS_REPORT_DIR="$RDIR" run_limited 120 "$NODE_BIN" "$JS" >> "$OUT" 2>&1; echo "probe rc=$?" >> "$OUT"
echo '```' >> "$OUT"
cat "$RDIR/asp-probe/a8banners.md" >> "$OUT" 2>/dev/null
head -c 9000 "$OUT"
