#!/bin/bash
# **`comment-warmup` の投稿経路を読む。読むだけ。費用 $0。**
#
# ## 直す対象の症状（`x145` の一次情報）
#
#   本文  「シも今年は結局満額いったわ😉」  ← **先頭 2 文字「アタ」が欠落**
#   親    （なし）                          ← **返信のつもりが単独投稿になった**
#   重み  28 / 280                          ← **長さ超過ではない**
#
# **この 2 つは、同じ原因の表と裏かもしれない。**
# 返信欄ではなく本体の投稿欄に打ち込み、かつフォーカスが載る前に打ち始めていれば、
# **親が付かず、先頭が落ちる。** 症状が両方 説明できる。
#
# ## 自分が当てたパッチを疑う（**先に自分を調べる**）
#
# **2026-09-23 に `x136` で `post-comment.js` を書き換えた**（返信に画像を添付する改造）。
# 壊れた投稿は **2026-09-25**。**時系列が合う。**
#
#   x136 が変えたもの
#     ① 引数を 2 つ → 3 つ（textArg, targetUrl, imageArg）
#     ② keyboard.type の直後に添付の処理を挿入
#     ③ run-publish.sh が imagePath を渡すように
#
# **②が本文を打つ直後に入っている。** 画像が無い経路で例外を投げたり、
# 添付待ちでフォーカスを奪っていれば、**先頭の欠落も親の欠落も起こりうる。**
#
# **だから「comment-warmup が post-comment.js を通るのか」を最初に確かめる。**
# 通らないなら自分のパッチは無関係。通るなら、まずそこを疑う。
#
# ## 何を出すか
#
#   ① plist（`.disabled` にしたが**中身は読める**）— どのスクリプトを、どの環境変数で回すか
#   ② そのスクリプトが**どこに投稿を投げているか**（`post-comment` / `post-via-playwright` / 別）
#   ③ 経路にあるスクリプトの**打ち込みと返信先の指定**（`keyboard.type` / `fill` / reply の作り）
#   ④ **`x136` のパッチが実際に入っているか**、そして `.bak-*` が残っているか
#   ⑤ 壊れた 1 件のログの**前後 40 行**（同じ周回で何が起きていたか）
#
# ## やらないこと
#
# **1 文字も書き換えない。ループを戻さない。投稿しない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
ID="2103379894306750770"
OUT="${OPS_REPORT_DIR:-/tmp}/warmup-post-path.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(xoxb-)[A-Za-z0-9-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

cnt() { c="$(grep -c "$1" "$2" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0 ;; esac; printf '%s' "$c"; }

{
echo "# \`comment-warmup\` の投稿経路（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。書き換えていない。ループも戻していない。**"
echo "> 症状は 2 つ。**先頭 2 文字の欠落**と**親が付かないこと。**"

echo
echo "## 1. plist（\`.disabled\` でも中身は読める）"
echo
P=""
for c in "$LA/ai.openclaw.comment-warmup.plist.disabled" "$LA/ai.openclaw.comment-warmup.plist"; do
  [ -f "$c" ] && { P="$c"; break; }
done
if [ -z "$P" ]; then
  echo "- **plist が見つからない。**"
  echo
  echo '```'
  ls -1 "$LA" 2>/dev/null | grep -i "comment" | sed 's/^/  /'
  echo '```'
else
  echo "読んだファイル: \`$(basename "$P")\`"
  echo
  echo '```'
  /usr/libexec/PlistBuddy -c "Print" "$P" 2>/dev/null | clean | sed 's/^/  /'
  echo '```'
fi

echo
echo "## 2. 入口のスクリプトは、どこへ投稿を投げているか"
echo
ENTRY="$S/comment-warmup.js"
[ -f "$ENTRY" ] || ENTRY="$(ls -1 "$S"/comment-warmup* 2>/dev/null | head -1)"
if [ -z "${ENTRY:-}" ] || [ ! -f "$ENTRY" ]; then
  echo "- **入口が見つからない。**"
  echo
  echo '```'
  ls -1 "$S" 2>/dev/null | grep -i "comment\|warmup" | sed 's/^/  /'
  echo '```'
else
  echo "読んだファイル: \`$(basename "$ENTRY")\`（$(wc -l < "$ENTRY" | tr -d ' ') 行）"
  echo
  echo "**投稿を投げている行**（他のスクリプトを呼んでいる箇所）:"
  echo
  echo '```javascript'
  grep -n "post-comment\|post-via-playwright\|run-publish\|queue-manager\|execSync\|spawnSync\|require(\"\./" "$ENTRY" 2>/dev/null \
    | head -40 | cut -c1-260 | clean | sed 's/^/  /'
  echo '```'
  echo
  echo "**返信先をどう渡しているか**（url / target / in_reply の周辺）:"
  echo
  echo '```javascript'
  grep -n "reply\|target\|permalink\|status/\|url" "$ENTRY" 2>/dev/null \
    | head -40 | cut -c1-260 | clean | sed 's/^/  /'
  echo '```'
fi

echo
echo "## 3. \`x136\` のパッチは経路に入っているか（**先に自分を疑う**）"
echo
CMT="$S/post-comment.js"
echo '```'
if [ -f "$CMT" ]; then
  printf '  post-comment.js       %s 行  更新 %s\n' "$(wc -l < "$CMT" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$CMT" 2>/dev/null)"
  printf '  imageArg の有無        %s 箇所\n' "$(cnt 'imageArg' "$CMT")"
  printf '  setInputFiles の有無   %s 箇所\n' "$(cnt 'setInputFiles' "$CMT")"
else
  echo "  **post-comment.js が無い**"
fi
echo
echo "  --- バックアップ（x136 が取ったもの）---"
ls -1 "$S"/post-comment.js.bak-* 2>/dev/null | sed 's/^/  /' || echo "  （無い）"
echo '```'
echo
if [ -f "$CMT" ] && [ "$(cnt 'imageArg' "$CMT")" -gt 0 ]; then
  echo "**パッチは入っている。** 本文を打つ前後を通しで見る（**ここが本命**）:"
  echo
  echo '```javascript'
  awk '/keyboard\.type|insertText|\.fill\(|imagePaths|setInputFiles|waitForSelector|attachments/{print NR"\t"$0}' "$CMT" 2>/dev/null \
    | head -50 | cut -c1-260 | clean | sed 's/^/  /'
  echo '```'
  echo
  echo "**画像が無いとき（\`imageArg\` が無い／\`\"null\"\`）に添付処理を飛ばしているか:**"
  echo
  echo '```javascript'
  grep -n -B3 -A12 'imagePaths' "$CMT" 2>/dev/null | head -60 | cut -c1-260 | clean | sed 's/^/  /'
  echo '```'
else
  echo "- **パッチが入っていない。** \`x136\` は今回の原因ではない（別の経路を見る）"
fi

echo
echo "## 4. 打ち込みと返信先の作り（**経路にあるスクリプト全部**）"
echo
for f in "$S/post-comment.js" "$S/post-via-playwright.js"; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\`"
  echo
  echo "**フォーカスを載せてから打っているか**（\`click\` → \`type\` の順と待ち）:"
  echo
  echo '```javascript'
  grep -n "click()\|focus()\|keyboard\.type\|keyboard\.press\|waitForTimeout\|waitForSelector\|tweetTextarea\|DraftEditor" "$f" 2>/dev/null \
    | head -40 | cut -c1-260 | clean | sed 's/^/  /'
  echo '```'
  echo
done

echo
echo "## 5. 壊れた 1 件の周辺（**同じ周回で何が起きていたか**）"
echo
echo '```'
if [ -f "$L/comment-warmup.log" ]; then
  grep -n -B20 -A20 -- "$ID" "$L/comment-warmup.log" 2>/dev/null | cut -c1-260 | clean | sed 's/^/  /'
else
  echo "  **comment-warmup.log が無い**"
fi
echo '```'
echo
echo "同じ周回のエラー側（\`-err.log\` の末尾）:"
echo
echo '```'
[ -f "$L/comment-warmup-err.log" ] && tail -40 "$L/comment-warmup-err.log" 2>/dev/null | cut -c1-260 | clean | sed 's/^/  /'
echo '```'

echo
echo "---"
echo
echo "## 読み方（**このタスクでは直さない**）"
echo
echo "| 出方 | 何が起きているか |"
echo "| --- | --- |"
echo "| \`click\` の直後に待ちなしで \`keyboard.type\` | **フォーカスが載る前に打ち始めている。** 先頭欠落の定番 |"
echo "| 返信先の URL を組んでいない／空で渡している | **本体の投稿欄に打っている。** 親が付かない理由 |"
echo "| \`imagePaths\` が空でも添付処理に入る | **\`x136\` が犯人。** 本文の直後で例外かフォーカス奪取 |"
echo "| \`post-comment.js\` を通っていない | \`x136\` は無関係。**別の投稿口を読む** |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'keyboard\.type\|setInputFiles\|post-comment' "$OUT" 2>/dev/null; then
  echo "comment-warmup の投稿経路を読んだ / $(basename "$OUT")"
else
  echo "**読めていない。レポートを確認すること** / $(basename "$OUT")"
fi
