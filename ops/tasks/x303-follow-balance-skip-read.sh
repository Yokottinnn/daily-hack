#!/bin/bash
# **follow-balance が「片思い」と判断して外す部分と、外さない人（除外）の決め方を読む。費用 $0。**
# x302: badge-followback が返した認証済みフォロワー 185 人のうち 26 人が、あとで外す側のログに出た（follow-balance.log 70 行など）。
# 返し漏れ 3 人は follow-balance のデータに出ていた。認証済みフォロワーを片思いと誤って外している疑い。直す前に判定の作りを読む。
set -uo pipefail
W="$HOME/.openclaw/workspace"; F="$W/scripts/follow-balance.js"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-balance-skip-read.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# follow-balance の片思いの判定と除外（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```javascript'
grep -n -E "followers|whitelist|WHITELIST|skip|除外|verified|mutual|片思い|followsYou|Follows you|フォローされています|GRACE|candidates|prev\.json|lists\.json" "$F" | grep -v -i "token\|secret" | head -70
echo '```'
echo
echo "## follow-balance.log の「外した」行の形（直近 6 行・伏せ）"
echo '```'
grep -E "外し|unfollow|✂" "$W/logs/follow-balance.log" | tail -6 | hide | cut -c1-200
echo '```'
echo "**読むだけ。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "follow-balance の判定と除外を読んだ / $(basename "$OUT")"
