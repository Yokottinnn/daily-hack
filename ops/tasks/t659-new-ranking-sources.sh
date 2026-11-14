#!/bin/bash
# **新しいランキング記事3本の元データを取る（t659）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者がダイアログで「新しいランキングを書く」を選んだ。候補: 都道府県別の宿泊者数（観光庁 宿泊旅行統計）・温泉の源泉数（環境省 温泉利用状況）・Jリーグのクラブ別観客数（Jリーグ公式データサイト）。
# 入口のページを取り、xlsx/pdf/csv へのリンクを書き出し、候補の URL のファイルも取る。ファイルは reports/t659/ に置く（解析はクラウドで行う）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t659"; mkdir -p "$D"
OUT="$RDIR/t659-new-ranking-sources.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 40 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes $(head -c 5 "$D/$1" | tr -dc 'A-Za-z%<!-')"; sleep 1; }
links(){ "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const L=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,120}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").replace(/\s+/g," ").trim().slice(0,70)}).filter(s=>/\.(pdf|xlsx?|csv|zip)(\?|\s|$)|統計|調査|結果|year|SFTD|search/i.test(s));
[...new Set(L)].slice(0,50).forEach(s=>console.log("  "+s))' "$1" "$2"; }
{
echo "# 新しいランキングの元データ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get kanko_index.html "https://www.mlit.go.jp/kankocho/tokei_hakusyo/shukuhakutokei.html"; links "$D/kanko_index.html" "https://www.mlit.go.jp/kankocho/tokei_hakusyo/shukuhakutokei.html"
get kanko_cand.xlsx "https://www.mlit.go.jp/kankocho/content/002026762.xlsx"
get onsen_index.html "https://www.env.go.jp/nature/onsen/data/index.html"; links "$D/onsen_index.html" "https://www.env.go.jp/nature/onsen/data/index.html"
get onsen_cand.pdf "https://www.env.go.jp/nature/onsen/pdf/6-7_p_1.pdf"
get jl2025.html "https://data.j-league.or.jp/SFTD14/search?competition_year=2025&competition_frame=1"
get jl2025_j2.html "https://data.j-league.or.jp/SFTD14/search?competition_year=2025&competition_frame=2"
get jl2024.html "https://data.j-league.or.jp/SFTD14/search?competition_year=2024&competition_frame=1"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t659 / $(basename "$OUT")"
