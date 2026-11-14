#!/bin/bash
# **Jリーグの記事の追加データ（年度別の入場者推移・試合ごとの入場者一覧）を取る（t666）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者がダイアログで「Jリーグの観客数」のランキングを選んだ。t659 で取ったクラブ別入場者数（SFTD14）のページのメニューにある
# 「年度別入場者推移（/SFTD12/）」と「入場者一覧（/SFTD11/）」を取る。入口のページと、SFTD14 と同じ形の検索 URL を試し、フォームの項目名も書き出す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t666"; mkdir -p "$D"
OUT="$RDIR/t666-jl-more-data.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
B="https://data.j-league.or.jp"
get(){ code=$(curl -sS -L -m 40 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes"; grep -o 'name="[a-z_]*"' "$D/$1" 2>/dev/null | sort -u | tr '\n' ' '; echo; sleep 1; }
{
echo "# Jリーグの追加データ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get sftd12.html "$B/SFTD12/"
get sftd12_j1.html "$B/SFTD12/search?competition_frame=1"
get sftd11.html "$B/SFTD11/"
get sftd11_2025_j1.html "$B/SFTD11/search?competition_year=2025&competition_frame=1"
get sftd11_2025_j1_b.html "$B/SFTD11/search?competition_years=2025&competition_frame_ids=1"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t666 / $(basename "$OUT")"
