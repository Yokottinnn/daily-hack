#!/bin/bash
# **花火の告知で画像が付かなかった原因を読む（x331）。読むだけ。費用 $0。**
# run-publish.sh の 1 本だけの経路（post-via-playwright.js）が画像をどう付けるかと、10/18 に画像が付いた投稿との違いを見る。
# **投稿しない・画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/post-image-path.md"
mask() { sed -E -e 's#(auth_token=|ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 画像が付かなかった原因を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo "## 1. run-publish.sh の 1 本だけの経路（140〜200 行）"
echo '```'; sed -n '28,40p;140,200p' "$S/run-publish.sh" | cut -c1-260 | mask; echo '```'
echo "## 2. post-via-playwright.js の全体（行番号つき）"
echo '```'; nl -ba "$S/post-via-playwright.js" | cut -c1-230 | mask | head -260; echo '```'
echo "## 3. 予約ジョブの出力ファイル（stderr 側）"
echo '```'; tail -n 30 "$W/logs/publish-hanabi-oneshot-out.log" "$W/logs/publish-hanabi-oneshot-err.log" 2>&1 | cut -c1-260 | mask; echo '```'
echo "## 4. text-safety の上限まわり（長文で何かを切っていないか）"
echo '```'; grep -n -iE 'maxWeighted|truncate|slice\(0|image' "$W/lib/text-safety.js" 2>/dev/null | head -20 | cut -c1-200; echo '```'
echo "**読んだだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x331 / $(basename "$OUT")"
