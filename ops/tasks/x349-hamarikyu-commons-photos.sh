#!/bin/bash
# **浜離宮恩賜庭園の写真を Wikimedia Commons から候補として取る（x349）。読むだけ・LLM 不使用・$0。**
# 利用者の指示で書くチームラボ浜離宮の記事用。クラウドからは Commons が 429 で読めないので Mac で取る。
# 自由ライセンス（CC0 / PD / CC BY / CC BY-SA）の写真を最大 10 枚、幅 1280px で reports/x349/ に置き、ライセンス台帳を _manifest.json に残す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/x349"; mkdir -p "$D"
OUT="$RDIR/x349-hamarikyu-commons.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)"
API="https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=6&gsrsearch=Hamarikyu%20Gardens%20filetype%3Abitmap&gsrlimit=40&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&iiurlwidth=1280"
curl -sS -m 40 -A "$UA" "$API" -o "$D/.api.json"
{
echo "# 浜離宮恩賜庭園の写真候補（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const D=process.argv[1];let j;try{j=JSON.parse(fs.readFileSync(D+"/.api.json","utf8"))}catch(e){console.log("API が読めない: "+fs.readFileSync(D+"/.api.json","utf8").slice(0,200));process.exit(0)}
const ok=/^(CC0|Public domain|CC BY(-SA)? [0-9.]+)/i;const rows=[];
for(const p of Object.values(j.query?.pages||{})){const i=p.imageinfo?.[0];if(!i||i.width<1200||i.width<i.height)continue;const m=i.extmetadata||{};const lic=(m.LicenseShortName||{}).value||"";if(!ok.test(lic))continue;
 rows.push({file:p.title,thumb:i.thumburl,page:i.descriptionurl,w:i.width,h:i.height,lic,artist:String((m.Artist||{}).value||"").replace(/<[^>]+>/g,"").trim().slice(0,80),date:String((m.DateTimeOriginal||{}).value||"").replace(/<[^>]+>/g,"").slice(0,20)})}
const pick=rows.slice(0,10);pick.forEach((r,k)=>r.key="hm"+(k+1));
fs.writeFileSync(D+"/_manifest.json",JSON.stringify(pick,null,2));
fs.writeFileSync(D+"/.list.txt",pick.map(r=>r.key+" "+r.thumb).join("\n")+"\n");
console.log("候補 "+rows.length+" 件 / 取る "+pick.length+" 件");pick.forEach(r=>console.log(r.key+" | "+r.file+" | "+r.w+"x"+r.h+" | "+r.lic+" | "+r.artist+" | "+r.date))' "$D"
n=0; while IFS=' ' read -r k u || [ -n "$k" ]; do [ -z "$k" ] && continue; curl -sS -m 40 -A "$UA" -o "$D/$k.jpg" "$u" && n=$((n+1)); sleep 1; done < "$D/.list.txt"
echo "取得 $n 件"; ls -la "$D" | awk '{print $5, $9}' | grep jpg
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
rm -f "$D/.api.json" "$D/.list.txt"
echo "x349 / $(basename "$OUT")"
