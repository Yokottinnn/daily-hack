#!/bin/bash
# **コンビニの記事の写真を Wikimedia Commons から候補として取る（t654）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者「ランキングの記事は徹底的に調べて…ららぽーとの記事のようなクオリティは絶対に維持」。都道府県ごと・チェーンごとの節に置く写真。
# 自由ライセンス（CC0 / PD / CC BY / CC BY-SA）・横長・幅 1200px 以上だけ、各 3 枚まで。幅 1280px で reports/t654/ に置き、台帳を _manifest.json に残す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t654"; mkdir -p "$D"
OUT="$RDIR/t654-conbini-photos.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)"
: > "$D/.list.txt"; echo "[]" > "$D/_manifest.json"
{
echo "# コンビニの記事の写真候補（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
for pair in "sevosaka|7-Eleven Osaka" "famiaichi|FamilyMart Nagoya" "lawaomori|Lawson Aomori" "lawkochi|Lawson Kochi" "sevhokkaido|Seven-Eleven Sapporo" "seico|Seicomart" "ministop|Ministop Japan" "dailyy|Daily Yamazaki" "newdays|NewDays JR East" "poplar|Poplar convenience store" "store100|Lawson Store 100" "sevfukuoka|7-Eleven Fukuoka" "famkanagawa|FamilyMart Yokohama" "sevsaitama|7-Eleven Saitama" "sevchiba|7-Eleven Chiba" "lawhyogo|Lawson Kobe" "sevshizuoka|7-Eleven Shizuoka" "sevokinawa|7-Eleven Okinawa" "famokinawa|FamilyMart Okinawa" "lawtottori|Lawson Tottori"; do
  key="${pair%%|*}"; q="${pair#*|}"
  enc=$("$NODE_BIN" -e 'console.log(encodeURIComponent(process.argv[1]+" filetype:bitmap"))' "$q")
  curl -sS -m 40 -A "$UA" "https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=6&gsrsearch=$enc&gsrlimit=30&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&iiurlwidth=1280" -o "$D/.api.json"
  "$NODE_BIN" -e '
const fs=require("fs");const [D,key]=process.argv.slice(1);let j;try{j=JSON.parse(fs.readFileSync(D+"/.api.json","utf8"))}catch(e){console.log(key+": API が読めない "+fs.readFileSync(D+"/.api.json","utf8").slice(0,120));process.exit(0)}
const ok=/^(CC0|Public domain|CC BY(-SA)? [0-9.]+)/i;const rows=[];
for(const p of Object.values(j.query?.pages||{}).sort((a,b)=>(a.index||0)-(b.index||0))){const i=p.imageinfo?.[0];if(!i||i.width<1200||i.width<i.height*1.2)continue;const m=i.extmetadata||{};const lic=(m.LicenseShortName||{}).value||"";if(!ok.test(lic))continue;
 rows.push({file:p.title,thumb:i.thumburl,page:i.descriptionurl,w:i.width,h:i.height,lic,artist:String((m.Artist||{}).value||"").replace(/<[^>]+>/g,"").trim().slice(0,80),date:String((m.DateTimeOriginal||{}).value||"").replace(/<[^>]+>/g,"").slice(0,20)})}
const pick=rows.slice(0,3);pick.forEach((r,k)=>r.key=key+(k+1));
const man=JSON.parse(fs.readFileSync(D+"/_manifest.json","utf8"));fs.writeFileSync(D+"/_manifest.json",JSON.stringify(man.concat(pick),null,2));
fs.appendFileSync(D+"/.list.txt",pick.map(r=>r.key+" "+r.thumb).join("\n")+(pick.length?"\n":""));
console.log(key+": 候補 "+rows.length+" 件 / 取る "+pick.length+" 件");pick.forEach(r=>console.log("  "+r.key+" | "+r.file+" | "+r.w+"x"+r.h+" | "+r.lic+" | "+r.artist))' "$D" "$key"
  sleep 2
done
n=0; t=0; while IFS=' ' read -r k u || [ -n "$k" ]; do [ -z "$k" ] && continue; t=$((t+1)); curl -sS -m 40 -A "$UA" -o "$D/$k.jpg" "$u" && n=$((n+1)); sleep 1; done < "$D/.list.txt"
echo "対象 $t 枚 / 取得 $n 枚"; ls -la "$D" | awk '{print $5, $9}' | grep jpg
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
rm -f "$D/.api.json" "$D/.list.txt"
echo "t654 / $(basename "$OUT")"
