#!/bin/bash
# **post-comment.js の「欄の中身が打った文と違う」を読む。読むだけ。費用 $0。**
#
# x245 で JAL [2/2] を出そうとして、次で止まった（送っていない）。
#   {"ok":false,"step":"text-mismatch","error":"欄の中身が打った文と違う。送らない","want_len":180,"got_len":182,...}
# 19:55 の x243 の [2/2] も `thread-reply-1-exec` で落ちている。
# **推測で直さない**（最上位ルール 20）。比べ方と打ち方の実物を書き出す。
#
#   ① text-mismatch を出している比較の前後 50 行
#   ② 文字を打つところ（type / insertText / keyboard）
#   ③ ファイルの更新日時と、印（x154 など）の一覧
#
# **投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

F="$HOME/.openclaw/workspace/scripts/post-comment.js"
OUT="${OPS_REPORT_DIR:-/tmp}/read-post-comment-mismatch.md"
hide() { sed -E "s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g; s#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g"; }

{
echo "# post-comment.js の text-mismatch（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
if [ ! -f "$F" ]; then echo "**post-comment.js が無い**"; exit 1; fi
printf -- '- %s 行・更新 %s\n' "$(wc -l < "$F" | tr -d ' ')" "$(stat -f '%Sm' -t '%m/%d %H:%M' "$F")"
echo
echo "## ① 比較の前後"
echo
echo '```javascript'
L="$(grep -n 'text-mismatch' "$F" | head -1 | cut -d: -f1)"
if [ -n "$L" ]; then
  S=$(( L > 50 ? L - 50 : 1 ))
  awk -v s="$S" -v e="$((L + 8))" 'NR>=s && NR<=e { printf "%4d  %s\n", NR, $0 }' "$F" | cut -c1-220 | hide
else echo "（text-mismatch が見つからない）"; fi
echo '```'
echo
echo "## ② 打つところ"
echo
echo '```javascript'
grep -n -E 'insertText|keyboard\.(type|press|insertText)|\.type\(|\.fill\(|innerText|textContent|normalize|replace\(/' "$F" | head -40 | cut -c1-220 | hide
echo '```'
echo
echo "## ③ 印"
echo
echo '```'
grep -n -o -E 'x[0-9]{2,3}[:：]?[^"]{0,40}' "$F" | head -30 | cut -c1-120 | hide
echo '```'
echo
echo "**投稿していない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "post-comment.js の比較を書き出した / $(basename "$OUT")"
