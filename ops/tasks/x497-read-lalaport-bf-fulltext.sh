#!/bin/bash
# **読むだけ・$0。** ららぽーと豊洲のブラックフライデー・抽選会のページの本文を全部出す（絞り込まない）。イベント一覧の 2〜4 ページ目と、ステージ・ライブの分類も読む（x497）。
# 利用者（2026-11-15）「まだ調べろ」。x486・x487 は行を絞り込んで読んだので、見落としが無いか全文で確かめる。ログインの要らない公開ページだけ。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x497-read-lalaport-bf-fulltext.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
B="https://mitsui-shopping-park.com/lalaport/toyosu"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd|span|a|td|th)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# ららぽーと豊洲のページを全文で読む（$(date '+%F %T') JST・読むだけ・\$0）"
for id in 3613509 3613510; do
  echo; echo "## event/$id（本文の 85〜260 行目・絞り込みなし）"; echo '```'
  curl -sL -m 25 -A "$UA" "$B/event/$id.html" | txt | grep -v '^\s*$' | sed -n '85,260p' | cut -c1-200
  echo '```'
  echo "画像の alt:"; curl -sL -m 25 -A "$UA" "$B/event/$id.html" | grep -o '<img[^>]*alt="[^"]\{2,\}"' | sed 's/.*alt="//; s/"$//' | sort -u | head -20
done
for q in "event/?page=2" "event/?page=3" "event/?page=4" "event/?category=music" "event/?cat=live" "shopnews/" "news/"; do
  echo; echo "## $B/$q"; echo '```'
  H="$(curl -sL -m 25 -A "$UA" "$B/$q")"; printf '  %s bytes\n' "$(printf '%s' "$H" | wc -c | tr -d ' ')"
  printf '%s' "$H" | grep -o '<a[^>]*href="[^"]*\(event\|shopnews\|news\)/[0-9]\{5,9\}[^"]*"[^>]*>' | sed 's/.*href="//; s/".*//' | sort -u | head -30
  printf '%s' "$H" | txt | grep -v '^\s*$' | grep -n -E 'ライブ|LIVE|ステージ|出演|アーティスト|ミニライブ|リリース|特典会|握手|サイン|トークショー|11/2[0-9]|11月2[0-9]日' | head -30 | cut -c1-200
  echo '```'
done
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "ららぽーと豊洲のページを全文で読んだ / $(basename "$OUT")"
