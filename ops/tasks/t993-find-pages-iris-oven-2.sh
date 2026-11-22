#!/bin/bash
# **オーブンレンジ比較記事のアイリスを「3 店で売っている機種」に替えるため、MO-F2404・MS-F3003-B・MO-F1808-B が Amazon・楽天で売られているかを調べる（t993・読むだけ・買わない）。**
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。t990・t992 で MS-F2601-B は Amazon だけ（楽天・Yahoo! に無い）と分かった。楽天・Yahoo! の検索で多く出たのが MO-F2404・MS-F3003-B・MO-F1808/1812。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。写真は Mac の手元（private-shots）だけ。シリーズ: oven-range-iris2
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t993-find-pages-iris-oven.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# アイリスのオーブンレンジ 商品ページの候補 2（t993・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SJ="$RDIR/.shop-oven-range-iris2.json"
cat > "$SJ" <<'J'
{"id":"oven-range-iris2","items":[
 {"id":"iris-mo-f2404","rakuten":{"keyword":"アイリスオーヤマ MO-F2404","must":["F2404"],"exclude":["角皿","トレー","カバー","部品","専用"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MO-F2404"}},
 {"id":"iris-ms-f3003","rakuten":{"keyword":"アイリスオーヤマ MS-F3003-B","must":["MS-F3003"],"exclude":["角皿","トレー","カバー","部品","専用"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MS-F3003-B"}},
 {"id":"iris-mo-f1808","rakuten":{"keyword":"アイリスオーヤマ MO-F1808-B","must":["MO-F1808"],"exclude":["角皿","トレー","カバー","部品","専用"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MO-F1808-B"}}
]}
J
[ -s "$JS" ] || { echo "⚠️ スクリプトが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="oven-range-iris2" SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/oven-range-iris2/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
