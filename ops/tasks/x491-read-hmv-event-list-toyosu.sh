#!/bin/bash
# **読むだけ・$0。** HMV の全店イベント一覧（/store/event/）を UTF-8 に直し、「豊洲」を含む行の前後を出す。あわせて店舗ページ（/store/TYS/）の本文の先頭も出す（x491）。x490 では店舗ページに 11 月の日付の行が無かった。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x491-read-hmv-event-list-toyosu.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd|span|a)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# HMV のイベント一覧から豊洲を拾う（$(date '+%F %T') JST・読むだけ・\$0）"
for P in "https://www.hmv.co.jp/store/event/" "https://www.hmv.co.jp/store/event/?page=2" "https://www.hmv.co.jp/store/event/?page=3"; do
  curl -sL -m 30 -A "$UA" "$P" 2>/dev/null | iconv -f CP932 -t UTF-8 -c | txt | grep -v '^\s*$' > /tmp/.x491.txt
  echo; echo "## $P（$(wc -l < /tmp/.x491.txt | tr -d ' ') 行）"; echo '```'
  grep -n '豊洲' /tmp/.x491.txt | head -20 | cut -d: -f1 | while read -r n || [ -n "$n" ]; do
    s=$((n - 6)); [ "$s" -lt 1 ] && s=1; e=$((n + 3)); sed -n "${s},${e}p" /tmp/.x491.txt | cut -c1-160; echo "  ……"
  done
  echo '```'
done
echo; echo "## 店舗ページ /store/TYS/ の本文（イベント・ライブ・日付の行）"; echo '```'
curl -sL -m 30 -A "$UA" "https://www.hmv.co.jp/store/TYS/" 2>/dev/null | iconv -f CP932 -t UTF-8 -c | txt | grep -v '^\s*$' > /tmp/.x491b.txt
grep -n -E 'イベント|ライブ|LIVE|ミニライブ|特典会|リリース|20[0-9][0-9]/|[0-9]{1,2}/[0-9]{1,2}|月[0-9]+日' /tmp/.x491b.txt | head -60 | cut -c1-160
echo '```'
rm -f /tmp/.x491.txt /tmp/.x491b.txt
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "HMV のイベント一覧から豊洲を拾った / $(basename "$OUT")"
