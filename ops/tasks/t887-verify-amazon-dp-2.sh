#!/bin/bash
# **比較記事の Amazon ボタン（商品ページ・ASIN）を本番で押し、商品ページ（カートのボタンあり・題名に型番）に着いて tag=dailyhack-22 が残るかを確かめる（t887・読むだけ・買わない・カートに入れない）。**
# 2026-11-22 利用者が「Amazon は商品ページに直接飛ばす」を選び、PR #1925 で 53 機種に ASIN を入れた。/dp/ のボタンだけを押す（MATCH=/dp/）。
# 本体は scripts/shop/verify-buttons.mjs（origin/main から取り出す）。写真は Mac の手元（private-shots）にだけ置き、公開ブランチには文字のレポートだけ出す。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t887-verify-amazon-dp.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# Amazon の商品ページボタンの確認（t887・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
git -C "$REPO" fetch -q origin main 2>/dev/null || true
JS="$RDIR/.shop-verify-buttons.mjs"; git -C "$REPO" show origin/main:scripts/shop/verify-buttons.mjs > "$JS"
[ -s "$JS" ] || { echo "⚠️ スクリプトが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
# 記事の slug:データの json:1 記事の持ち時間（ミリ秒）
for spec in smartwatch-comparison-2026:smartwatch:75000 humidifying-air-purifier-comparison-2026:humidifying-air-purifier:65000 futon-dryer-comparison-2026:futon-dryer:95000; do
  SLUG="${spec%%:*}"; rest="${spec#*:}"; SER="${rest%%:*}"; BMS="${rest#*:}"
  # SER は「a+b」で 2 つのデータをまとめられる（電動歯ブラシの記事は本体と替えブラシの 2 つ）
  SJ="$RDIR/.shop-verify-$SLUG.json"; : > "$SJ.parts"
  for s in ${SER//+/ }; do git -C "$REPO" show "origin/main:src/data/shop/$s.json" > "$RDIR/.shop-part-$s.json"; echo "$RDIR/.shop-part-$s.json" >> "$SJ.parts"; done
  "$NODE_BIN" -e 'const fs=require("fs");const items=fs.readFileSync(process.argv[1],"utf8").trim().split("\n").flatMap(p=>JSON.parse(fs.readFileSync(p,"utf8")).items||[]);fs.writeFileSync(process.argv[2],JSON.stringify({items}));' "$SJ.parts" "$SJ"
  ( export SLUG STORE=amazon MATCH=/dp/ SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" VERIFY_BUDGET_MS="$BMS" SHOT_PREFIX=dp; run_limited $(( BMS / 1000 + 30 )) "$NODE_BIN" "$JS" ) > /dev/null 2>&1
  echo "- $SLUG: rc=$?" >> "$OUT"
  R="$RDIR/shop-verify/$SLUG/report-amazon-retry.md"
  if [ -f "$R" ]; then
    "$NODE_BIN" -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const ok=j.rows.filter(r=>r.cart&&r.titleHit&&/[?&]tag=dailyhack-22(&|$)/.test(r.fin||""));
console.log(`  - ボタン ${j.total} 個 / 押した ${j.rows.length} 個 / 商品ページ＋型番＋tag ${ok.length} 個`);
for(const r of j.rows){if(ok.includes(r))continue;console.log(`  - ⚠️ ${r.name||""}｜${r.href}｜着いた先 ${(r.fin||"").slice(0,120)}｜cart=${!!r.cart} 型番=${!!r.titleHit}｜題名 ${(r.h1||r.title||"").slice(0,80)}${r.error?"｜"+r.error:""}`);}
' "$RDIR/shop-verify/$SLUG/result-amazon-retry.json" >> "$OUT" 2>&1
  else echo "  - （レポートが無い）" >> "$OUT"; fi
done
cat "$OUT"
