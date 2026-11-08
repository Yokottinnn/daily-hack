#!/bin/bash
# x437（2026-11-08・読むだけ・$0）: X の収益化の公式ヘルプを読み、「広告（プロモーション）で出した表示が審査の数に入るか」の文を抜き出す。
# 利用者の問い「認証済みフォロワーに対する表示を達成するために、広告を使っていいのか」。クラウドからは help.x.com が 403。
# 投稿しない・ログインしない・何も書き換えない。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x437-x-monetization-official-terms.md"
D="${OPS_REPORT_DIR:-/tmp}/x437"; mkdir -p "$D"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
{
echo "# X の収益化の公式ヘルプ（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
i=0
for u in \
  "https://help.x.com/en/using-x/original-content-rewards" \
  "https://help.x.com/en/using-x/creator-revenue-sharing" \
  "https://help.x.com/ja/using-x/creator-revenue-sharing" \
  "https://help.x.com/en/rules-and-policies/creator-revenue-sharing-terms" \
  "https://legal.x.com/en/creator-revenue-sharing-terms.html" \
  "https://legal.x.com/en/original-content-rewards-terms.html" ; do
  i=$((i+1)); f="$D/p$i.html"
  code="$(curl -sS -L -A "$UA" -H 'Accept-Language: en-US,en;q=0.9' -o "$f" -w '%{http_code}' --max-time 25 "$u" 2>&1)"
  echo; echo "## $u"; echo "HTTP $code / $(wc -c < "$f" 2>/dev/null | tr -d ' ') bytes"
  echo '```'
  "$NODE_BIN" -e '
const fs=require("fs");let h="";try{h=fs.readFileSync(process.argv[1],"utf8")}catch(e){}
const t=h.replace(/<script[\s\S]*?<\/script>/gi," ").replace(/<style[\s\S]*?<\/style>/gi," ").replace(/<[^>]+>/g," ").replace(/&nbsp;/g," ").replace(/&amp;/g,"&").replace(/&#39;|&rsquo;/g,"\x27").replace(/&quot;/g,"\"").replace(/\s+/g," ");
const s=t.split(/(?<=[.!?。])\s+/);const re=/promot|paid|advertis|\bads?\b|organic|qualified impression|verified (impression|follower)|inauthentic|artificial|boost|500,?000|5M|5 million|impressions? (in|within|over) the (last|past)/i;
const hit=s.filter(x=>re.test(x)&&x.length<600);console.log(hit.length?hit.slice(0,40).join("\n"):"（該当の文なし・本文 "+t.length+" 字）");' "$f"
  echo '```'
done
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
