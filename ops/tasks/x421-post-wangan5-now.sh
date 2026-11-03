#!/bin/bash
# **湾岸ニュース5選（お台場に直した版）を、いま 1 回だけ出す（x421）。費用 $0。**
# x414 で 11/4 8:00 に予約したが、x420（08:19）で出ていなかった: キューは awaiting_approval・ログは空（start の行も無い）・ジョブは外れていた。
# 利用者の指示は「明日投稿して」「時間は朝に投稿しておいて」、お台場に直した版を見て「投稿していいよ」。朝のうちに出し直す。
POST_APPROVAL_QUOTE="投稿していいよ"
POST_APPROVAL_AT="2026-11-03 23:1x JST（チャット・お台場に直した版を見たうえで）"
POST_SET_KEY="news-wangan-5"
#
# 作り: ① なぜ外れたかを読む（plist・tab-guard のログ）→ ② キューの中身が x414 で積んだ版のままかを確かめる
#       → ③ x414 が置いた 1 回きりのランナーをいま直接走らせる（run-publish.sh → キューへ書き戻し）→ ④ 結果を出す
# **二重投稿を防ぐ:** キューの状態が posted か x_tweet_id があれば走らせない。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
ID="x-news-20261104-wangan-5b"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
LABEL="ai.openclaw.publish-wangan5-oneshot"; UID_N="$(id -u)"
RUNNER="$S/publish-wangan5-oneshot.sh"; ALTF="$D/.x414-wangan5-alts.json"; IMGDIR="$D/x-wangan-news-5"
LOG="$W/logs/publish-wangan5-oneshot.log"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x421-post-wangan5-now.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g'; }
{
echo "# 湾岸ニュース5選をいま出し直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo; echo "## 1. なぜ外れたか（読むだけ）"; echo '```'
ls -la "$LA/$LABEL.plist" 2>&1 | sed "s#$HOME#~#"
ls -la "$LA"/*wangan5* 2>/dev/null | sed "s#$HOME#~#"
for f in "$W/logs/tab-guard.log" "$W/logs/tab-guard-err.log"; do [ -f "$f" ] && { echo "--- $(basename "$f") の該当行"; grep -nE 'wangan5|publish-.*oneshot|bootout|unload' "$f" | tail -8 | cut -c1-220 | hide; }; done
grep -rlE 'publish-wangan5' "$W/logs" 2>/dev/null | sed "s#$HOME#~#" | head -5
echo '```'
echo; echo "## 2. 走らせる前の確かめ"; echo '```'
[ -x "$RUNNER" ] || [ -f "$RUNNER" ] || { echo "ランナーが無い: $RUNNER。止める"; echo '```'; exit 1; }
[ -f "$ALTF" ] || { echo "ALT のファイルが無い。止める"; echo '```'; exit 1; }
ls "$IMGDIR" 2>&1 | head -5
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id===process.argv[2]); if(!e){console.log("FAIL キューに無い");process.exit(1);}
if(e.status==="posted"||e.x_tweet_id){console.log("FAIL もう出ている: "+e.x_tweet_id);process.exit(1);}
const t=(e.thread_chain||[]).map(c=>c&&(c.text||c.tweet_text||""));
const all=t.join("")+(e.text||e.tweet_text||"");
if(!all.includes("お台場・ダイバーシティ東京 プラザ")||all.includes("青海")){console.log("FAIL お台場に直した版ではない");process.exit(1);}
const imgs=String(e.image_path||(e.thread_chain&&e.thread_chain[0]&&e.thread_chain[0].image_path)||"").split(",").filter(Boolean);
for(const p of imgs){ if(!require("fs").existsSync(p)){console.log("FAIL 画像が無い: "+p.replace(process.env.HOME,"~"));process.exit(1);} }
console.log("OK status="+e.status+" ／ 文面 "+t.length+" 本 ／ 画像 "+imgs.length+" 枚 ／ ALT "+JSON.parse(require("fs").readFileSync(process.argv[3],"utf8")).length+" 本");' "$D/post_queue.json" "$ID" "$ALTF" 2>&1
PRC=$?
echo '```'
if [ "$PRC" -ne 0 ]; then echo "- **確かめで止めた。出していない。**"; exit 1; fi
echo; echo "## 3. いま走らせる"; echo '```'
/bin/bash "$RUNNER"; echo "runner rc=$?"
echo "--- ログの終わり"
tail -n 20 "$LOG" 2>/dev/null | cut -c1-240 | hide
echo '```'
echo; echo "## 4. キューの結果（一次情報）"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id===process.argv[2]);
console.log(JSON.stringify({status:e&&e.status,x_tweet_id:e&&e.x_tweet_id||null,thread_chain_ids:((e&&e.thread_chain)||[]).map(c=>c&&c.x_tweet_id||null),last_result:e&&e.last_result||null}));' "$D/post_queue.json" "$ID" 2>&1
launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1 && echo "ジョブ: 載っている" || echo "ジョブ: 載っていない（ランナーが自分を外した）"
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
