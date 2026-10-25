#!/bin/bash
# **返信の ID を記録するための下調べ（x346）。読むだけ。費用 $0。**
# 利用者が「返信の ID を記録する」を選んだ（2026-10-26）。返信を出すスクリプトが、出した返信の ID を受け取れているか・どこに書いているかを読む。
# **返信しない・押さない。他人のハンドルは伏せる。秘密は出さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-poster.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g; s/(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+/$1…/g; s/(xox[bp]-)[A-Za-z0-9-]+/$1…/g'; }
{
echo "# 返信を出す仕組みを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
for L in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher; do
  echo; echo "## $L の起動内容"; echo '```'
  launchctl print "gui/$(id -u)/$L" 2>&1 | grep -E 'state =|runs =|last exit|program|arguments|^\s+/|\.js' | head -15 | hide
  echo '```'
done
echo; echo "## 返信を出していそうなスクリプト（scripts/ の中で返信・投稿を呼ぶ箇所）"; echo '```'
cd "$W/scripts" 2>/dev/null && grep -lE 'post-comment|postReply|tweetButton|replyTo|in_reply_to' *.js 2>/dev/null | head -20
echo '```'
for f in comment-warmup.js comment-orchestrator.js post-comment.js incoming-reply-watcher.js; do
  P="$W/scripts/$f"; [ -f "$P" ] || continue
  echo; echo "## $f（$(wc -l < "$P") 行）: 投稿・結果・記録に関わる行"; echo '```'
  grep -nE 'post-comment|spawn|execFile|execSync|JSON\.parse|tweet_id|status/|reply_id|replyId|url|writeFileSync|appendFileSync|out\(|console\.log\(JSON|history|posted' "$P" | head -60 | cut -c1-220 | hide
  echo '```'
done
echo; echo "## post-comment.js の最後 40 行（何を返しているか）"; echo '```'
tail -40 "$W/scripts/post-comment.js" 2>/dev/null | cut -c1-220 | hide
echo '```'
echo; echo "## comment-warmup.log の直近の「出した」行（20 行）"; echo '```'
grep -E '✅|posted|投稿|replied|返信した|tweet_id|status/' "$W/logs/comment-warmup.log" 2>/dev/null | tail -20 | cut -c1-220 | hide
echo '```'
echo; echo "## comment-orchestrator.log の直近の「出した」行（20 行）"; echo '```'
grep -E '✅|posted|投稿|replied|返信した|tweet_id|status/' "$W/logs/comment-orchestrator.log" 2>/dev/null | tail -20 | cut -c1-220 | hide
echo '```'
echo "**読んだだけ。返信・クリックはしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x346 / $(basename "$OUT")"
