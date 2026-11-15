#!/bin/bash
# x501（2026-11-15・読むだけ・$0）: フォロー前に「プロフィールを眺める」「ときどき相手の投稿にいいね」を入れる前に、follow-handle.js の全文を読む
# 利用者がダイアログで「フォロー前にプロフィールを眺める」「ときどき相手の投稿にいいねしてからフォロー」を選んだ。秘密は出さない（トークン類の行は伏せる）
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/scripts/follow-handle.js"
OUT="${OPS_REPORT_DIR:-/tmp}/x501-read-follow-handle-full.md"
{
echo "# follow-handle.js の全文（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "$(wc -l < "$F" | tr -d ' ') 行・$(wc -c < "$F" | tr -d ' ') bytes"; echo '```js'
awk '{ if ($0 ~ /(TOKEN|SECRET|PASSWORD|API_KEY|Bearer )/) print NR": （伏せた）"; else print NR": "$0 }' "$F" | cut -c1-400
echo '```'
echo; echo "## いいねのボタンを押している既存のスクリプト（書き方を写すため）"; echo '```'
grep -ln 'data-testid="like"\|testid\$="like"\|\[data-testid=.like.\]' "$W/scripts/"*.js 2>/dev/null | head -5
for f in $(grep -l 'data-testid="like"\|\[data-testid=.like.\]' "$W/scripts/"*.js 2>/dev/null | head -2); do echo "--- $(basename "$f")"; grep -n 'like' "$f" | head -15 | cut -c1-240; done
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
head -3 "$OUT" | tail -1
exit 0
