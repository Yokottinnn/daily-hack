#!/bin/bash
# **東京の地下鉄（東京メトロ・都営）の駅別乗降人員の元データを取る（t675）。読むだけ・LLM 不使用・$0／回・$0／日・$0／月。**
# 2026-11-14 利用者がダイアログで「次のランキングを書く」を選んだ。次の候補の題材。両社の公式の駅別乗降人員のページと、そこから張られた表（PDF・Excel）。ファイルは reports/t675/ に置く（解析はクラウドで行う）。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t675"; mkdir -p "$D"
OUT="$RDIR/t675-metro-sources.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
get(){ code=$(curl -sS -L -m 60 -A "$UA" -o "$D/$1" -w '%{http_code}' "$2" 2>&1 | tail -c 40); echo "$1 ← $2 → $code $(wc -c < "$D/$1" 2>/dev/null) bytes $(head -c 5 "$D/$1" | tr -dc 'A-Za-z%<!-')"; sleep 1; }
links(){ "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const L=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,120}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").replace(/\s+/g," ").trim().slice(0,70)}).filter(s=>/\.(pdf|xlsx?|csv|zip)(\?|\s|$)|利用者|統計|調査|data/i.test(s));
[...new Set(L)].slice(0,60).forEach(s=>console.log("  "+s))' "$1" "$2"; }
{
echo "# 東京の地下鉄の駅別乗降人員の元データ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
get metro.html "https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html"; links "$D/metro.html" "https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html"
get toei.html "https://www.kotsu.metro.tokyo.jp/subway/kanren/passengers.html"; links "$D/toei.html" "https://www.kotsu.metro.tokyo.jp/subway/kanren/passengers.html"
# 張られた PDF / Excel を 8 本まで取る
for f in metro toei; do
  "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const L=[...h.matchAll(/href="([^"]+\.(?:pdf|xlsx?|csv))"/gi)].map(m=>{try{return new URL(m[1],base).href}catch(e){return ""}}).filter(Boolean);
[...new Set(L)].slice(0,8).forEach((u,i)=>console.log(i+" "+u))' "$D/$f.html" "$([ $f = metro ] && echo https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html || echo https://www.kotsu.metro.tokyo.jp/subway/kanren/passengers.html)" > "$D/.$f-files.txt"
  while read -r i u || [ -n "$i" ]; do [ -z "$i" ] && continue; ext="${u##*.}"; get "$f-$i.$ext" "$u"; done < "$D/.$f-files.txt"
done
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t675 / $(basename "$OUT")"
