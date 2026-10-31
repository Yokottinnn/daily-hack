#!/bin/bash
# **{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・57 件）（t480・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"（t480）。** 画面を読むだけ・LLM 不使用・**$0**。
# 2026-10-31 の申請で提携中が 310 件に増えた（237 件が即時に提携）。新しく提携した案件の名前を読み、記事に合うバナーを選ぶ材料にする。
# 本体は scripts/asp/asp-probe.mjs（origin/main から取り出す）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t480-a8-partnered-35.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
{ echo "# A8 の提携中プログラムの名前・報酬・本人申込可否を読む（10/31 に提携した分・57 件）（t480・**\$0**）"; echo ""; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo ""; } > "$OUT"
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
A8_IDS=s00000000488020,s00000012600006,s00000025843001,s00000022624001,s00000025671001,s00000020428001,s00000017947001,s00000023026002,s00000012789008,s00000024526001,s00000018128001,s00000010054001,s00000023862001,s00000027366001,s00000017695001,s00000024864001,s00000017695007,s00000014348002,s00000020875001,s00000024740001,s00000026050001,s00000027162001,s00000006548001,s00000018024006,s00000018024002,s00000018024004,s00000018024003,s00000018024008,s00000018024011,s00000014992001,s00000015589003,s00000015589004,s00000014249003,s00000012574002,s00000024224003,s00000015589001,s00000013178004,s00000008384006,s00000021136004,s00000004657003,s00000020635003,s00000004657001,s00000007052007,s00000020635004,s00000020949005,s00000015619002,s00000016106001,s00000020962001,s00000022947006,s00000018721001,s00000019429001,s00000017141001,s00000021640001,s00000010346002,s00000020682003,s00000020682001,s00000010346001 ASP_PROBE=a8partnered OPS_REPORT_DIR="$RDIR" run_limited 200 "$NODE_BIN" "$JS" >> "$OUT" 2>&1
RC=$?
echo '```' >> "$OUT"; echo "rc=$RC / $(wc -c < "$OUT") bytes" >> "$OUT"
cp "$RDIR/asp-probe/a8partnered.json" "$RDIR/asp-probe/a8partnered-t480.json" 2>/dev/null
head -c 3000 "$OUT"
