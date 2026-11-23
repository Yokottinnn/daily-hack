#!/bin/bash
# **ノンフライヤーの比較記事の材料: アイリスオーヤマ FV-M30A-C の取扱説明書（PDF）・発売の知らせ・商品サポートのページを取る（t1213）。** 読むだけ・LLM 不使用・$0／回・$0／日・$0／月。
# 2026-11-24 blog3 の air-fryer-comparison-2026。irisohyama.co.jp はクラウドから 403 になるので Mac から取る。URL は t1211 の検索結果に出た公式のものだけ（組み立てない）。
# 取扱説明書は公開されている PDF なので reports/t1213/ にそのまま置く（クラウドで容量・空ける距離・食器洗い乾燥機の可否を読む）。ログインの要るページは開かない。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t1213-iris-air-fryer-docs.md"
D="$RDIR/t1213"; rm -rf "$D"; mkdir -p "$D"
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
{ echo "# アイリスオーヤマ FV-M30A-C の公式資料（t1213・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
get() {  # key url
  local c
  c=$(curl -sL -m 40 -A "$UA" -o "$D/$1" -w "%{http_code} %{size_download} %{content_type} %{url_effective}" "$2")
  echo "- $1: $c" >> "$OUT"
}
get iris-manual.pdf "https://www.irisohyama.co.jp/products/manual/pdf/113158.pdf"
get iris-news.html "https://www.irisohyama.co.jp/news/2025/?date=1208"
get iris-support.html "https://www.irisohyama.co.jp/products/support/4967576809078"
get iris-flier.html "https://www.irisohyama.co.jp/products/electrical-appliances/cooking-appliances/flyer-toaster/flyer/air-flier"
echo "" >> "$OUT"
if [ -n "$NODE_BIN" ]; then
  for f in iris-news iris-support iris-flier; do
    [ -s "$D/$f.html" ] || continue
    "$NODE_BIN" -e '
const fs=require("fs");let h=fs.readFileSync(process.argv[1],"utf8");
h=h.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/g,"").replace(/<br\s*\/?>/g,"\n").replace(/<[^>]+>/g,"\n").replace(/&nbsp;/g," ").replace(/&amp;/g,"&");
const t=h.split("\n").map(s=>s.trim()).filter(Boolean).join("\n");fs.writeFileSync(process.argv[2],t);' "$D/$f.html" "$D/$f.txt"
    echo "### $f.txt（$(wc -c < "$D/$f.txt" | tr -d ' ') bytes）" >> "$OUT"
    grep -nE "FV-M30A|容量|消費電力|価格|円|発売|食器洗|L）|リットル" "$D/$f.txt" | head -40 >> "$OUT"
    echo "" >> "$OUT"
  done
  rm -f "$D"/*.html
fi
ls -la "$D" | awk '{print $5, $9}' >> "$OUT"
echo "" >> "$OUT"; echo "**読むだけ。LLM 不使用（\$0／回）。**" >> "$OUT"
cat "$OUT"
