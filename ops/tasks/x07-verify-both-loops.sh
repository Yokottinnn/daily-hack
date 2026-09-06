#!/bin/bash
# **返信とアンフォローが本当に動いたかを、実物で確かめる。費用 $0。**
#
# ## なぜ要るか
#
# `x04` は `launchctl list` で **ロード済み・rc=0** を確認し、
# `kickstart -k` も打った。だが**私の待ち時間が 10 秒と短く**、
# この処理は実績上 **3 分** かかる（`start 12:00:05 → picked 12:03:06`）。
# **結果を取り逃した。**
#
# CLAUDE.md にこう書いてある。
#
#   > **ログが動いても「ジョブが復活した」証拠にならない。**
#
# **「起動した」ではなく「出た」を数字で示す。**
#
# ## 出すもの（すべて $0・LLM を呼ばない）
#
#   1. **今日 出た返信の本文と tweet_id**（キューから）
#   2. `comment-warmup.log` の今日の行（全部）
#   3. **アンフォローの前後**（`unfollowed` の件数・期限到来の残り）
#   4. `reply-followers-cleanup.log` の末尾
#   5. 3 系統のジョブのロード状態と最後の rc
#
# ## やらないこと
#
# **返信しない。アンフォローしない。投稿しない。ジョブを触らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-both-loops.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
TODAY="$(date '+%Y-%m-%d')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 返信とアンフォローは本当に出たか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **「起動した」ではなく「出た」を数字で示す。**"
echo "> \`x04\` は待ち時間 10 秒で結果を取り逃した（この処理は 3 分かかる）。"
echo "> **何も触らない。読むだけ。**"

echo
echo "## 1. ジョブのロード状態"
echo
echo '```'
for j in comment-warmup reply-followers-cleanup reply-followback-check \
         competitor-follower-follow hashtag-follow badge-followback; do
  lbl="ai.openclaw.$j"
  line="$(launchctl list 2>/dev/null | grep -F "$lbl" || true)"
  if [ -z "$line" ]; then printf '  **未ロード** %-34s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-34s PID=%-8s 最後のrc=%s\n", j, $1, $2}'; fi
done
echo '```'
echo
echo "**最後の rc が 0 以外なら失敗している。**"

echo
echo "## 2. 今日 出た返信（**本文つき**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }catch(e){ console.log("  キューが読めない"); process.exit(0); }
const today=process.argv[2];
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply"));
const mine=rows.filter(e=>String(e.created_at||e.posted_at||"").slice(0,10)===today);
console.log("  comment/reply 合計: "+rows.length+" 件");
console.log("  今日つくられた: "+mine.length+" 件");
if(!mine.length){ console.log("  **今日はまだ 1 件も出ていない。**"); }
const by={}; for(const e of mine) by[e.status||"(なし)"]=(by[e.status||"(なし)"]||0)+1;
Object.entries(by).forEach(([k,v])=>console.log("    "+String(k).padEnd(20)+v+" 件"));
mine.slice(-6).forEach((e,i)=>{
  console.log("");
  console.log("  --- "+(i+1)+" 件目 / status="+(e.status||"?")+" ---");
  console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
  const tid=e.x_tweet_id||e.tweet_id;
  if(tid) console.log("  → https://x.com/heng_ji31590/status/"+tid);
  else console.log("  → tweet_id なし（まだ出ていない）");
});
' "$W/data/post_queue.json" "$TODAY" 2>&1 | clean
echo '```'

echo
echo "### \`comment-warmup.log\` の今日の行"
echo
echo '```'
grep "$TODAY" "$W/logs/comment-warmup.log" 2>/dev/null | tail -40 | clean
echo '```'

echo
echo "## 3. アンフォローは外れたか"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let s; try{ s=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }catch(e){ console.log("  状態ファイルが読めない"); process.exit(0); }
const now=Date.now();
const by={}; let due=0, unfToday=0;
const today=process.argv[2];
for(const e of Object.values(s)){
  if(!e) continue;
  by[e.followback_status||"(なし)"]=(by[e.followback_status||"(なし)"]||0)+1;
  if(e.scheduled_unfollow_at && new Date(e.scheduled_unfollow_at).getTime()<=now) due++;
  if(String(e.unfollowed_at||"").slice(0,10)===today) unfToday++;
}
console.log("  総数: "+Object.keys(s).length+" 件");
Object.entries(by).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>console.log("    "+String(k).padEnd(34)+v+" 件"));
console.log("");
console.log("  **今日 外した数: "+unfToday+" 件**");
console.log("  期限到来で残っている: "+due+" 件");
if(unfToday>0) console.log("  → **外れている。実行役は生きている。**");
else if(due===0) console.log("  → 期限到来がゼロ。外すものが無い。");
else console.log("  → **まだ外れていない。**");
' "$W/data/reply-followers.json" "$TODAY" 2>&1 | clean
echo '```'

echo
echo "### \`reply-followers-cleanup.log\` の末尾"
echo
echo '```'
tail -25 "$W/logs/reply-followers-cleanup.log" 2>/dev/null | clean
echo '```'

echo
echo "## 4. 今日のフォロー"
echo
echo '```'
for f in "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")]"
  grep "$TODAY" "$f" 2>/dev/null | grep -oE '=== end: [0-9]+/[0-9]+ OK ===' | sed 's/^/    /'
done
echo '```'

echo
echo "---"
echo
echo "**何も触っていない。返信もアンフォローもフォローもしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**3 系統の実際の出力を確かめた（変更なし・\$0）** / $(basename "$OUT")"
