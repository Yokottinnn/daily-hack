#!/bin/bash
# **いま何件 出ているかを、一次情報だけで数える。費用 $0。**
#
# ## 聞かれたこと
#
#   > いま返信いくつ？
#
# **推測で答えない。** CLAUDE.md 最上位ルール 11 のとおり、
# 判定してよいのは **キューの `x_tweet_id` / `tweet_id`** だけ。
#
# ## 数えないもの（**一次情報ではない**）
#
#   * `heartbeat.json` の `posted_today` — **ログの行数**。二重計上する
#   * ログの grep 件数 — リトライが行ごとに残る
#   * 過去のレポート — **生成時刻の状態**であって「いま」ではない
#
# ## 出すもの
#
#   1. **このスクリプトが走った時刻**（レポートの鮮度を読む側が判断できるように）
#   2. 今日（JST）出た返信の **件数と、1 件ずつの時刻・URL**
#   3. `comment-warmup` / `reply-followers-cleanup` のロード状態と最後の rc
#   4. **アンフォローの実数**（`unfollowed_at` が今日のもの）
#
# ## やらないこと
#
# **投稿しない。返信しない。アンフォローしない。ジョブを触らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/count-replies-now.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
STATE="$W/data/reply-followers.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# いま返信は何件 出ているか"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **この時刻の状態である。** 読んだ時点の状態ではない。"
echo "> 数えたのは **キューの \`x_tweet_id\` だけ**（最上位ルール 11）。"
echo "> ログの行数・\`posted_today\`・過去のレポートは**使っていない**。"

echo
echo "## 1. 今日（JST）出た返信"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  **キューが読めない: "+e.message+"**"); process.exit(0); }
const jst=d=>new Date(d.getTime()+9*3600*1000).toISOString();
const today=jst(new Date()).slice(0,10);
const all=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply"));
const posted=all.filter(e=>e.x_tweet_id||e.tweet_id);
const when=e=>String(e.posted_at||e.created_at||"");
const mine=posted.filter(e=>when(e).slice(0,10)===today);
console.log("  今日の日付(JST): "+today);
console.log("");
console.log("  **今日 出た返信: "+mine.length+" 件**");
console.log("  投稿済み 累計   : "+posted.length+" 件");
console.log("  キュー上の comment/reply 総数: "+all.length+" 件");
console.log("");
if(!mine.length){
  console.log("  **今日は 0 件。**（この時刻時点で 0）");
} else {
  mine.forEach((e,i)=>{
    console.log("  --- "+(i+1)+"/"+mine.length+" ---");
    console.log("  時刻   : "+(when(e)||"日時なし"));
    console.log("  status : "+(e.status||"?"));
    console.log("  URL    : https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
    console.log("  本文   : "+String(e.text||"").replace(/\n/g,"\n           "));
    console.log("");
  });
}
// まだ出ていないもの
const pending=all.filter(e=>!(e.x_tweet_id||e.tweet_id)&&when(e).slice(0,10)===today);
console.log("  今日つくられたが **まだ出ていない**: "+pending.length+" 件");
const by={}; pending.forEach(e=>{const k=e.status||"(なし)"; by[k]=(by[k]||0)+1;});
Object.entries(by).forEach(([k,v])=>console.log("    "+String(k).padEnd(22)+v+" 件"));
' "$QJSON" 2>&1 | clean
echo '```'

echo
echo "## 2. アンフォローの実数（今日）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let s; try{ s=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  **状態ファイルが読めない: "+e.message+"**"); process.exit(0); }
const jst=d=>new Date(d.getTime()+9*3600*1000).toISOString();
const today=jst(new Date()).slice(0,10);
const now=Date.now();
let unfToday=0, unfTotal=0, due=0;
for(const e of Object.values(s)){
  if(!e) continue;
  if(e.unfollowed_at){ unfTotal++; if(String(e.unfollowed_at).slice(0,10)===today) unfToday++; }
  if(e.scheduled_unfollow_at && new Date(e.scheduled_unfollow_at).getTime()<=now
     && !e.unfollowed_at) due++;
}
console.log("  **今日 外した数: "+unfToday+" 件**");
console.log("  外した数 累計  : "+unfTotal+" 件");
console.log("  期限到来で未処理: "+due+" 件");
if(unfToday===0) console.log("");
if(unfToday===0) console.log("  → **0 件。まだ 1 件も外れていない。**");
' "$STATE" 2>&1 | clean
echo '```'

echo
echo "## 3. ジョブのロード状態（最後の rc）"
echo
echo '```'
for j in comment-warmup reply-followers-cleanup reply-followback-check \
         competitor-follower-follow hashtag-follow; do
  lbl="ai.openclaw.$j"
  line="$(launchctl list 2>/dev/null | grep -F "$lbl" || true)"
  if [ -z "$line" ]; then printf '  **未ロード** %-32s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-32s PID=%-8s 最後のrc=%s\n", j, $1, $2}'; fi
done
echo '```'

echo
echo "### \`comment-warmup\` の \`MAX_PICKS_PER_FIRE\`"
echo
echo '```'
P="$HOME/Library/LaunchAgents/ai.openclaw.comment-warmup.plist"
if [ -f "$P" ]; then
  V="$(plutil -extract EnvironmentVariables.MAX_PICKS_PER_FIRE raw "$P" 2>/dev/null || echo '(未設定)')"
  echo "  MAX_PICKS_PER_FIRE = $V"
  echo "  → 4 なら 16 件/日、2 なら 8 件/日"
else
  echo "  **plist が無い**"
fi
echo '```'

echo
echo "## 4. ポーラーは生きているか"
echo
echo '```'
launchctl list 2>/dev/null | grep -F 'com.dailyhack.ops-poller' \
  | awk '{printf "  ops-poller PID=%s 最後のrc=%s\n", $1, $2}' \
  || echo "  **ops-poller が未ロード**"
LK="$W/../ops-tasks.lock"
for d in "$HOME/.openclaw/ops/.tasks.lock" "$W/.tasks.lock"; do
  [ -e "$d" ] && echo "  ロック残存: $d ($(stat -f '%Sm' -t '%H:%M:%S' "$d" 2>/dev/null))"
done
echo '```'

echo
echo "---"
echo
echo "**何も触っていない。投稿もアンフォローもしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -m1 -oE '今日 出た返信: [0-9]+ 件' "$OUT" 2>/dev/null || echo '件数不明')"
U="$(grep -m1 -oE '今日 外した数: [0-9]+ 件' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') 時点** / $N / $U / $(basename "$OUT")"
