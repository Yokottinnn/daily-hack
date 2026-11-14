#!/bin/bash
# **JFA のコンビニ統計の PDF を取り直す（t658）。読むだけ・LLM 不使用・$0。**
# t657 では PDF の URL が 64 バイトのリダイレクト（トップへ戻る）になった。入口のページ（particle/320.html）を Referer に付け、Cookie を持ったまま取り直す。
# 2026-11-14 利用者「ランキングの記事は徹底的に調べて…ららぽーとの記事のようなクオリティは絶対に維持」。コンビニの記事の「全国の店舗数・売上の推移」に使う。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; D="$RDIR/t658"; mkdir -p "$D"
OUT="$RDIR/t658-jfa-cvs-stats.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
REF="https://www.jfa-fc.or.jp/particle/320.html"; CJ="$D/.cookies"
{
echo "# JFA コンビニ統計の取り直し（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo; echo '```'
curl -sS -L -m 30 -A "$UA" -c "$CJ" -b "$CJ" -o "$D/.entry.html" "$REF"; echo "entry $(wc -c < "$D/.entry.html") bytes"
for pair in "jfa2025.pdf|https://www.jfa-fc.or.jp/folder/1/img/20260120121124.pdf" "jfa2024.pdf|https://www.jfa-fc.or.jp/folder/1/img/20250120103927.pdf" "jfa202609.pdf|https://www.jfa-fc.or.jp/folder/1/img/20261020101918.pdf" "jfa2016.pdf|https://www.jfa-fc.or.jp/folder/1/img/20170120104404.pdf"; do
  f="${pair%%|*}"; u="${pair#*|}"
  code=$(curl -sS -L -m 40 -A "$UA" -e "$REF" -c "$CJ" -b "$CJ" -o "$D/$f" -w '%{http_code} %{content_type}' "$u" 2>&1 | tail -c 80)
  echo "$f → $code $(wc -c < "$D/$f") bytes $(head -c 5 "$D/$f" | tr -dc 'A-Za-z%-')"
  sleep 1
done
rm -f "$CJ" "$D/.entry.html"
echo '```'; echo "**読むだけ。LLM 不使用（\$0／回）。**"
} > "$OUT" 2>&1
echo "t658 / $(basename "$OUT")"
