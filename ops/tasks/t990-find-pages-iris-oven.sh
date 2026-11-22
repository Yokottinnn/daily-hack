#!/bin/bash
# **オーブンレンジ比較記事のアイリスオーヤマを「売っている機種」に替えるため、公式で販売中の 4 機種が Amazon・楽天で売られているかを調べる（t990・読むだけ・買わない）。**
# 2026-11-22 利用者がダイアログで「オーブンレンジのアイリスを売っている機種に替える」を選んだ。MS-F3002-B は t912 で楽天・Amazon に型番の商品が出なかった。
# 候補は公式のスチームオーブンレンジ一覧（t910）にある MS-F2601-B（26L タンク式）・MS-2402（24L タンク式過熱水蒸気）・MO-FS3001-B（30L カップ式）・MO-FS2601-B（26L カップ式）。
# 本体は scripts/shop/find-product-pages.mjs（origin/main から取り出す）。写真は Mac の手元（private-shots）だけ。シリーズ: oven-range-iris
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t990-find-pages-iris-oven.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
{ echo "# アイリスのオーブンレンジ 商品ページの候補（t990・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
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
SJ="$RDIR/.shop-oven-range-iris.json"
cat > "$SJ" <<'J'
{"id":"oven-range-iris","items":[
 {"id":"iris-ms-f2601","rakuten":{"keyword":"アイリスオーヤマ MS-F2601-B","must":["MS-F2601"],"exclude":["角皿","トレー","カバー","部品"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MS-F2601-B"}},
 {"id":"iris-ms-2402","rakuten":{"keyword":"アイリスオーヤマ MS-2402","must":["MS-2402"],"exclude":["角皿","トレー","カバー","部品"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MS-2402"}},
 {"id":"iris-mo-fs3001","rakuten":{"keyword":"アイリスオーヤマ MO-FS3001-B","must":["MO-FS3001"],"exclude":["角皿","トレー","カバー","部品"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MO-FS3001-B"}},
 {"id":"iris-mo-fs2601","rakuten":{"keyword":"アイリスオーヤマ MO-FS2601-B","must":["MO-FS2601"],"exclude":["角皿","トレー","カバー","部品"]},"amazon":{"keyword":"アイリスオーヤマ スチームオーブンレンジ MO-FS2601-B"}}
]}
J
[ -s "$JS" ] || { echo "⚠️ スクリプトが main に無い" >> "$OUT"; cat "$OUT"; exit 1; }
( export SERIES="oven-range-iris" SHOP_JSON="$SJ" OPS_REPORT_DIR="$RDIR" FIND_BUDGET_MS=230000; run_limited 270 "$NODE_BIN" "$JS" ) >> "$OUT" 2>&1
echo "- rc=$?" >> "$OUT"
cat "$RDIR/shop-pages/oven-range-iris/report.md" >> "$OUT" 2>/dev/null || echo "（report.md が無い）" >> "$OUT"
cat "$OUT"
