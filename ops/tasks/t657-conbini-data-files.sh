#!/bin/bash
# **コンビニの記事の数字の元ファイルを取る（t657）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者「ランキングの記事は徹底的に調べて…ららぽーとの記事のようなクオリティは絶対に維持」。
# t655 で入口のページから拾ったリンクだけを取る（URL を推測で組まない）。JFA のコンビニ統計（2025年の年間集計・2026年9月度）、
# 総務省の人口推計の都道府県別人口（2025年10月1日の版があればそれ、無ければ t655 で見えた 2024年版）、セブンの売上・店舗数の推移と「データで見る」、
# ファミマの月次営業報告、ミニストップの月次営業報告、ポプラの月次業績。ファイルをそのまま reports/t657/ に置く（解析はクラウドで行う）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t657"; mkdir -p "$D"
OUT="$RDIR/t657-conbini-data-files.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 40 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes"; sleep 1; }
{
echo "# コンビニの数字の元ファイル（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get jfa2025.pdf "https://www.jfa-fc.or.jp/folder/1/img/20260120121124.pdf"
get jfa2024.pdf "https://www.jfa-fc.or.jp/folder/1/img/20250120103927.pdf"
get jfa202609.pdf "https://www.jfa-fc.or.jp/folder/1/img/20261020101918.pdf"
get stat2025.html "https://www.stat.go.jp/data/jinsui/2025np/index.html"
x=$(grep -o 'zuhyou/[^"]*-2\.xlsx' "$D/stat2025.html" 2>/dev/null | head -1)
if [ -n "$x" ]; then get pop.xlsx "https://www.stat.go.jp/data/jinsui/2025np/$x"; else echo "2025年版の第2表が見つからない → 2024年版"; get pop.xlsx "https://www.stat.go.jp/data/jinsui/2024np/zuhyou/05k2024-2.xlsx"; fi
get sej_suii.html "https://www.sej.co.jp/company/suii.html"
get sej_data.html "https://www.sej.co.jp/company/data/index.html"
get sej_enkaku.html "https://www.sej.co.jp/company/enkaku.html"
get fami_monthly.html "https://www.family.co.jp/company/familymart/monthly_sales.html"
get fami_history.html "https://www.family.co.jp/company/familymart/development01.html"
get lawson_history.html "https://www.lawson.co.jp/company/corporate/data/history/"
get ministop_results.html "https://www.ministop.co.jp/corporate/ir/finance/results/"
get poplar202610.pdf "https://www.poplar-cvs.co.jp/ir/pdf/index/2026/tsukiji261110.pdf"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t657 / $(basename "$OUT")"
