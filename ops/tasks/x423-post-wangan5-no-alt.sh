#!/bin/bash
# **湾岸ニュース5選（お台場に直した版）を ALT 無しで、いま 1 回だけ出す（x423）。費用 $0。**
# x421（08:22）の出し直しは、1 枚目の ALT を付けたあと 2 枚目の ALT の途中で post-via-playwright.js が落ちた（x422・X には出ていない）。
# 利用者がダイアログで「ALT を付けずにいま出す」を選んだ。文面と画像は x414 で積んだもの（お台場の版）のまま。
# post-via-playwright.js の ALT の処理は ALT_TEXTS_FILE があるときだけ動くので、渡さずに出す（x268 と同じ）。
POST_APPROVAL_QUOTE="投稿していいよ"
POST_APPROVAL_AT="2026-11-03 23:1x JST（チャット・お台場に直した版を見たうえで）。2026-11-04 08:3x にダイアログで「ALT を付けずにいま出す」を選んだ"
POST_SET_KEY="news-wangan-5"
# **二重投稿を防ぐ:** キューが posted か x_tweet_id があれば出さない。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
ID="x-news-20261104-wangan-5b"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
WB="$S/.publish-wangan5-writeback.js"; LOG="$W/logs/publish-wangan5-oneshot.log"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x423-post-wangan5-no-alt.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-)[A-Za-z0-9-]+/<伏せ>/g; s/"[A-Za-z0-9+\/=]{40,}"/"<base64>"/g'; }
{
echo "# 湾岸ニュース5選を ALT 無しで出す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo; echo "## 1. 走らせる前の確かめ"; echo '```'
[ -f "$WB" ] || { echo "書き戻しのスクリプトが無い。止める"; echo '```'; exit 1; }
"$NODE_BIN" -e '
const fs=require("fs");const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id===process.argv[2]); if(!e){console.log("FAIL キューに無い");process.exit(1);}
if(e.status==="posted"||e.x_tweet_id){console.log("FAIL もう出ている: "+e.x_tweet_id);process.exit(1);}
const all=(e.thread_chain||[]).map(c=>c&&(c.text||c.tweet_text||"")).join("")+(e.text||e.tweet_text||"");
if(!all.includes("お台場・ダイバーシティ東京 プラザ")||all.includes("青海")){console.log("FAIL お台場に直した版ではない");process.exit(1);}
const imgs=String(e.image_path||(e.thread_chain&&e.thread_chain[0]&&e.thread_chain[0].image_path)||"").split(",").filter(Boolean);
for(const p of imgs){ if(!fs.existsSync(p)){console.log("FAIL 画像が無い");process.exit(1);} }
console.log("OK status="+e.status+" ／ 画像 "+imgs.length+" 枚");' "$D/post_queue.json" "$ID" 2>&1
PRC=$?
echo '```'
if [ "$PRC" -ne 0 ]; then echo "- **確かめで止めた。出していない。**"; exit 1; fi
echo; echo "## 2. いま出す（ALT_TEXTS_FILE を渡さない）"; echo '```'
cd "$W" || exit 1
echo "[$(date '+%F %T')] start x423 (ALT 無し)" >> "$LOG"
unset ALT_TEXTS_FILE
OUTP="$(/bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; RC=$?
printf '%s\n' "$OUTP" >> "$LOG"
printf '%s' "$OUTP" | "$NODE_BIN" "$WB" "$D/post_queue.json" "$ID" >> "$LOG" 2>&1
echo "[$(date '+%F %T')] done x423 rc=$RC" >> "$LOG"
awk '/start x423/{f=1} f' "$LOG" | tail -20 | cut -c1-300 | hide
echo '```'
echo; echo "## 3. キューの結果（一次情報）"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id===process.argv[2]);
console.log(JSON.stringify({status:e&&e.status,x_tweet_id:e&&e.x_tweet_id||null,thread_chain_ids:((e&&e.thread_chain)||[]).map(c=>c&&c.x_tweet_id||null),last_result:e&&e.last_result||null}));' "$D/post_queue.json" "$ID" 2>&1 | hide
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
