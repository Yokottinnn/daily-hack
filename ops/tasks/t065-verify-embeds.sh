#!/bin/bash
# **格安スーパー記事の埋め込みが生きているかを確かめる。**
#
# クラウドセッションからは外に出られないため、YouTube の動画 ID と
# ツイート ID が実在するかを確認できない。**死んだ ID を埋めると、
# ページ上では「この動画は利用できません」という灰色の箱になり、
# ビルドも検査も通ってしまう。**
#
# 判定:
#   YouTube … https://www.youtube.com/oembed?format=json&url=... が 200 なら生きている
#   ツイート … https://cdn.syndication.twimg.com/tweet-result?id=... が本文を返せば生きている
#
# 出力は `$OPS_REPORT_DIR`。**秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t065-embeds.md"

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'

{
  echo "# 格安スーパー記事の埋め込み確認（t065）"
  echo
  echo "## YouTube"
  echo
  for id in 42sjI0HAm7g Q8rOjIllPCU ea1lk2LVbUE Gb5Iks5xf04 IQlZ1FeGIHc L6rfSyiYNzM 26aqdhhXGMM; do
    body=$(curl -sS -m 20 -A "$UA" \
      "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=$id" 2>/dev/null)
    if echo "$body" | grep -q '"title"'; then
      title=$(echo "$body" | sed -n 's/.*"title":"\([^"]*\)".*/\1/p')
      author=$(echo "$body" | sed -n 's/.*"author_name":"\([^"]*\)".*/\1/p')
      echo "- ✅ \`$id\` … $title ／ $author"
    else
      echo "- ❌ **\`$id\` は生きていない。** 記事から外すか差し替える"
    fi
  done

  echo
  echo "## ツイート"
  echo
  for id in 2025480684190540286 2042734632609943808; do
    body=$(curl -sS -m 20 -A "$UA" \
      "https://cdn.syndication.twimg.com/tweet-result?id=$id&lang=ja&token=a" 2>/dev/null)
    if echo "$body" | grep -q '"text"'; then
      name=$(echo "$body" | sed -n 's/.*"screen_name":"\([^"]*\)".*/\1/p' | head -1)
      echo "- ✅ \`$id\` … @$name"
      echo "$body" | python3 -c 'import sys,json;d=json.load(sys.stdin);print("  - 本文:",d.get("text","")[:160].replace("\n"," "))' 2>/dev/null
    else
      echo "- ❌ **\`$id\` は取れなかった。** 削除済みか非公開の可能性"
    fi
  done
} | tee "$OUT"

exit 0
