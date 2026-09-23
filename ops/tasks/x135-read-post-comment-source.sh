#!/bin/bash
# **`post-comment.js` に画像添付を足すために、実物を読む。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `x134` の §1 で確定した。**reply に画像は付かない。**
#
#   run-publish.sh:122  const cmd = `node scripts/post-comment.js "${textB64}" "${prevUrl}"`;
#                       ↑ **imagePath がどこにも無い**
#   post-comment.js:20  const [textArg, targetUrl] = process.argv.slice(2);
#                       ↑ **引数が 2 つ。setInputFiles も 0 箇所**
#
# スキーマのコメントには `thread_chain[]: [{text, role, image_path?, url?}]` と
# 書いてあるのに、**実装は 1 本目にしか効かない。** 書いたとおりに積んでも
# **エラーは出ず、画像だけ黙って消える。**
#
# ## 直す前に読む（**当て推量でパッチを当てない**）
#
# `post-via-playwright.js` は同じことを既にやっている。**その書き方を写す**のが確実で、
# セレクタも待ちも実績があるものになる。**想像で書くと、また黙って落ちる。**
#
# ## 読むだけ。投稿しない・積まない・ファイルを書き換えない
#
# **測るものと直すものを同じタスクに入れない**（最上位ルール 15）。
#
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るのでハンドルと秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/post-comment-source.md"
CMT="$W/scripts/post-comment.js"
PUBJS="$W/scripts/post-via-playwright.js"
RUN="$W/scripts/run-publish.sh"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# reply に画像を足すために実物を読む（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 投稿も、積むことも、書き換えもしていない。"

echo
echo "## 0. 大きさ"
echo
echo '```'
for f in "$CMT" "$PUBJS" "$RUN"; do
  if [ -f "$f" ]; then
    printf '  %-28s %5s 行  %8s bytes\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')" "$(wc -c < "$f" | tr -d ' ')"
  else
    printf '  **無い** %s\n' "$f"
  fi
done
echo '```'
[ -f "$CMT" ] || { echo; echo "- **post-comment.js が無い。ここで止まる。**"; exit 1; }

echo
echo "## 1. \`post-comment.js\` の全文"
echo
echo "**足す場所を決めるために通しで読む。** 引数の受け口・投稿ボタンの押し方・"
echo "返している JSON の形が要る。"
echo
echo '```javascript'
cat -n "$CMT" 2>/dev/null | clean
echo '```'

echo
echo "## 2. \`post-via-playwright.js\` の画像添付（**この書き方を写す**）"
echo
echo "同じことを既にやっている箇所。**セレクタも待ちも実績がある。**"
echo
echo '```javascript'
sed -n '25,110p' "$PUBJS" 2>/dev/null | cat -n | clean
echo '```'

echo
echo "## 3. \`run-publish.sh\` の reply を組み立てている行の前後"
echo
echo "**ここに \`imagePath\` を足す。** 行番号を確かめる。"
echo
echo '```bash'
sed -n '110,135p' "$RUN" 2>/dev/null | cat -n | clean
echo '```'

echo
echo "---"
echo
echo "## 直すときの注意（**このタスクでは直さない**）"
echo
echo "- **macOS には \`sed -i\` が無い**（\`-i ''\` が要る）。**\`awk\` で書いて \`mv\`**（最上位ルール 14）"
echo "- **一時ファイルに \`.new\` を付けない。** node が拡張子で弾く。隠しファイル名にする"
echo "- **\`playwright\` ではなく \`playwright-core\`**（契約書 §1）"
echo "- **書き換えたら \`node --check\` を通す。** 通らなければ元に戻す"
echo "- **元ファイルのバックアップを取ってから書く。** 投稿経路の本体である"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'setInputFiles' "$OUT" 2>/dev/null; then
  echo "post-comment.js と添付の実装を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
