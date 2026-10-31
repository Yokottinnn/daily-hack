#!/bin/bash
# **{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t477・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"（t477）。** 画面を読むだけ・LLM 不使用・**$0**。
# 2026-10-31 の申請で提携中が 310 件に増えた（237 件が即時に提携）。新しく提携した案件の名前を読み、記事に合うバナーを選ぶ材料にする。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t477-a8-partnered-35.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t477・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000016469001,s00000015110002,s00000003655004,s00000025786001,s00000011939001,s00000027732001,s00000023342001,s00000017117006,s00000001148001,s00000027309001,s00000027731001,s00000017964001,s00000000979014,s00000024773001,s00000022801001,s00000026743001,s00000026076001,s00000025681002,s00000016351005,s00000016351006,s00000027225001,s00000025009003,s00000017718022,s00000024266003,s00000008091019,s00000000979008,s00000000979024,s00000000979016,s00000000979023,s00000000979017,s00000014546018,s00000025883001,s00000000979020,s00000000040018,s00000022358003,s00000022358002,s00000013909002,s00000027653001,s00000011875005,s00000020187002,s00000013504001,s00000025107001,s00000021810003,s00000021918003,s00000022400001,s00000022400002,s00000004439045,s00000022400003,s00000004439066,s00000023934001,s00000027240002,s00000025743001,s00000027240001,s00000024389001,s00000020819010,s00000026218001,s00000027294001,s00000017634001,s00000004570004,s00000026058001 ASP_PROBE=a8partnered OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cp "$RDIR/asp-probe/a8partnered.json" "$RDIR/asp-probe/a8partnered-t477.json" 2>/dev/null
head -c 3000 "$OUT"
