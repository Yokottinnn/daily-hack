#!/bin/bash
# **読むだけ・$0。** ららぽーと豊洲のブラックフライデー・抽選会（11/21〜23）の前後に出る「注目アーティスト」（ライブ・ステージ・出演者）を公式ページから読む（x486）。
# 利用者（2026-11-15 00:5x JST）: 元の投稿（2120713367275061545）へのスレッドで「注目アーティスト」の投稿を作ってほしい。推測で書かないため、公式の文面を取る。
set -uo pipefail
OUT="${OPS_REPORT_DIR:-/tmp}/x486-read-lalaport-artists.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
B="https://mitsui-shopping-park.com/lalaport/toyosu"
txt() { perl -0pe 's/<script.*?<\/script>//gs; s/<style.*?<\/style>//gs; s/<br\s*\/?>/\n/gi; s/<\/(p|div|li|h[1-6]|tr|dt|dd)>/\n/gi; s/<[^>]+>//g; s/&nbsp;/ /g; s/&amp;/&/g; s/[ \t]+/ /g; s/\n\s*\n+/\n/g'; }
{
echo "# ららぽーと豊洲の公式ページから、アーティスト・ライブ・ステージを読む（$(date '+%F %T') JST・読むだけ・\$0）"
for u in "$B/event/3613510.html" "$B/event/3613509.html" "$B/event/" "$B/event/index.html" "$B/news/"; do
  echo; echo "## $u"; echo '```'
  H="$(curl -sL -m 25 -A "$UA" "$u" 2>/dev/null)"; printf '  取れた %s bytes\n' "$(printf '%s' "$H" | wc -c | tr -d ' ')"
  T="$(printf '%s' "$H" | txt)"
  printf '%s\n' "$T" | grep -n -E 'アーティスト|ライブ|LIVE|ステージ|出演|ミニライブ|トーク|握手|サイン|特典会|シーサイドデッキ|11/2[0-9]|11月2[0-9]日' | head -60 | cut -c1-220
  echo '```'
  # 個別のイベントへのリンク（11 月のもの）
  printf '%s' "$H" | grep -o 'href="[^"]*event/[0-9]\{6,8\}\.html"[^>]*>[^<]\{0,80\}' | sed 's/href="//; s/"[^>]*>/ | /' | sort -u | head -40
done
# 一覧から拾った個別ページのうち、題名にライブ・ステージ・アーティストが入るものを読む
echo; echo "## 個別のイベント（題名にライブ・ステージ等）"
L="$(curl -sL -m 25 -A "$UA" "$B/event/" 2>/dev/null | grep -o 'href="[^"]*event/[0-9]\{6,8\}\.html"[^>]*>[^<]\{0,80\}' | grep -E 'ライブ|LIVE|ステージ|アーティスト|出演|コンサート|ショー' | sed 's/href="//; s/".*//' | sort -u | head -8)"
for p in $L; do case "$p" in http*) u="$p";; /*) u="https://mitsui-shopping-park.com$p";; *) u="$B/event/$p";; esac
  echo; echo "### $u"; echo '```'; curl -sL -m 25 -A "$UA" "$u" 2>/dev/null | txt | grep -v '^\s*$' | sed -n '1,400p' | grep -n -E 'アーティスト|ライブ|出演|日時|日程|開催|場所|会場|時間|観覧|無料|整理券|特典|11/|11月' | head -40 | cut -c1-220; echo '```'; done
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
echo "ららぽーと豊洲の公式ページを読んだ / $(basename "$OUT")"
