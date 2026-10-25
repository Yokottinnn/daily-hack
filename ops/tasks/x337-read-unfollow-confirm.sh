#!/bin/bash
# **follow-balance の「押したあと」（確認の確定と、外れたかの判定）を読む（x337）。読むだけ。費用 $0。**
# x336: 押すボタンは正しく `<id>-unfollow`（フォロー中）だった。だが結果が「購入する」になる。押した後の処理を読む。
# **押さない・外さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
S="$HOME/.openclaw/workspace/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-confirm.md"
{
echo "# 押したあとの処理を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'; nl -ba "$S/follow-balance.js" | sed -n '556,600p' | cut -c1-260 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; echo '```'
echo; echo "## mutual-prune.js の同じ処理（比べる）"; echo '```'
grep -n -E 'confirmationSheet|unfollow|外れた|外れていない' "$S/mutual-prune.js" | head -20 | cut -c1-220
echo '```'
echo "**読んだだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x337 / $(basename "$OUT")"
