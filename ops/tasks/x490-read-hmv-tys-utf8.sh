#!/bin/bash
# **読むだけ・$0。** HMV ららぽーと豊洲の店舗イベント（https://www.hmv.co.jp/store/TYS/）を UTF-8 に直して読み、11 月の出演者・日時を出す（x490）。x489 は Shift_JIS のまま読んで文字化けした。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x490-read-hmv-tys-utf8.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd|span|a)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# HMV ららぽーと豊洲の店舗イベントを読む（$(date '+%F %T') JST・読むだけ・\$0）"
U="https://www.hmv.co.jp/store/TYS/"
curl -sL -m 30 -A "$UA" "$U" 2>/dev/null | iconv -f CP932 -t UTF-8 -c > /tmp/.x490.html
printf '取れた %s bytes（UTF-8 に直した後）\n' "$(wc -c < /tmp/.x490.html | tr -d ' ')"
echo; echo "## 題名"; grep -o '<title>[^<]*' /tmp/.x490.html | head -1
echo; echo "## 11 月の行（前後 4 行つき）"; echo '```'
txt < /tmp/.x490.html | grep -v '^\s*$' > /tmp/.x490.txt
grep -n -E '2026/11/(1[4-9]|2[0-9]|30)|11/(1[4-9]|2[0-9]|30)' /tmp/.x490.txt | head -40 | cut -d: -f1 | while read -r n || [ -n "$n" ]; do
  s=$((n - 4)); [ "$s" -lt 1 ] && s=1; e=$((n + 4)); sed -n "${s},${e}p" /tmp/.x490.txt | cut -c1-160; echo "  ……"
done
echo '```'
echo; echo "## イベントのリンク（題名つき）"; echo '```'
grep -o 'href="[^"]*/store/event/[0-9]*/*"[^>]*>[^<]\{0,80\}' /tmp/.x490.html | sed 's/href="//; s/"[^>]*>/ | /' | sort -u | head -30
echo '```'
rm -f /tmp/.x490.html /tmp/.x490.txt
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "HMV ららぽーと豊洲の店舗イベントを読んだ / $(basename "$OUT")"
