#!/bin/bash
# x454（2026-11-10・読むだけ・$0）: 利用者「Xでの返信ってちゃんと動いてる？」。
# 直近 7 日の返信の件数（comment-warmup の ok:true）と、今日出た返信の投稿 ID を出す（クラウドから syndication で実物を確かめる）。
# 他人のハンドルは伏せる。投稿・いいねはしない。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/x454-read-replies-today.md"
{
echo "# 返信は出ているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 日ごとの件数（comment-warmup.log の ok:true・entry_id の日付）"; echo '```'
grep -hoE '^\{"ok":true,"entry_id":"comment-[0-9]{8}' "$L/comment-warmup.log" 2>/dev/null | sed -E 's/.*comment-//' | sort | uniq -c | tail -8
echo '```'
echo; echo "## 今日の返信の投稿 ID（新しい順に 12 件）"; echo '```'
grep -hE '^\{"ok":true' "$L/comment-warmup.log" 2>/dev/null | grep "comment-$(date '+%Y%m%d')" | grep -oE '"(reply_tweet_id|tweet_id|x_tweet_id)":"[0-9]{15,}"' | tail -12
echo '```'
echo; echo "## 直近の失敗（ok:false・末尾 6 件）"; echo '```'
grep -hE '^\{"ok":false' "$L/comment-warmup.log" 2>/dev/null | tail -6 | cut -c1-220 | perl -pe 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo; echo "## ジョブ"; echo '```'
for lb in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher ai.openclaw.quick-reply-watcher; do printf '%-40s ' "$lb"; launchctl print "gui/$(id -u)/$lb" 2>/dev/null | grep -E '^\s+(state|runs|last exit code) =' | tr -s ' \n' ' ' || echo "載っていない"; echo; done
echo '```'
} > "$OUT" 2>&1
grep -c '_id' "$OUT" | sed 's/^/ID の行: /'
exit 0
