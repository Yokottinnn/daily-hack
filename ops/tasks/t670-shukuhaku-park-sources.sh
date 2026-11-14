#!/bin/bash
# **宿泊者数ランキングの比べる年の数字と、次の候補（国立公園の利用者数）の入口を取る（t670）。読むだけ・LLM 不使用・$0／回・$0／日・$0／月。**
# 2026-11-14 利用者がダイアログで「次のランキングを書く」を選んだ。観光庁 宿泊旅行統計調査の 2024 年・2019 年の年の確定値と推移表、環境省の自然公園等利用者数の入口。ファイルは reports/t670/ に置く（解析はクラウドで行う）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t670"; mkdir -p "$D"
OUT="$RDIR/t670-shukuhaku-park-sources.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 60 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes $(head -c 5 "$D/$1" | tr -dc 'A-Za-z%<!-')"; sleep 1; }
links(){ "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const L=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,120}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").replace(/\s+/g," ").trim().slice(0,70)}).filter(s=>/\.(pdf|xlsx?|csv|zip)(\?|\s|$)|利用者|統計|調査|data/i.test(s));
[...new Set(L)].slice(0,60).forEach(s=>console.log("  "+s))' "$1" "$2"; }
{
echo "# 宿泊者数の比べる年と国立公園の入口（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get kanko2024.xlsx "https://www.mlit.go.jp/kankocho/content/002026764.xlsx"
get kanko2019.xlsx "https://www.mlit.go.jp/kankocho/content/002026792.xlsx"
get kanko_suii.xlsx "https://www.mlit.go.jp/kankocho/content/002028776.xlsx"
get kanko2025.pdf "https://www.mlit.go.jp/kankocho/content/002026763.pdf"
get park_doc.html "https://www.env.go.jp/park/doc/data.html"; links "$D/park_doc.html" "https://www.env.go.jp/park/doc/data.html"
get park_top.html "https://www.env.go.jp/park/"; links "$D/park_top.html" "https://www.env.go.jp/park/"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t670 / $(basename "$OUT")"
