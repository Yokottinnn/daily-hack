#!/bin/bash
# 018 で取れた投稿は本文末尾が「続く」で、スレッドに続きがある
# （syndication の conversation_count = 2）。その続きを取りに行く。
#
# syndication も fxtwitter も **単発の投稿しか返さない**ため、
# スレッドを見るには別経路が要る。ここでは nitter 系のミラーと
# 作者タイムラインの RSS を順に叩く。どれか 1 つ通れば続きが読める。
#
# ログイン不要の公開エンドポイントだけを使う。LLM を呼ばないため API 課金なし。
set -uo pipefail

ID="2086581590344491157"
HANDLE="shoshilog"
OUT="${OPS_REPORT_DIR:-/tmp}/tweet-${ID}-thread.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"

# HTML を素のテキストに落とす（pandoc 等に依存しない）
detag() {
  sed -e 's/<br[^>]*>/\n/g' -e 's/<\/p>/\n\n/g' -e 's/<[^>]*>//g' \
    | sed -e 's/&nbsp;/ /g' -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&quot;/"/g' -e "s/&#39;/'/g"
}

try() { curl -sSL --max-time 30 -A "$UA" "$1" 2>&1; }

{
  echo "# スレッドの続き（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "元投稿: https://x.com/${HANDLE}/status/${ID}"
  echo

  for M in xcancel.com nitter.poast.org nitter.privacyredirect.com lightbrd.com; do
    echo "## ${M}"
    echo
    echo '```'
    try "https://${M}/${HANDLE}/status/${ID}" | detag \
      | grep -v '^[[:space:]]*$' | sed -n '1,220p' | cut -c1-400
    echo '```'
    echo
  done

  echo "## 作者タイムラインの RSS（前後の投稿から続きを探す）"
  echo
  echo '```'
  try "https://xcancel.com/${HANDLE}/rss" | detag \
    | grep -v '^[[:space:]]*$' | sed -n '1,200p' | cut -c1-400
  echo '```'
} > "$OUT"

echo "書き出した: reports/tweet-${ID}-thread.md（$(wc -c < "$OUT" | tr -d ' ') bytes）"
