#!/bin/bash
# **温泉とJリーグの記事の「推移」の元データを取る（t665）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者がダイアログで「温泉の源泉数」「Jリーグの観客数」を選んだ。2つ目の軸（推移）のため。
# 環境省の温泉利用状況の経年変化表（t659 で入口のページから拾ったリンク）と、Jリーグ公式データサイトの J1 の各年（2015〜2023年）と J3 の 2025 年の入場者数のページ（t659 と同じ URL の年だけを変えたもの）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t665"; mkdir -p "$D"
OUT="$RDIR/t665-onsen-jl-history.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 40 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes"; sleep 1; }
{
echo "# 温泉とJリーグの推移の元データ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get onsen_trend.pdf "https://www.env.go.jp/nature/onsen/pdf/6-7_p_3.pdf"
get onsen_hist.pdf "https://www.env.go.jp/nature/onsen/pdf/6-7_p_2.pdf"
for y in 2015 2016 2017 2018 2019 2020 2021 2022 2023; do get "jl$y.html" "https://data.j-league.or.jp/SFTD14/search?competition_year=$y&competition_frame=1"; done
get jl2025_j3.html "https://data.j-league.or.jp/SFTD14/search?competition_year=2025&competition_frame=3"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t665 / $(basename "$OUT")"
