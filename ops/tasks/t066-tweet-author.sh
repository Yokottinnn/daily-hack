#!/bin/bash
# **ロピア批判ツイートの投稿者を確定させる。**
#
# t065 の判定スクリプトは `sed` で JSON 中の**最初の** `"screen_name"` を拾っていた。
# 引用元やリプライ先が JSON に混ざると、**別人の名前を掴む。**
# 実際 `2042734632609943808` に対して t065 は `@nikkei` と出したが、
# 記事側は `@CryptoEggmen`（EggCooker）と書いている。**どちらかが誤り。**
#
# 誤った帰属のまま公開すると、**他人の発言を別の誰かの発言として出すことになる。**
# `user.screen_name` を JSON として正しく読んで確定させる。
#
# 出力は `$OPS_REPORT_DIR`。**秘密は出さない。**
#
# LLM 不使用・$0/回・$0/日・$0/月（1 回だけの確認タスク）

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t066-tweet-author.md"
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'

{
  echo "# ツイートの投稿者を確定させる（t066）"
  echo
  for id in 2042734632609943808 2025480684190540286; do
    echo "## \`$id\`"
    echo
    curl -sS -m 25 -A "$UA" \
      "https://cdn.syndication.twimg.com/tweet-result?id=$id&lang=ja&token=a" 2>/dev/null \
    | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("- ❌ JSON として読めなかった:", type(e).__name__); raise SystemExit
u = d.get("user") or {}
print("- **投稿者: @%s（%s）**" % (u.get("screen_name","?"), u.get("name","?")))
print("- 投稿日時:", d.get("created_at","?"))
print("- 本文:", (d.get("text") or "").replace("\n"," ")[:200])
q = d.get("quoted_tweet") or {}
if q:
    qu = q.get("user") or {}
    print("- ※ 引用元がある: @%s。**t065 はこちらを掴んだ可能性がある**" % qu.get("screen_name","?"))
'
    echo
  done
} | tee "$OUT"

exit 0
