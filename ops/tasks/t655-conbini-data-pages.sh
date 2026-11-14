#!/bin/bash
# **コンビニの記事の数字の出どころ（公式ページ）を読む（t655）。読むだけ・LLM 不使用・$0。**
# 2026-11-14 利用者「ランキングの記事は徹底的に調べて…ららぽーとの記事のようなクオリティは絶対に維持」。
# 軸を足すための一次情報: JFA のコンビニ統計（全国の店舗数・売上の推移）・総務省の人口推計（人口あたりの店舗数）・各社の公式の店舗数と日販・ほかのチェーン（ミニストップ・セイコーマート・デイリーヤマザキ・NewDays・ポプラ）。
# 各ページの HTML を reports/t655/ に置き、本文の文字（店舗・日販・人口を含む行）と、pdf/xlsx/csv へのリンクを書き出す。推測で URL を組まない: 入口のページからリンクを拾う。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t655"; mkdir -p "$D"
OUT="$RDIR/t655-conbini-data-pages.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
{
echo "# コンビニの数字の出どころ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
for pair in "jfa|https://www.jfa-fc.or.jp/particle/320.html" "stat|https://www.stat.go.jp/data/jinsui/2024np/index.html" "lawson|https://www.lawson.co.jp/company/corporate/data/sales/" "lawsonstore|https://www.lawson.co.jp/company/corporate/data/store/" "fami|https://www.family.co.jp/company/familymart/store.html" "famicorp|https://www.family.co.jp/company/familymart.html" "sej|https://www.sej.co.jp/company/tenpo.html" "sejdata|https://www.sej.co.jp/company/aboutus/data.html" "ministop|https://www.ministop.co.jp/corporate/" "seico|https://www.seicomart.co.jp/" "daily|https://www.daily-yamazaki.jp/" "jrcross|https://www.jr-cross.co.jp/" "poplar|https://www.poplar-cvs.co.jp/"; do
  key="${pair%%|*}"; u="${pair#*|}"
  code=$(curl -sS -L -m 30 -A "$UA" -o "$D/$key.html" -w '%{http_code}' "$u" 2>&1 | tail -c 40)
  echo "== $key $u → $code $(wc -c < "$D/$key.html" 2>/dev/null) bytes"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,base]=process.argv.slice(1);let h="";try{h=fs.readFileSync(f,"utf8")}catch(e){process.exit(0)}
const txt=h.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/gi,"").replace(/<[^>]+>/g,"\n").replace(/&nbsp;/g," ").split("\n").map(s=>s.trim()).filter(Boolean);
const hit=txt.filter(s=>/店|日販|人口|売上|推移|年.?月/.test(s)&&/[0-9０-９]/.test(s)).slice(0,60);
console.log("-- 数字のある行 "+hit.length);hit.forEach(s=>console.log("  "+s.slice(0,160)));
const links=[...h.matchAll(/href="([^"]+)"[^>]*>([\s\S]{0,80}?)<\/a>/gi)].map(m=>{let u=m[1];try{u=new URL(u,base).href}catch(e){};return u+" | "+m[2].replace(/<[^>]+>/g,"").trim().slice(0,50)}).filter(s=>/\.(pdf|xlsx?|csv)(\?|\s|$)|店舗|tenpo|store|data|ir\/|統計|company|kaisha|corporate/i.test(s));
console.log("-- リンク "+links.length);[...new Set(links)].slice(0,40).forEach(s=>console.log("  "+s))' "$D/$key.html" "$u"
  sleep 1
done
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t655 / $(basename "$OUT")"
