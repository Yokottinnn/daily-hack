#!/bin/bash
# x447（2026-11-10）: 高輪ゲートウェイの告知（x-news-20261109-takanawa）が出たか確かめ、出ていなければ今すぐ出す。
# 11/9 12:00 の予約（x439）は、Mac が 11/9 早朝から外とつながらず、出たかどうか分からないまま。
POST_APPROVAL_QUOTE="いますぐ投稿して頼むから"
POST_APPROVAL_AT="2026-11-10 00:2x JST（チャット）"
POST_SET_KEY="takanawa"
# **x_tweet_id がもう在れば絶対に出し直さない。** 別の誰か（Mac の Claude セッション）が同時に出している気配があれば止まる。
# LLM を呼ばない（$0）。ハンドルと秘密は伏せる。
set -uo pipefail
ID="x-news-20261109-takanawa"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
RUNNER="$S/publish-takanawa-oneshot.sh"; LOG="$W/logs/publish-takanawa-oneshot.log"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x447-post-takanawa-now.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g'; }
state() { "$NODE_BIN" -e '
const q=require(process.argv[1]);const r=(Array.isArray(q)?q:(q.queue||q.items||q.posts)).find(x=>x&&x.id===process.argv[2]);
console.log(r?JSON.stringify({status:r.status,x_tweet_id:r.x_tweet_id||null,t2:(r.thread_chain&&r.thread_chain[1]&&r.thread_chain[1].x_tweet_id)||null,last_result:r.last_result||null}):"NOENTRY");' "$D/post_queue.json" "$ID" 2>&1; }
{
echo "# 高輪の告知を確かめて、出ていなければ出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. いまのキュー"; echo '```'; S1="$(state)"; echo "$S1" | clean; echo '```'
echo; echo "## 2. 12:00 の予約のログ（末尾）"; echo '```'; tail -n 25 "$LOG" 2>/dev/null | cut -c1-220 | clean || echo "（ログなし）"; echo '```'
echo; echo "## 3. 出す"; echo '```'
TID="$(printf '%s' "$S1" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).x_tweet_id||"")}catch(e){console.log("")}})')"
BUSY="$(pgrep -fl "run-publish.sh $ID" 2>/dev/null | head -1)"
if [ "$S1" = "NOENTRY" ]; then echo "  キューに無い。出さない"
elif [ -n "$TID" ]; then echo "  もう出ている: https://x.com/heng_ji31590/status/$TID （出し直さない）"
elif [ -n "$BUSY" ]; then echo "  いま別の処理が出している最中。重ねない"
elif [ ! -f "$RUNNER" ]; then echo "  出すスクリプトが無い: $RUNNER"
else
  echo "  まだ出ていない → いま出す"; /bin/bash "$RUNNER" >/dev/null 2>&1; echo "  runner rc=$?"
fi
echo '```'
echo; echo "## 4. 出したあとのキュー"; echo '```'; state | clean; tail -n 6 "$LOG" 2>/dev/null | cut -c1-220 | clean; echo '```'
} > "$OUT" 2>&1
grep -E 'もう出ている|まだ出ていない|x_tweet_id|重ねない|無い' "$OUT" | head -4 | cut -c1-280
exit 0
