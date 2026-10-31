#!/bin/bash
# **{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t479・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"（t479）。** 画面を読むだけ・LLM 不使用・**$0**。
# 2026-10-31 の申請で提携中が 310 件に増えた（237 件が即時に提携）。新しく提携した案件の名前を読み、記事に合うバナーを選ぶ材料にする。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t479-a8-partnered-35.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・60 件）（t479・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000027043001,s00000023371001,s00000020065003,s00000021712001,s00000027644001,s00000022499001,s00000011202001,s00000027055001,s00000026172001,s00000014877001,s00000027604001,s00000020001002,s00000010453001,s00000001671069,s00000027637001,s00000027470001,s00000026610001,s00000018024005,s00000019280005,s00000013178018,s00000020048001,s00000017957001,s00000017294002,s00000017294001,s00000026001001,s00000015695001,s00000017294003,s00000025694001,s00000014225015,s00000012993002,s00000019409001,s00000023131001,s00000019447001,s00000027222001,s00000016565007,s00000001004012,s00000022942001,s00000005174001,s00000015623001,s00000000842023,s00000017598001,s00000027553001,s00000013027001,s00000000488028,s00000000488017,s00000009132012,s00000008115002,s00000008115003,s00000008115001,s00000024962001,s00000024360001,s00000021681001,s00000023526001,s00000021288005,s00000010789007,s00000021058001,s00000007476001,s00000023645001,s00000025052001,s00000009319002 ASP_PROBE=a8partnered OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cp "$RDIR/asp-probe/a8partnered.json" "$RDIR/asp-probe/a8partnered-t479.json" 2>/dev/null
head -c 3000 "$OUT"
