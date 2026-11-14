#!/bin/bash
# **読むだけ・$0。** ららぽーと豊洲「音楽ライブ Presented by HMV」のページ（event/2328133）が案内している「ストアイベント情報」のリンク先を読み、11/21〜23 前後の出演アーティストを出す（x489）。x486・x487 では公式ページに出演者の名前が無かった。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x489-read-hmv-toyosu-events.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd|span|a)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# HMV ららぽーと豊洲のストアイベントを読む（$(date '+%F %T') JST・読むだけ・\$0）"
P="https://mitsui-shopping-park.com/lalaport/toyosu/event/2328133.html"
H="$(curl -sL -m 25 -A "$UA" "$P" 2>/dev/null)"
echo; echo "## 2328133 の中のリンク（hmv を含むもの）"; echo '```'
LINKS="$(printf '%s' "$H" | grep -o 'href="[^"]*"' | sed 's/href="//; s/"$//' | grep -i 'hmv' | sort -u | head -10)"
printf '%s\n' "$LINKS"; echo '```'
for u in $LINKS "https://www.hmv.co.jp/store/TYS/" "https://www.hmv.co.jp/store/event/" ; do
  echo; echo "## $u"; echo '```'
  B="$(curl -sL -m 25 -A "$UA" "$u" 2>/dev/null)"; printf '  取れた %s bytes\n' "$(printf '%s' "$B" | wc -c | tr -d ' ')"
  printf '%s' "$B" | grep -o '<title>[^<]*' | head -1
  printf '%s' "$B" | txt | grep -v '^\s*$' | grep -n -E '豊洲|11/1[5-9]|11/2[0-9]|11月(1[5-9]|2[0-9])日|ミニライブ|インストア|リリース|出演|特典会|メインステージ' | head -60 | cut -c1-220
  echo '```'
  printf '%s' "$B" | grep -o 'href="[^"]*event[^"]*"[^>]*>[^<]\{0,60\}' | grep -i '豊洲\|toyosu\|TYS' | sed 's/href="//' | sort -u | head -20
done
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "HMV ららぽーと豊洲のストアイベントを読んだ / $(basename "$OUT")"
