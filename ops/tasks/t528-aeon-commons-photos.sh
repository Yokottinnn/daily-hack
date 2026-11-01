#!/bin/bash
# **イオンモールの記事（全国の施設を総賃貸面積で並べる）の表紙と各節の写真を、Wikimedia Commons から候補として取る（t528）。読むだけ・LLM 不使用・$0。**
# 作戦室で利用者が選んだ構想「イオンモール売上ランキング」（2026-10-22）。2026-11-01 に公式サイトが戻ったので着手した。クラウドからは Commons が 429 で読めないので Mac で取る。
# 施設ごとに自由ライセンス（CC0 / PD / CC BY / CC BY-SA）の横長写真を最大 3 枚、幅 1280px で reports/t528/ に置き、ライセンス台帳を _manifest.json に残す。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t528"; mkdir -p "$D"
OUT="$RDIR/t528-aeon-commons.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)"
Q=(
"makuhari|AEON Mall Makuhari"
"kashihara|AEON Mall Kashihara"
"shinrifu|AEON Mall Shinrifu"
"laketown|Aeon Lake Town"
"fuchu|AEON Mall Hiroshima Fuchu"
"okayama|AEON Mall Okayama"
"fukuoka|AEON Mall Fukuoka"
"tokoname|AEON Mall Tokoname"
"rycom|AEON Mall Okinawa Rycom"
"mozo|mozo wondercity"
)
{
echo "# イオンモールの写真候補（t528・$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
: > "$D/.list.txt"; echo '[]' > "$D/_manifest.json"
for e in "${Q[@]}"; do
  key="${e%%|*}"; q="${e#*|}"
  enc="$("$NODE_BIN" -e 'process.stdout.write(encodeURIComponent(process.argv[1]+" filetype:bitmap"))' "$q")"
  curl -sS -m 40 -A "$UA" "https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=6&gsrsearch=$enc&gsrlimit=30&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&iiurlwidth=1280" -o "$D/.api.json"
  "$NODE_BIN" -e '
const fs=require("fs");const [D,key]=process.argv.slice(1);let j;try{j=JSON.parse(fs.readFileSync(D+"/.api.json","utf8"))}catch(e){console.log(key+": API が読めない");process.exit(0)}
const ok=/^(CC0|Public domain|CC BY(-SA)? [0-9.]+)/i;const rows=[];
for(const p of Object.values(j.query?.pages||{})){const i=p.imageinfo?.[0];if(!i||i.width<1000||i.width<i.height)continue;const m=i.extmetadata||{};const lic=(m.LicenseShortName||{}).value||"";if(!ok.test(lic))continue;
 rows.push({file:p.title,thumb:i.thumburl,page:i.descriptionurl,w:i.width,h:i.height,lic,artist:String((m.Artist||{}).value||"").replace(/<[^>]+>/g,"").trim().slice(0,80),date:String((m.DateTimeOriginal||{}).value||"").replace(/<[^>]+>/g,"").slice(0,20)})}
const pick=rows.slice(0,3);pick.forEach((r,k)=>r.key=key+(k+1));
const man=JSON.parse(fs.readFileSync(D+"/_manifest.json","utf8"));fs.writeFileSync(D+"/_manifest.json",JSON.stringify(man.concat(pick),null,2));
fs.appendFileSync(D+"/.list.txt",pick.map(r=>r.key+" "+r.thumb).join("\n")+(pick.length?"\n":""));
console.log(key+": 候補 "+rows.length+" 件 / 取る "+pick.length+" 件");pick.forEach(r=>console.log("  "+r.key+" | "+r.file+" | "+r.w+"x"+r.h+" | "+r.lic+" | "+r.artist+" | "+r.date))' "$D" "$key"
  sleep 2
done
n=0; while IFS=' ' read -r k u || [ -n "$k" ]; do [ -z "$k" ] && continue; curl -sS -m 40 -A "$UA" -o "$D/$k.jpg" "$u" && n=$((n+1)); sleep 1; done < "$D/.list.txt"
echo "取得 $n 件"; ls -la "$D" | awk '{print $5, $9}' | grep jpg
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
rm -f "$D/.api.json" "$D/.list.txt"
echo "t528 / $(basename "$OUT")"
