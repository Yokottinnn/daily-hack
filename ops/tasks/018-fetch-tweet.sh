#!/bin/bash
# 参考にしたい X の投稿を Mac 側から取得して報告に書き出す。
#
# **クラウドセッションには一般の外向き通信が無い。** 2026-08-22 に実測したところ、
# WebFetch は x.com はもちろん ja.wikipedia.org も EGRESS_BLOCKED、
# Bash からの curl は example.com ですら CONNECT に 403 が返る。
# 記事の題材として投稿を読むには、通常のインターネットに出られる Mac を経由するしかない。
#
# **ログイン不要の公開エンドポイントだけを使う。** OpenClaw のブラウザや
# X の認証情報には触れない（あれは tweet2 の領分）。
#
# LLM を呼ばないため API クレジットは消費しない。
set -uo pipefail

ID="2086581590344491157"
HANDLE="shoshilog"
OUT="${OPS_REPORT_DIR:-/tmp}/tweet-${ID}.md"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"

fetch() { curl -sS --max-time 25 -A "$UA" "$1" 2>&1; }

{
  echo "# X 投稿の取得（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "対象: https://x.com/${HANDLE}/status/${ID}"
  echo

  echo "## 1. syndication（ログイン不要の埋め込み用 JSON）"
  echo
  echo '```json'
  fetch "https://cdn.syndication.twimg.com/tweet-result?id=${ID}&lang=ja&token=a" | head -c 6000
  echo
  echo '```'
  echo

  echo "## 2. oembed（本文の HTML が返る）"
  echo
  echo '```json'
  fetch "https://publish.twitter.com/oembed?url=https%3A%2F%2Ftwitter.com%2F${HANDLE}%2Fstatus%2F${ID}&omit_script=1&lang=ja" | head -c 4000
  echo
  echo '```'
  echo

  echo "## 3. fxtwitter（本文・画像・スレッドが JSON で返る）"
  echo
  echo '```json'
  fetch "https://api.fxtwitter.com/${HANDLE}/status/${ID}" | head -c 8000
  echo
  echo '```'
  echo

  echo "## 4. x.com の HTML から og:description を拾う"
  echo
  echo '```'
  fetch "https://x.com/${HANDLE}/status/${ID}" \
    | grep -oE '<meta[^>]+(og:description|og:title|og:image)[^>]*>' | head -20
  echo '```'
} > "$OUT"

BYTES=$(wc -c < "$OUT" | tr -d ' ')
echo "書き出した: reports/tweet-${ID}.md（${BYTES} bytes）"
