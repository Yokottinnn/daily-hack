#!/bin/bash
# x443（2026-11-08・読むだけ・$0）: ららぽーと豊洲ブラックフライデー抽選会の景品の画像を集める（景品紹介の画像に使う。「画像は参考です」と添える）。
# 利用者のコメント「4枚目の画像は不要なので、代わりに景品の画像を取得してきて景品紹介の画像を作ってよ／公式の画像ではないので『画像は参考です』みたいな感じにして」。
# 各ページの og:image と、景品名に関わる画像を $OPS_REPORT_DIR/x443-prizes/ に保存する（15 KB 未満は捨てる）。投稿しない・ログインしない。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x443-lalaport-prize-images.md"
D="${OPS_REPORT_DIR:-/tmp}/x443-prizes"; mkdir -p "$D"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
{
echo "# 抽選会の景品の画像（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
while IFS='|' read -r tag kw u || [ -n "$tag" ]; do
  [ -z "$tag" ] && continue
  f="$D/.page.html"
  code="$(curl -sS -L -A "$UA" -H 'Accept-Language: ja,en;q=0.8' -o "$f" -w '%{http_code}' --max-time 25 "$u" 2>&1)"
  echo; echo "## $tag  $u"; echo "HTTP $code / $(wc -c < "$f" 2>/dev/null | tr -d ' ') bytes"; echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");let h="";try{h=fs.readFileSync(process.argv[1],"utf8")}catch(e){}const base=process.argv[2];const kw=new RegExp(process.argv[3],"i");
const out=[];const add=(u,why)=>{try{const x=new URL(u.replace(/&amp;/g,"&"),base).href;if(!out.find(o=>o.u===x))out.push({u:x,why})}catch(e){}};
for(const m of h.matchAll(/<meta[^>]+(?:property|name)="(?:og:image|twitter:image)"[^>]+content="([^"]+)"/gi))add(m[1],"og");
for(const m of h.matchAll(/<meta[^>]+content="([^"]+)"[^>]+(?:property|name)="(?:og:image|twitter:image)"/gi))add(m[1],"og");
for(const m of h.matchAll(/<img[^>]+>/gi)){const t=m[0];const s=(t.match(/(?:data-src|src)="([^"]+)"/i)||[])[1];if(!s)continue;const a=(t.match(/alt="([^"]*)"/i)||[])[1]||"";if(kw.test(a+" "+s))add(s,"img alt="+a.slice(0,40));}
console.log(out.slice(0,8).map(o=>o.why+"\t"+o.u).join("\n"));' "$f" "$u" "$kw" > "$D/.list.txt" 2>&1
  n=0
  while IFS=$'\t' read -r why iu || [ -n "$why" ]; do
    [ -z "$iu" ] && continue
    n=$((n+1)); o="$D/$tag-$n.img"
    curl -sS -L -A "$UA" -e "$u" -o "$o" --max-time 20 "$iu" 2>/dev/null
    sz="$(wc -c < "$o" 2>/dev/null | tr -d ' ')"
    if [ "${sz:-0}" -lt 15000 ]; then rm -f "$o"; echo "（小さいので捨てた） $why $iu"; continue; fi
    t="$(file -b --mime-type "$o")"; ext=jpg; case "$t" in image/png) ext=png;; image/webp) ext=webp;; image/jpeg) ext=jpg;; *) rm -f "$o"; echo "（画像でない $t） $iu"; continue;; esac
    mv "$o" "$D/$tag-$n.$ext"
    dim="$(sips -g pixelWidth -g pixelHeight "$D/$tag-$n.$ext" 2>/dev/null | awk '/pixel/{printf "%s ",$2}')"
    echo "$tag-$n.$ext  ${sz} bytes  ${dim}  [$why]  $iu"
  done < "$D/.list.txt"
  echo '```'
done <<'LIST'
dangbei|n2|https://av.watch.impress.co.jp/docs/news/2004986.html
dangbei|n2|https://www.richersounds.com/dangbei-n2-mini-grey/
dangbei|n2|https://www.visunext.co.uk/p/dangbei-n2-mini-projector-1000034900
recolte|RSY|https://www.ksdenki.com/shop/g/g4582180208378/
jcb|ギフト|https://www.jcb.co.jp/merchant/services/payment/jcbgift.html
jcb|ギフト|https://www.jcb.co.jp/voucher/index.html
andmall|logo|https://mitsui-shopping-park.com/ec/
LIST
rm -f "$D/.page.html" "$D/.list.txt"
echo; echo "保存したもの: $(ls "$D" | tr '\n' ' ')"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
