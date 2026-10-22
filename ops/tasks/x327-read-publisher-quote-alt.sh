#!/bin/bash
# **投稿の仕組み（run-publish.sh とその先）が「引用ポスト」と「画像の説明（ALT）」に対応しているかを読むだけ（x327）。費用 $0。**
# 花火の告知（B 案）は 7/6 の投稿を引用し、1 枚目の CC BY-SA の写真の撮影者名を ALT に書く必要がある。
# 対応していなければ、推測で積まずに直し方を決める。**投稿しない。画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/publisher-quote-alt.md"
mask() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=|ct0=)[A-Za-z0-9]+#\1<MASKED>#g' | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 投稿の仕組みは引用と ALT に対応しているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo "## 1. run-publish.sh が呼ぶもの"
echo '```'
grep -nE 'node|\.js|\.sh' "$S/run-publish.sh" 2>/dev/null | head -40 | mask
echo '```'
echo
echo "## 2. scripts/ と lib/ の中で quote / alt / attachment_url を扱っている行"
echo '```'
for d in "$S" "$W/lib"; do
  grep -rnE -i 'quote|attachment_url|alt_text|altText|"alt"|\.alt\b|AltTextInput|image.?description' "$d" --include='*.js' --include='*.sh' 2>/dev/null \
    | grep -v -E 'node_modules|\.bak|quoteIdent|JSON\.stringify' | head -60 | cut -c1-240 | mask
done
echo '```'
echo
echo "## 3. 投稿本体のファイル（run-publish.sh から辿れるもの）の、テキストと画像を入れる箇所"
echo '```'
for f in $(grep -oE '[A-Za-z0-9_./-]+\.js' "$S/run-publish.sh" 2>/dev/null | sort -u); do
  p="$S/$(basename "$f")"; [ -f "$p" ] || p="$W/$f"; [ -f "$p" ] || continue
  echo "--- $(basename "$p") ($(wc -l < "$p" | tr -d ' ') 行)"
  grep -nE -i 'setInputFiles|fileInput|tweetTextarea|insertText|keyboard\.type|image_path|thread_chain|quote|alt' "$p" | head -30 | cut -c1-220 | mask
done
echo '```'
echo
echo "**読んだだけ。投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x327 / $(basename "$OUT")"
