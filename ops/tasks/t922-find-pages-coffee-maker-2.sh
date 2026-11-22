#!/bin/bash
# **全自動コーヒーメーカー比較の 3 店ボタン: 商品ページの候補（ASIN・楽天の商品 URL）の残り 4 機種（t922・読むだけ・買わない）。**
# t921 で途中に Chrome のページが閉じ、デロンギ 3 機種とツインバード CM-D495B が読めなかった。その 4 つだけをもう一度。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。写真は Mac の手元（private-shots）だけ。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t922-find-pages-coffee-maker-2.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# 商品ページの候補（t922・coffee-maker の残り 4 機種・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
JS="$RDIR/.shop-find-pages.mjs"; git -C "$REPO" show origin/main:scripts/shop/find-product-pages.mjs > "$JS"
SJ0="$RDIR/.shop-coffee-maker-all.json"; git -C "$REPO" show origin/main:src/data/shop/coffee-maker.json > "$SJ0"
[ -s "$JS" ] && [ -s "$SJ0" ] || { echo "⚠️ スクリプトかデータが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
SJ="$RDIR/.shop-coffee-maker-2.json"
KEEP="delonghi-ecam22112b,delonghi-ecam22020b,delonghi-exam44055b,twinbird-cm-d495b" "$NODE_BIN" -e '
const fs=require("fs");const keep=process.env.KEEP.split(",");
const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));d.items=d.items.filter(i=>keep.includes(i.id));
fs.writeFileSync(process.argv[2],JSON.stringify(d));console.log("- 対象 "+d.items.length+" 件: "+d.items.map(i=>i.id).join(", "));' "$SJ0" "$SJ" >> "$OUT" 2>&1
( export SERIES="coffee-maker-2" SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/coffee-maker-2/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
