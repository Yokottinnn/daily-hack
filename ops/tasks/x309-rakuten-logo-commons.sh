#!/bin/bash
# **楽天市場（日本版）のロゴを Wikimedia Commons から取る。費用 $0。**
# 記事と X 画像のロゴが台湾版「樂天市場」だった（利用者の指摘・2026-10-17）。楽天のトップには漢字のロゴが無い（x308）。
# MediaWiki API で「Rakuten」のロゴのファイルを探し、ファイル名・ライセンス・実体 URL と、PNG（幅 1200）を保存する。
set -uo pipefail
RD="${OPS_REPORT_DIR:-/tmp}"
OUT="$RD/rakuten-logo-commons.md"
D="$RD/x309-logo"; mkdir -p "$D"
API="https://commons.wikimedia.org/w/api.php"
{
echo "# 楽天のロゴ（Wikimedia Commons）（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
curl -s --max-time 20 -A "daily-hack-ops/1.0" "$API?action=query&list=search&srsearch=Rakuten%20logo&srnamespace=6&srlimit=15&format=json" \
 | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));for(const s of j.query.search)console.log(s.title)' > "$D/titles.txt" 2>&1
cat "$D/titles.txt"
echo '```'
echo
n=0
while IFS= read -r t || [ -n "$t" ]; do
  case "$t" in *[Ll]ogo*|*楽天*) ;; *) continue;; esac
  n=$((n+1)); [ $n -gt 6 ] && break
  info="$(curl -s --max-time 20 -A "daily-hack-ops/1.0" -G "$API" --data-urlencode "titles=$t" --data "action=query&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=1200&format=json")"
  echo "$info" | node -e '
const j=JSON.parse(require("fs").readFileSync(0,"utf8"));const p=Object.values(j.query.pages)[0];const ii=(p.imageinfo||[])[0]||{};const m=ii.extmetadata||{};
console.log("### "+p.title);console.log("- ライセンス: "+((m.LicenseShortName||{}).value||"?")+" / "+((m.UsageTerms||{}).value||""));console.log("- 実体: "+ii.url);console.log("- 幅1200: "+ii.thumburl);
require("fs").writeFileSync(process.argv[1], ii.thumburl||"")' "$D/u$n.txt"
  u="$(cat "$D/u$n.txt")"; [ -n "$u" ] && curl -s --max-time 20 -A "daily-hack-ops/1.0" -o "$D/logo$n.png" "$u" && echo "- 保存: x309-logo/logo$n.png（$(wc -c < "$D/logo$n.png" | tr -d ' ') bytes）"
  rm -f "$D/u$n.txt"
done < "$D/titles.txt"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "楽天のロゴを Commons から取った / $(basename "$OUT")"
