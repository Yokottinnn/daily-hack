#!/bin/bash
# **今日公開した比較記事の Yahoo! のボタンだけを本番で押し直し、型番の商品が並んでいるかを数える（t988・読むだけ・買わない）。**
# 2026-11-22 利用者がダイアログで「Yahoo! の確認の道具を直す」を選んだ。直した scripts/shop/verify-buttons.mjs
# （型番を LinkSwitch の成果リンクの中の元の URL から取る・広告枠を数えない）で、countertop-dishwasher・oven-toaster の 2 本を確かめる。
# 写真は Mac の手元（private-shots）だけ。$OPS_REPORT_DIR に出すのは文字のレポートだけ。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t988-yahoo-reverify.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# Yahoo! のボタンの押し直し（t988・countertop-dishwasher・oven-toaster・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -n "$NODE_BIN" ] || { echo "⚠️ node が無い" >> "$OUT"; cat "$OUT"; exit 0; }
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
summarize() {
  local f="$RDIR/shop-verify/$1/result-yahoo-v3.json"
  [ -s "$f" ] || { echo "- ⚠️ $1: result-yahoo-v3.json が無い" >> "$OUT"; return; }
  "$NODE_BIN" -e '
    const d = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const ok = d.rows.filter((r) => r.hits > 0 || (r.cart && r.titleHit)).length;
    console.log(`\n### まとめ: ${d.slug}（ボタン ${d.total} 個 / 確かめた ${d.rows.length} 個 / 型番の商品あり ${ok} 個）`);
    for (const r of d.rows) console.log(`- ${r.n} ${r.name || r.model || "?"}｜型番「${(r.keys || []).join(" ")}」｜通常の商品 ${r.items ?? "—"} 件（広告 ${r.ads ?? "—"} 件は数えない）のうち型番一致 ${r.hits ?? "—"} 件${r.error ? "｜⚠️ " + r.error : ""}${r.robot ? "｜ロボット確認" : ""}`);
  ' "$f" >> "$OUT" 2>&1
}
git -C "$REPO" fetch -q origin main 2>/dev/null || true
JS="$RDIR/.shop-verify-988-buttons.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
[ -s "$JS" ] || { echo "⚠️ scripts/shop/verify-buttons.mjs が main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
git -C "$REPO" show origin/main:src/data/shop/countertop-dishwasher.json > "$RDIR/.t988-countertop-dishwasher.json"
( export SLUG="countertop-dishwasher-comparison-2026" STORE="yahoo" SHOP_JSON="$RDIR/.t988-countertop-dishwasher.json" OUT_SUFFIX="-v3" SHOT_PREFIX="y" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=125000; run_limited 145 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$? (countertop-dishwasher-comparison-2026)" >> "$OUT"
summarize "countertop-dishwasher-comparison-2026"
git -C "$REPO" show origin/main:src/data/shop/oven-toaster.json > "$RDIR/.t988-oven-toaster.json"
( export SLUG="oven-toaster-comparison-2026" STORE="yahoo" SHOP_JSON="$RDIR/.t988-oven-toaster.json" OUT_SUFFIX="-v3" SHOT_PREFIX="y" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS=125000; run_limited 145 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$? (oven-toaster-comparison-2026)" >> "$OUT"
summarize "oven-toaster-comparison-2026"

cat "$OUT"
