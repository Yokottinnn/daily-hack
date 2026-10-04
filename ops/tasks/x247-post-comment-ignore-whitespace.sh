#!/bin/bash
# **post-comment.js の text-mismatch を、空白・改行の数の違いでは止めないようにする。費用 $0。**
#
# ## 分かったこと（x246 で実物を読んだ）
#
#   * x150 のガードは「打った文」と「欄の innerText」を、末尾の空白だけ落として比べている（185 行目）
#   * X の入力欄は **空行 1 つにつき改行を 1 つ多く返す**。JAL [2/2] は空行が 2 つで、
#     **want_len 180 / got_len 182（+2）・先頭は一致**。中身は同じなのに送らなかった
#   * 19:55 の x243 の [2/2]（thread-reply-1-exec）も同じ所で落ちたと見られる
#
# ## 直すところ（1 か所）
#
#   比べる前に **空白・改行をすべて落としてから** 比べる（`replace(/\s+/g, "")`）。
#   **先頭が落ちた・文字が欠けたときは今までどおり止まる**（ガードの目的はそのまま）。
#   want_len / got_len の出力は変えない。
#
# 当たったかを文字列で確かめ、node --check が通らなければ置かない。控えを残す。
# **投稿しない（x248 で出す）。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

S="$HOME/.openclaw/workspace/scripts"
F="$S/post-comment.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BAK="$F.bak-x247-$STAMP"
TMP="$S/.post-comment-x247-$STAMP.js"
OUT="${OPS_REPORT_DIR:-/tmp}/post-comment-ignore-whitespace.md"

{
echo "# post-comment.js: 空白・改行の数の違いでは止めない（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo '```'
if [ ! -f "$F" ]; then echo "  **post-comment.js が無い**"; echo '```'; exit 1; fi
if grep -q 'x247:' "$F"; then echo "  もう当たっている（x247: の印がある）。何もしない"; echo '```'; exit 0; fi
cp "$F" "$BAK" && printf '  控え: %s\n' "$(basename "$BAK")"
node -e '
const fs = require("fs");
const [src, dst] = process.argv.slice(1);
let s = fs.readFileSync(src, "utf8");
const A = `      if (_norm(_got) !== _norm(text)) {`;
const k = s.split(A).length - 1;
if (k === 1) s = s.replace(A, `      // x247: X の入力欄は空行 1 つにつき改行を 1 つ多く返す（JAL [2/2] で 180 / 182・先頭は一致）。空白・改行は落として比べる
      const _x247sq = (v) => _norm(v).replace(/\\s+/g, "");
      if (_x247sq(_got) !== _x247sq(text)) {`);
fs.writeFileSync(dst, s);
console.log("  当たった数（1 なら当たり）: " + k);
if (k !== 1) process.exit(3);
' "$F" "$TMP"; RC=$?
if [ "$RC" -ne 0 ]; then echo "  **当たる場所が 1 か所 見つからない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
CK="$(node --check "$TMP" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -ne 0 ]; then echo "  **構文が通らない。置かない**（元のまま）"; rm -f "$TMP"; echo '```'; exit 1; fi
mv "$TMP" "$F"
printf '  置いた。%s 行\n' "$(wc -l < "$F" | tr -d ' ')"
echo '```'
echo
echo '```javascript'
grep -n -A3 'x247:' "$F" | cut -c1-200
echo '```'
echo
echo "- 戻すときは \`$(basename "$BAK")\` を post-comment.js に戻す"
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '置いた。' "$OUT"; then echo "post-comment.js の比較を直した / $(basename "$OUT")"
elif grep -q 'もう当たっている' "$OUT"; then echo "もう直っていた / $(basename "$OUT")"
else echo "**直せていない。元のまま** / $(basename "$OUT")"; exit 1; fi
