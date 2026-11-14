#!/bin/bash
# **駅の乗降客数（乗車人員）の公式ページを読む（t622）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者がダイアログで「駅の乗降客数を Mac で確かめる」を選んだ。クラウドからは JR東日本・東京メトロが 403 で読めない。
# JR東日本「各駅の乗車人員」と東京メトロ「各駅の乗降人員ランキング」の HTML を取り、表の行（駅名と数字）を文字にして reports/t622/ に置く。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t622"; mkdir -p "$D"
OUT="$RDIR/t622-station-ridership.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
{
echo "# 駅の乗降客数の公式ページ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
for pair in "jre-top|https://www.jreast.co.jp/passenger/" "jre-2024|https://www.jreast.co.jp/passenger/index.html" "metro|https://www.tokyometro.jp/corporate/enterprise/passenger_rail/transportation/passengers/index.html"; do
  key="${pair%%|*}"; url="${pair#*|}"
  code=$(curl -sS -L -m 30 -A "$UA" -H "Accept-Language: ja" -o "$D/$key.html" -w "%{http_code}" "$url"); sz=$(wc -c < "$D/$key.html" | tr -d ' ')
  echo "$key $url → HTTP $code / $sz bytes"
done
"$NODE_BIN" -e '
const fs=require("fs");const D=process.argv[1];
for(const k of ["jre-top","jre-2024","metro"]){let h="";try{h=fs.readFileSync(D+"/"+k+".html","utf8")}catch(e){continue}
 const title=(h.match(/<title>([^<]*)/)||[])[1]||"";console.log("\n## "+k+" | "+title.trim());
 const links=[...h.matchAll(/<a[^>]+href="([^"]+)"[^>]*>([^<]{2,60})<\/a>/g)].filter(m=>/乗車人員|乗降人員|20[12][0-9]|ランキング|pdf/i.test(m[2]+m[1])).slice(0,30);
 links.forEach(m=>console.log("LINK "+m[2].trim()+" -> "+m[1]));
 const rows=[...h.matchAll(/<tr[^>]*>([\s\S]*?)<\/tr>/g)].map(m=>m[1].replace(/<[^>]+>/g," ").replace(/&nbsp;/g," ").replace(/\s+/g," ").trim()).filter(r=>/[0-9,]{4,}/.test(r));
 console.log("表の行 "+rows.length+" 行（先頭 120 行）");rows.slice(0,120).forEach(r=>console.log("ROW "+r));
 fs.writeFileSync(D+"/"+k+".rows.txt",rows.join("\n")+"\n");}
' "$D"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
rm -f "$D"/*.html
echo "t622 / $(basename "$OUT")"
