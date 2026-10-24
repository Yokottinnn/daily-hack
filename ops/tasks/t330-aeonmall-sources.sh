#!/bin/bash
# **イオンモールの記事の元データを取る（t330・読むだけ）。**
# 利用者（2026-10-24）が作戦室で選んだ構想「イオンモール売上ランキング」。繊研の全順位は有料なので、
# 「公開されている売上＋面積・店舗数」で組むと決めた。クラウドからは aeonmall.com が 10/24 にメンテナンス表示、
# 各モールのサイトと Wikipedia は届かなかったので、Mac で取る。
#
#   ① aeonmall.com のトップと IR の入口（メンテナンス中かどうか・リンクの一覧）
#   ② 決算説明資料の PDF（2025 年度・2024 年度）とファクトブック類（リンクに factbook / databook があれば）
#   ③ Wikipedia「イオンモール」「イオンモールの店舗一覧」系のウィキテキスト（API）
#
# 出力は $OPS_REPORT_DIR/aeon/ に置く（heartbeat が push する）。PDF は公開の IR 資料。
# ## 費用（最上位ルール 2-B）: LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（1 回きり）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
D="$RDIR/aeon"; mkdir -p "$D"
OUT="$RDIR/t330-aeonmall-sources.md"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36'
{ echo "# イオンモールの元データ（t330・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
get(){ # $1=URL $2=保存名
  local code; code="$(curl -sS -L -m 60 -A "$UA" -o "$D/$2" -w '%{http_code} %{size_download}' "$1" 2>&1 | tail -1)"
  echo "- \`$2\` ← $1 : **$code**" >> "$OUT"
}
echo "## ① 入口" >> "$OUT"
get https://www.aeonmall.com/ top.html
get https://www.aeonmall.com/ir/ ir.html
get https://www.aeonmall.com/ir/library/ ir-library.html
if grep -q 'メンテナンス中' "$D/top.html" 2>/dev/null; then echo "- ⚠️ まだメンテナンス中" >> "$OUT"; fi
# リンクの一覧（mall / ir / pdf を含むもの）
for f in top.html ir.html ir-library.html; do
  [ -s "$D/$f" ] || continue
  grep -Eo 'href="[^"]+"' "$D/$f" | sed 's/^href="//;s/"$//' | grep -Ei 'mall|ir/|\.pdf|fact|data|shop|list' | sort -u > "$D/links-$f.txt"
  echo "- $f のリンク: $(wc -l < "$D/links-$f.txt" | tr -d ' ') 件" >> "$OUT"
done
echo >> "$OUT"; echo "## ② IR 資料" >> "$OUT"
get https://www.aeonmall.com/ir/pdf/presentations/202605.pdf presentation-202605.pdf
get https://www.aeonmall.com/ir/pdf/ircalendar/01.pdf presentation-202504.pdf
# ライブラリにファクトブック・データブックがあれば取る（最大 4 本）
n=0
for f in "$D"/links-*.txt; do [ -s "$f" ] || continue; cat "$f"; done 2>/dev/null | grep -Ei 'fact|databook|data_book|data-book' | sort -u | while IFS= read -r u || [ -n "$u" ]; do
  n=$((n+1)); [ $n -le 4 ] || break
  case "$u" in http*) ;; /*) u="https://www.aeonmall.com$u" ;; *) continue ;; esac
  get "$u" "fact-$n.$( [ "${u##*.}" = pdf ] && echo pdf || echo html )"
done
for f in "$D"/*.pdf; do [ -f "$f" ] || continue; echo "- $(basename "$f") 先頭: $(head -c 5 "$f" | tr -dc '[:print:]')" >> "$OUT"; done
echo >> "$OUT"; echo "## ③ Wikipedia" >> "$OUT"
W='https://ja.wikipedia.org/w/api.php?action=parse&prop=wikitext&format=json&page='
get "${W}%E3%82%A4%E3%82%AA%E3%83%B3%E3%83%A2%E3%83%BC%E3%83%AB" wp-aeonmall.json
sleep 2
get "${W}%E3%82%A4%E3%82%AA%E3%83%B3%E3%83%A2%E3%83%BC%E3%83%AB%E3%81%AE%E5%BA%97%E8%88%97%E4%B8%80%E8%A6%A7" wp-aeonmall-list.json
echo >> "$OUT"; echo '```text' >> "$OUT"; ls -la "$D" >> "$OUT"; echo '```' >> "$OUT"
cat "$OUT"
