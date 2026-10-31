#!/bin/bash
# **{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t478・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"（t478）。** 画面を読むだけ・LLM 不使用・**$0**。
# 2026-10-31 の申請で提携中が 310 件に増えた（237 件が即時に提携）。新しく提携した案件の名前を読み、記事に合うバナーを選ぶ材料にする。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t478-a8-partnered-35.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t478・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000026123001,s00000013465001,s00000005350010,s00000025659001,s00000013798009,s00000013798001,s00000025498001,s00000026857001,s00000000218001,s00000001343020,s00000023946002,s00000001343016,s00000023244001,s00000022171004,s00000023067003,s00000022171001,s00000022946004,s00000022192001,s00000022171006,s00000001343022,s00000022171005,s00000001343017,s00000001343021,s00000027658001,s00000026619001,s00000014755001,s00000006576005,s00000010693001,s00000027697001,s00000021239001,s00000024278002,s00000005350011,s00000023946003,s00000022946005,s00000002586002,s00000027866001,s00000025957001,s00000010921001,s00000026280001,s00000000204018,s00000012076006,s00000027560001,s00000024116001,s00000015266006,s00000020317001,s00000024759002,s00000027650001,s00000006576010,s00000004439042,s00000020001004,s00000010868002,s00000004439025,s00000024558001,s00000013277002,s00000020317006,s00000020317003,s00000020001003,s00000022571001,s00000023371004,s00000013178023 ASP_PROBE=a8partnered OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cp "$RDIR/asp-probe/a8partnered.json" "$RDIR/asp-probe/a8partnered-t478.json" 2>/dev/null
head -c 3000 "$OUT"
