#!/bin/bash
# **`thread_chain` の 2 本目（reply）に画像を付けられるかを読む。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# モーニング告知は **[1/2] が文字だけ、[2/2] に画像 1 枚**という形に決まった
# （2026-09-22 にダイアログで決定）。これまでの告知は全部 **1 本目に画像**で、
# **2 本目に画像を付けたことが一度も無い。**
#
# `docs/x-publisher-contract.md` §4 の例も `chain[0]` にしか `image_path` が無く、
# **reply が画像を受けるかどうかは書かれていない。**
#
# **推測で積むと、エラーも出さずに画像なしで出る**（契約書 §1 と同じ穴）。
# だから出す前に、実物のソースを読む。
#
# ## 読むだけ。投稿しない・キューに積まない・Chrome を触らない
#
# **測るものと直すものを同じタスクに入れない**（最上位ルール 15）。
# ここは測るだけで、投稿タスクは結果を見てから書く。
#
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るのでハンドルと秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-image-support.md"
PUB="$W/scripts/post-via-playwright.js"
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
echo "# \`thread_chain\` の reply に画像を付けられるか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 投稿していないし、キューにも積んでいない。"

echo
echo "## 0. ファイルが在るか"
echo
echo '```'
for f in "$PUB" "$RUN"; do
  if [ -f "$f" ]; then
    printf '  在る  %-34s %s bytes\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"
  else
    printf '  **無い** %s\n' "$f"
  fi
done
echo '```'
[ -f "$PUB" ] || { echo; echo "- **\`post-via-playwright.js\` が無い。ここで止まる。**"; exit 1; }

echo
echo "## 1. \`image_path\` をどこで読んでいるか"
echo
echo "**\`images\` ではなく \`image_path\`**（契約書 §3）。行番号つきで全部 出す。"
echo
echo '```'
grep -n 'image_path\|imagePath\|IMAGE' "$PUB" "$RUN" 2>/dev/null | head -40 | clean
echo '```'

echo
echo "## 2. reply を出している箇所の前後"
echo
echo "**1 本目と 2 本目で、画像を付ける処理が分かれているかを見る。**"
echo "分かれていて reply 側に無ければ、**[2/2] に画像は付かない。**"
echo
echo '```'
grep -n -B4 -A18 'reply\|thread_chain\|threadChain' "$PUB" 2>/dev/null | head -90 | clean
echo '```'

echo
echo "## 3. \`run-publish.sh\` が chain の各要素をどう渡しているか"
echo
echo '```'
if [ -f "$RUN" ]; then
  grep -n -B3 -A14 'thread_chain\|threadChain\|chain' "$RUN" 2>/dev/null | head -70 | clean
else
  echo "（run-publish.sh が無い）"
fi
echo '```'

echo
echo "## 4. ファイル入力（画像添付）の実装"
echo
echo "**X はファイル input に \`setInputFiles\` で渡す。** その呼び出しが"
echo "1 本目のときだけ走る作りなら、reply には付かない。"
echo
echo '```'
grep -n -B6 -A10 'setInputFiles\|input\[type="file"\]\|fileChooser' "$PUB" 2>/dev/null | head -60 | clean
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "- §2 / §4 で、**reply を出す経路から \`setInputFiles\` に到達できるか**を見る"
echo "- 到達できないなら、**[2/2] に画像は付けられない。** 形を決め直す必要がある"
echo "- **\`rc=0\` は証拠にならない**（最上位ルール 13）。ソースの行で判断する"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'setInputFiles' "$OUT" 2>/dev/null; then
  echo "reply への画像添付を読んだ（setInputFiles の箇所あり） / $(basename "$OUT")"
else
  echo "**画像添付の実装が見つからない。レポートを読むこと** / $(basename "$OUT")"
fi
