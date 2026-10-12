#!/bin/bash
# **競合の「認証済みフォロワー」からのフォローを、いま 1 回だけ走らせる（上限 10）。費用 $0。**
#
# ## なぜ（2026-10-12）
#
#   x278 でフォローの的を認証済みに寄せた。利用者が「いま競合からのフォローを 1 回走らせる」を選んだ。
#   **今回だけ上限を 10 にする。** plist の 30 のまま走らせると、フォロー中 200 → 最大 230 ／ フォロワー 345 で
#   比率 0.667 になり、帯（0.45〜0.65・最上位ルール 19）を超えうる。10 なら最大 210 ／ 345 ＝ 0.609。
#
#   1 件あたり プロフィールを読む ＋ 30 秒の間隔で、10 件なら 7〜8 分かかる。**タスクの 5 分を超える**ので
#   （最上位ルール 15）、**裏で起動して、このタスクはすぐ終える。** 結果は次のタスクで読む。
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/run-competitor-verified.md"
LOG="$W/logs/x279-competitor-verified.log"
{
echo "# 競合の認証済みフォロワーからのフォローを起動（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
if ! grep -q "x278" "$S/competitor-follower-follow.js" 2>/dev/null; then
  echo "**x278 が当たっていない。起動しない。**"; exit 0
fi
if pgrep -f "competitor-follower-follow.js" >/dev/null 2>&1; then
  echo "**もう走っている。二重に起動しない。**"; exit 0
fi
cd "$W" && nohup env COMPETITOR_FOLLOW_DAILY_CAP=10 FORCE_RUN=1 /usr/local/bin/node "$S/competitor-follower-follow.js" > "$LOG" 2>&1 < /dev/null &
PID=$!
sleep 3
if kill -0 "$PID" 2>/dev/null; then echo "- 起動した（pid $PID・上限 10・ログ \`logs/x279-competitor-verified.log\`）"; else echo "- **起動直後に終わった。** ログの先頭:"; echo '```'; head -20 "$LOG" | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; echo '```'; fi
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 結果は次のタスクで読む。"
} > "$OUT" 2>&1
echo "競合の認証済みフォロワーからのフォローを起動した / $(basename "$OUT")"
