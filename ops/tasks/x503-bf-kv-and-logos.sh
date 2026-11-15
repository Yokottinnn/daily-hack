#!/bin/bash
# x503（2026-11-15・読むだけ・$0）: ブラックフライデーまとめの X 告知を利用者のコメントで直す材料を取る。
#  ① 表紙（9 枚のタイル）: 3 連休（11/21〜23）にイベントがある 9 施設の公式ブラックフライデーページから、告知画像（og:image / twitter:image）を取る
#  ② 足りないロゴ 7 件: 公式サイトの logo の img・link と、ウィキメディア・コモンズの「<名前> logo」から候補を取る（最上位ルール 17）
# 利用者「表紙の画像として…9つぐらいタイル型でまとめていろんな施設のブラックフライデーの告知画像をまとめてもいいかも」「アイコンが取得できていないものは公式サイトやそのほかサイト等から必ず取得してきて」
# 公開ページだけ。ログインしない。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/x503"; mkdir -p "$D"
OUT="$RDIR/x503-bf-kv-and-logos.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
abs() { "$NODE_BIN" -e 'try{console.log(new URL(process.argv[1],process.argv[2]).href)}catch(e){}' "$1" "$2"; }
{
echo "# ブラックフライデーの告知画像とロゴの候補（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① 告知画像"; echo '```'
for pair in "mop|https://mitsui-shopping-park.com/mop/special/2611_blackfriday/" "aeonmall|https://lp.aeonmall.com/lp/blackfriday/" "uniqlo|https://www.uniqlo.com/jp/ja/special-feature/kanshasai" "donki|https://www.majica-net.com/campaign/2026_blackfriday/" "hanayashiki|https://www.hanayashiki.net/events/event/BlackFriday2026/" "cainz|https://www.cainz.com/contents/sale/blackfriday.html" "ohsho|https://www.ohsho.co.jp/info/2026/1120232026.html" "toysrus|https://www.toysrus.co.jp/ja-jp/promotions/blackfriday-toy/" "hands|https://hands.net/season/black-friday/"; do
  k="${pair%%|*}"; u="${pair#*|}"
  curl -sSL -m 25 -A "$UA" -o "$D/.p.html" "$u"; sz=$(wc -c < "$D/.p.html" | tr -d ' ')
  cands=$("$NODE_BIN" -e '
const h=require("fs").readFileSync(process.argv[1],"utf8");const out=[];
for(const re of [/<meta[^>]+(?:property|name)=["\x27](?:og:image|twitter:image)(?::src)?["\x27][^>]*content=["\x27]([^"\x27]+)/gi,/<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]*(?:property|name)=["\x27](?:og:image|twitter:image)/gi]){let m;while((m=re.exec(h)))out.push(m[1])}
let m;const re2=/<img[^>]+src=["\x27]([^"\x27]+)["\x27][^>]*>/gi;while((m=re2.exec(h))){if(/black|bf|kv|main|mv|hero|top/i.test(m[0])&&!/logo|icon|sprite|\.svg/i.test(m[1]))out.push(m[1])}
console.log([...new Set(out)].slice(0,4).join("\n"))' "$D/.p.html" 2>/dev/null)
  echo "$k: ページ $sz bytes"
  i=0; while IFS= read -r c || [ -n "$c" ]; do [ -z "$c" ] && continue; a=$(abs "$c" "$u"); [ -z "$a" ] && continue; i=$((i+1))
    ext=$(printf '%s' "$a" | sed -E 's/[?#].*//' | grep -oE '\.(jpg|jpeg|png|webp|gif)$' | head -1); ext=${ext:-.jpg}
    curl -sSL -m 25 -A "$UA" -e "$u" -o "$D/kv-$k-$i$ext" "$a"; n=$(wc -c < "$D/kv-$k-$i$ext" | tr -d ' ')
    dim=$(sips -g pixelWidth -g pixelHeight "$D/kv-$k-$i$ext" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')
    echo "  kv-$k-$i$ext  ${n} bytes  ${dim}← $a"
  done <<< "$cands"
  [ "$i" = 0 ] && echo "  候補なし"
  sleep 1
done
echo '```'
echo; echo "## ② ロゴの候補"; echo '```'
for spec in "isetan|https://www.mistore.jp/|Isetan Mitsukoshi logo" "teppay|https://www.teppay.jp/|teppay logo" "jrct|https://travel.jr-central.co.jp/|JR Central Tours logo" "toysrus|https://www.toysrus.co.jp/|Toys R Us logo" "heartbread|https://www.heart-bread.com/|Heart Bread Antique logo" "yahooshop|https://shopping.yahoo.co.jp/|Yahoo! Shopping logo" "matsukiyo|https://www.matsukiyococokara.com/|MatsukiyoCocokara logo"; do
  IFS='|' read -r k u q <<< "$spec"
  curl -sSL -m 25 -A "$UA" -o "$D/.p.html" "$u"
  cands=$("$NODE_BIN" -e '
const h=require("fs").readFileSync(process.argv[1],"utf8");const out=[];let m;
const re=/<(img|link|image|use)[^>]+>/gi;while((m=re.exec(h))){const t=m[0];if(!/logo|apple-touch-icon|brand/i.test(t))continue;const s=(t.match(/(?:src|href|xlink:href|data-src)=["\x27]([^"\x27]+)/i)||[])[1];if(s&&!/^#|data:/.test(s))out.push(s)}
const og=(h.match(/og:image["\x27][^>]*content=["\x27]([^"\x27]+)/i)||[])[1];if(og)out.push(og);
console.log([...new Set(out)].slice(0,4).join("\n"))' "$D/.p.html" 2>/dev/null)
  echo "$k:"
  i=0; while IFS= read -r c || [ -n "$c" ]; do [ -z "$c" ] && continue; a=$(abs "$c" "$u"); [ -z "$a" ] && continue; i=$((i+1))
    ext=$(printf '%s' "$a" | sed -E 's/[?#].*//' | grep -oE '\.(svg|png|jpg|jpeg|webp|gif|ico)$' | head -1); ext=${ext:-.png}
    curl -sSL -m 20 -A "$UA" -e "$u" -o "$D/logo-$k-$i$ext" "$a"; n=$(wc -c < "$D/logo-$k-$i$ext" | tr -d ' ')
    echo "  logo-$k-$i$ext  ${n} bytes ← $a"
  done <<< "$cands"
  enc=$("$NODE_BIN" -e 'console.log(encodeURIComponent(process.argv[1]))' "$q")
  curl -sS -m 25 -A "daily-hack-blog/1.0 (https://daily-hack.fieldbeside.com/)" -o "$D/.api.json" "https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=6&gsrsearch=$enc&gsrlimit=5&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&iiurlwidth=600"
  c=$("$NODE_BIN" -e '
let j;try{j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
const ps=Object.values(j.query?.pages||{}).sort((a,b)=>(a.index||0)-(b.index||0)).filter(p=>/logo/i.test(p.title)).slice(0,2);
for(const p of ps){const i=p.imageinfo?.[0];if(!i)continue;const m=i.extmetadata||{};console.log((i.thumburl||i.url)+"\t"+p.title+"\t"+((m.LicenseShortName||{}).value||""))}' "$D/.api.json")
  j=0; while IFS=$'\t' read -r tu tt tl || [ -n "$tu" ]; do [ -z "$tu" ] && continue; j=$((j+1))
    curl -sSL -m 20 -A "daily-hack-blog/1.0" -o "$D/logo-$k-c$j.png" "$tu"; echo "  logo-$k-c$j.png  $(wc -c < "$D/logo-$k-c$j.png" | tr -d ' ') bytes ← コモンズ $tt（$tl）"
  done <<< "$c"
  [ "$i" = 0 ] && [ "$j" = 0 ] && echo "  候補なし"
  sleep 1
done
echo '```'
rm -f "$D/.p.html" "$D/.api.json"
echo; echo "取ったファイル: $(ls "$D" | wc -l | tr -d ' ') 個"
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "x503 / $(ls "$D" | wc -l | tr -d ' ') 個"
exit 0
