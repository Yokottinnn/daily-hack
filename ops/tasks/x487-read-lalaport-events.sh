#!/bin/bash
# **読むだけ・$0。** ららぽーと豊洲のイベント 19 件を 1 件ずつ読み、題名・日程・出演者（アーティスト）を出す（x487）。x486 で「音楽ライブ Presented by HMV」の枠はあったが出演者の名前が取れなかったため。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x487-read-lalaport-events.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
B="https://mitsui-shopping-park.com/lalaport/toyosu/event"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd|span)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# ららぽーと豊洲のイベントを 1 件ずつ読む（$(date '+%F %T') JST・読むだけ・\$0）"
N=0; OK=0
for id in 1898316 2328133 2715081 3026618 3119700 3354741 3355806 3476875 3638089 3661429 3669267 3669273 3672755 3676031 3676117 3680992 3687557; do
  N=$((N + 1)); u="$B/$id.html"; H="$(curl -sL -m 20 -A "$UA" "$u" 2>/dev/null)"
  T="$(printf '%s' "$H" | grep -o '<title>[^<]*' | head -1 | sed 's/<title>//')"
  echo; echo "## $id ｜ ${T:-（題名なし）}"; echo '```'
  [ -n "$H" ] && OK=$((OK + 1))
  # 本文の中ほど（ヘッダーとフッターを除く）。イベントの説明・出演者・日時の行を出す
  printf '%s' "$H" | txt | awk 'NR>90 && NR<260' | grep -v '^\s*$' | grep -n -E '出演|アーティスト|ゲスト|ライブ|LIVE|ステージ|日時|日程|開催|時間|場所|会場|観覧|無料|特典|整理券|CD|リリース|11/|11月|12/|12月' | head -30 | cut -c1-220
  echo '```'
done
echo; echo "対象 $N 件 / 取れた $OK 件"
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "ららぽーと豊洲のイベントを読んだ / $(basename "$OUT")"
