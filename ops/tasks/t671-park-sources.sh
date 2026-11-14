#!/bin/bash
# **国立公園の利用者数ランキングの元データ（環境省 自然公園等利用者数調 令和6年）を取る（t671）。読むだけ・LLM 不使用・$0／回・$0／日・$0／月。**
# 2026-11-14 利用者がダイアログで「次のランキングを書く」を選んだ。次の候補の題材。公園別・年次別・都道府県別・ビジターセンター・訪日外国人の推計の Excel と概要の PDF。ファイルは reports/t671/ に置く（解析はクラウドで行う）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t671"; mkdir -p "$D"
OUT="$RDIR/t671-park-sources.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 60 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes $(head -c 5 "$D/$1" | tr -dc 'A-Za-z%<!-')"; sleep 1; }
links(){ "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const L=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,120}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").replace(/\s+/g," ").trim().slice(0,70)}).filter(s=>/\.(pdf|xlsx?|csv|zip)(\?|\s|$)|利用者|統計|調査|data/i.test(s));
[...new Set(L)].slice(0,60).forEach(s=>console.log("  "+s))' "$1" "$2"; }
{
echo "# 国立公園の利用者数の元データ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get np02.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_02.xlsx"
get np03.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_03.xlsx"
get np04.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_04.xlsx"
get np05.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_05.xlsx"
get np06.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_06.xlsx"
get np07.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_07.xlsx"
get np08.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_08.xlsx"
get np09.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_09.xlsx"
get np12.xlsx "https://www.env.go.jp/park/doc/data/natural/naturalpark_12.xlsx"
get np01.pdf "https://www.env.go.jp/park/doc/data/natural/naturalpark_01.pdf"
get np_gaiyo.pdf "https://www.env.go.jp/park/doc/data/natural/naturalpark_gaiyo.pdf"
get np11.pdf "https://www.env.go.jp/park/doc/data/natural/naturalpark_11.pdf"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t671 / $(basename "$OUT")"
