#!/bin/bash
# **MediaWiki API が 13 ブランド すべてで空を返した。原因を出す（t162）。$0。**
#
# ## 何が起きたか
#
# t159 / t160 / t161 で **13 ブランド すべて**が「ロゴらしいファイルが記事に無い」
# になり、**保険で入れた生ファイル名の一覧も空**だった。
#
#   **13 件 中 13 件 が同じ結果＝データではなく、こちらの呼び方が壊れている。**
#
# **クラウドからは確かめられない**（`ja.wikipedia.org` へ CONNECT が 403）。
# だから **Mac で生の応答を見る。**
#
# ## 出すもの
#
# **応答の先頭 400 字をそのまま。** 加工しない。
# 4 つの呼び方を並べて、**どれが通るのかを 1 往復で決める。**
#
#   ① curl -G + --data-urlencode（t159 と同じ書き方。これが壊れている疑い）
#   ② URL に直接クエリを書く（日本語は %エンコード済みのものを使う）
#   ③ REST API の summary（`originalimage` が返る）
#   ④ 英語版（`en.wikipedia.org`）で同じこと
#
# **判断はしない。応答をそのまま持ち帰るだけ。**
#
# **120 秒 で打ち切る**（最上位ルール 15）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t162-mediawiki-diagnose.md"
UA="daily-hack-ops/1.0 (https://daily-hack.fieldbeside.com; contact via GitHub)"

{
  echo "# MediaWiki API が空を返す原因（t162・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**13 ブランド すべてで空**だった。データではなく呼び方の問題として見る。"
  echo "**応答の先頭 400 字をそのまま出す。加工しない。**"
  echo ""
} > "$OUT"

command -v curl >/dev/null 2>&1 || { echo "⚠️ **curl が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

show() {  # $1=見出し $2...=curl の引数
  local label="$1"; shift
  local body code
  code="$(curl -sS -o "${TMPDIR:-/tmp}/t162.body" -w '%{http_code}' --max-time 15 "$@" 2>&1 || echo 000)"
  body="$(head -c 400 "${TMPDIR:-/tmp}/t162.body" 2>/dev/null)"
  local n; n=$(wc -c < "${TMPDIR:-/tmp}/t162.body" 2>/dev/null | head -1 | tr -d ' ')
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  {
    echo "### $label"
    echo ""
    echo "- status **$code** / **$n bytes**"
    echo ""
    echo '```json'
    printf '%s\n' "$body"
    echo '```'
    echo ""
  } >> "$OUT"
}

echo "## ① \`-G\` ＋ \`--data-urlencode\`（t159 と同じ書き方）" >> "$OUT"; echo "" >> "$OUT"
show "prop=images / titles=日本航空" \
  -A "$UA" -G \
  --data-urlencode "action=query" \
  --data-urlencode "format=json" \
  --data-urlencode "prop=images" \
  --data-urlencode "imlimit=60" \
  --data-urlencode "titles=日本航空" \
  "https://ja.wikipedia.org/w/api.php"

echo "## ② URL に直接書く（**%エンコード済み**の「日本航空」）" >> "$OUT"; echo "" >> "$OUT"
show "prop=images（エンコード済み）" -A "$UA" \
  "https://ja.wikipedia.org/w/api.php?action=query&format=json&prop=images&imlimit=60&titles=%E6%97%A5%E6%9C%AC%E8%88%AA%E7%A9%BA"

echo "## ③ REST API の summary（\`originalimage\` が返る）" >> "$OUT"; echo "" >> "$OUT"
show "rest_v1 summary（エンコード済み）" -A "$UA" \
  "https://ja.wikipedia.org/api/rest_v1/page/summary/%E6%97%A5%E6%9C%AC%E8%88%AA%E7%A9%BA"

echo "## ④ 英語版で同じこと（\`Japan Airlines\`）" >> "$OUT"; echo "" >> "$OUT"
show "en / prop=images" -A "$UA" \
  "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=images&imlimit=60&titles=Japan%20Airlines"

echo "## ⑤ UA を外したらどうなるか（弾かれているかの切り分け）" >> "$OUT"; echo "" >> "$OUT"
show "en / UA 指定なし" \
  "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=images&imlimit=20&titles=Japan%20Airlines"

{
  echo "---"
  echo ""
  echo "**読み方**"
  echo ""
  echo "- \`\"missing\":\"\"\` が入っていれば**記事名が違う**（リダイレクトを追う必要がある）"
  echo "- \`\"error\"\` が入っていれば**呼び方が違う**"
  echo "- status が **403 / 429** なら**弾かれている**（UA かレート）"
  echo "- ①だけ空で②が返るなら、**\`-G --data-urlencode\` の書き方が原因**"
  echo ""
  echo "**次の一手はこの応答を見てから決める。推測でもう 1 往復しない。**"
} >> "$OUT"

rm -f "${TMPDIR:-/tmp}/t162.body"
cat "$OUT"
