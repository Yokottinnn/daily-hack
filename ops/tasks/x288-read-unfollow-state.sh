#!/bin/bash
# **アンフォローの 2 本（follow-balance・mutual-prune）が実際に何をしたかを読む。何も押さない。費用 $0。**
# 利用者の指摘（2026-10-14）: 「フォローされていないのにこちらからフォローしているアカウントがいたり、相互だけど比率が全然たいしたことなかったり…言われたことやっていない気がする」
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-state.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# アンフォローの実際（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も押していない）"
for L in follow-balance mutual-prune; do
  echo; echo "## $L"; echo '```'
  launchctl print "gui/$(id -u)/ai.openclaw.$L" 2>&1 | grep -E "state =|runs =|last exit code" | head -3
  P="$HOME/Library/LaunchAgents/ai.openclaw.$L.plist"
  echo "定時: $(plutil -extract StartCalendarInterval json -o - "$P" 2>/dev/null | head -c 300) $(plutil -extract StartInterval raw "$P" 2>/dev/null)"
  echo "--- ログ（直近 2 日の要点）"
  grep -E "start|実数|比率|目標|GLIDE|外す候補|外した|quota|今回|片思い|done|end|下限|警戒|外さない" "$W/logs/$L.log" 2>/dev/null | grep -E "2026-10-1[234]" | sed -E 's/^\[([^]]*)\] /\1 /' | hide | tail -40
  echo '```'
done
echo; echo "## follow-balance.js の「何件外すか」を決める行（300〜380 行）"; echo '```javascript'
sed -n 300,380p "$S/follow-balance.js" | hide
echo '```'
echo; echo "## 片思いの記録（reply-followers.json）"; echo '```'
node -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const now=Date.now();
const rows=Object.values(j).filter(v=>v&&typeof v==="object");
const st={};rows.forEach(r=>{const s=String(r.followback_status||"(無し)");st[s]=(st[s]||0)+1});
const pend=rows.filter(r=>/pending|no/.test(String(r.followback_status))&&r.followed_at&&now-Date.parse(r.followed_at)>86400000&&!r.unfollowed_at);
console.log("状態の分布: "+JSON.stringify(st));
console.log("24 時間を過ぎて、まだ返っていない・外していない（記録上）: "+pend.length+" 件");
' "$W/data/reply-followers.json" 2>&1
echo '```'
echo; echo "**何も押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "アンフォローの実際を読んだ / $(basename "$OUT")"
