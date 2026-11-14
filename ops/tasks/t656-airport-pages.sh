#!/bin/bash
# **空港の記事の公式ページを読む（t656）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者「ランキングの記事は徹底的に調べて…ららぽーとの記事のようなクオリティは絶対に維持」。
# 上位10空港の公式サイト（トップと会社・空港の概要）。滑走路・開港・ターミナルなど、その空港だけの事実を節に書くため。鹿児島・神戸は公式の URL が正しいかもここで確かめる。
# 各ページの HTML を reports/t656/ に置き、本文の文字（滑走路・開港・ターミナル・路線を含む行）と、概要・会社・施設のページへのリンクを書き出す。推測で URL を組まない: 入口のページからリンクを拾う。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t656"; mkdir -p "$D"
OUT="$RDIR/t656-airport-pages.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
{
echo "# 空港の公式ページ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
for pair in "haneda|https://tokyo-haneda.com/" "narita|https://www.narita-airport.jp/" "kix|https://www.kansai-airport.or.jp/" "fukuoka|https://www.fukuoka-airport.jp/" "chitose|https://www.new-chitose-airport.jp/" "naha|https://www.naha-airport.co.jp/" "itami|https://www.osaka-airport.co.jp/" "centrair|https://www.centrair.jp/" "kagoshima|https://www.koj-ab.co.jp/" "kobe|https://www.kairport.co.jp/" "mlit|https://www.mlit.go.jp/koku/15_bf_000185.html"; do
  key="${pair%%|*}"; u="${pair#*|}"
  code=$(curl -sS -L -m 30 -A "$UA" -o "$D/$key.html" -w '%{http_code}' "$u" 2>&1 | tail -c 40)
  echo "== $key $u → $code $(wc -c < "$D/$key.html" 2>/dev/null) bytes"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const txt=h.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi,"").replace(/<[^>]+>/g,"\n").replace(/&nbsp;/g," ").split("\n").map(s=>s.trim()).filter(Boolean);
const hit=txt.filter(s=>/滑走路|開港|開業|ターミナル|就航|路線|万人|国際線|ｍ|m |年.?月/.test(s)&&/[0-9０-９]/.test(s)).slice(0,60);
console.log("-- 数字のある行 "+hit.length);hit.forEach(s=>console.log("  "+s.slice(0,160)));
const links=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,80}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").trim().slice(0,50)}).filter(s=>/\.(pdf|xlsx?|csv)(\?|\s|$)|about|company|corporate|overview|gaiyo|概要|会社|歴史|history|facility|施設/i.test(s));
console.log("-- リンク "+links.length);[...new Set(links)].slice(0,40).forEach(s=>console.log("  "+s))' "$D/$key.html" "$u"
  sleep 1
done
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t656 / $(basename "$OUT")"
