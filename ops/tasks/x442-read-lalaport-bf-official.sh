#!/bin/bash
# x442（2026-11-08・読むだけ・$0）: ららぽーと豊洲のブラックフライデーの公式ページを読み直す。
# 利用者のコメント「最新の情報を調べて、内容として正しいかどうかを確認して／公式から画像を取得して、3枚目4枚目で添付できるようなら追加して」。
# ページの本文（期間・抽選会の条件・レシート・電子レシート）を抜き出し、画像を全部 $OPS_REPORT_DIR/x442-lalaport/ に保存する（15 KB 未満は捨てる）。
# 投稿しない・ログインしない・何も書き換えない。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x442-lalaport-bf-official.md"
D="${OPS_REPORT_DIR:-/tmp}/x442-lalaport"; mkdir -p "$D"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
{
echo "# ららぽーと豊洲 ブラックフライデーの公式ページ（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
n=0
for u in "https://mitsui-shopping-park.com/lalaport/toyosu/event/3613509.html" "https://mitsui-shopping-park.com/lalaport/toyosu/event/3613510.html"; do
  f="$D/page-$(basename "$u" .html).html"
  code="$(curl -sS -L -A "$UA" -o "$f" -w '%{http_code}' --max-time 25 "$u" 2>&1)"
  echo; echo "## $u"; echo "HTTP $code / $(wc -c < "$f" | tr -d ' ') bytes"
  echo; echo "### 本文"; echo '```text'
  "$NODE_BIN" -e '
const fs=require("fs");const h=fs.readFileSync(process.argv[1],"utf8");
const m=h.match(/<main[\s\S]*?<\/main>/i)||h.match(/<article[\s\S]*?<\/article>/i)||[h];
let t=m[0].replace(/<script[\s\S]*?<\/script>/gi,"").replace(/<style[\s\S]*?<\/style>/gi,"").replace(/<br\s*\/?>/gi,"\n").replace(/<\/(p|div|li|h\d|dt|dd|tr)>/gi,"\n").replace(/<[^>]+>/g," ").replace(/&nbsp;/g," ").replace(/&amp;/g,"&").replace(/&yen;/g,"¥").replace(/[ \t]+/g," ").split("\n").map(s=>s.trim()).filter(Boolean);
console.log(t.join("\n").slice(0,6000));' "$f" 2>&1
  echo '```'
  echo; echo "### 画像"; echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");const h=fs.readFileSync(process.argv[1],"utf8");const base=process.argv[2];
const urls=new Set();for(const m of h.matchAll(/(?:src|data-src|content)="([^"]+\.(?:jpe?g|png|webp)[^"]*)"/gi)){try{urls.add(new URL(m[1],base).href)}catch(e){}}
console.log([...urls].join("\n"));' "$f" "$u" > "$D/urls.txt" 2>&1
  while IFS= read -r iu || [ -n "$iu" ]; do
    [ -z "$iu" ] && continue
    n=$((n+1)); ext="${iu##*.}"; ext="${ext%%\?*}"; case "$ext" in jpg|jpeg|png|webp) ;; *) ext=jpg;; esac
    o="$D/img-$(printf '%02d' $n).$ext"
    curl -sS -L -A "$UA" -o "$o" --max-time 20 "$iu" 2>/dev/null
    sz="$(wc -c < "$o" 2>/dev/null | tr -d ' ')"
    if [ "${sz:-0}" -lt 15000 ]; then rm -f "$o"; continue; fi
    dim="$(sips -g pixelWidth -g pixelHeight "$o" 2>/dev/null | awk '/pixel/{printf "%s ",$2}')"
    echo "$(basename "$o")  ${sz} bytes  ${dim}  $iu"
  done < "$D/urls.txt"
  echo '```'
done
rm -f "$D"/page-*.html "$D/urls.txt"
echo; echo "保存したもの: $(ls "$D" | tr '\n' ' ')"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
