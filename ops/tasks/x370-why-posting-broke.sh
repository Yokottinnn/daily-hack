#!/bin/bash
# **10/28 ごろから X に出せなくなった原因を、残っている記録から分析する（x370）。読むだけ・押さない・$0。**
# 利用者「原因を分析して。それができないのなら意味がないでしょう」（2026-10-29）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x370-why-posting-broke.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g; s/(auth_token|ct0)=[A-Za-z0-9]+/$1=<伏せ>/g'; }
{
echo "# X に出せなくなった原因の分析（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. 返信の結果の推移（comment-warmup.log・日ごと・成功と失敗の段）"; echo '```'
grep -hE '^\{"ok":(true|false)' "$W/logs/comment-warmup.log" 2>/dev/null | tail -400 | "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const m={};for(const l of s.split("\n")){if(!l)continue;let j;try{j=JSON.parse(l)}catch{continue}
 const d=(String(j.entry_id||"").match(/comment-(\d{8})/)||[])[1]||"?";const k=j.ok?"ok":("NG:"+(j.step||"")+":"+String(j.error||"").slice(0,50));m[d]=m[d]||{};m[d][k]=(m[d][k]||0)+1}
 for(const d of Object.keys(m).sort().slice(-6))console.log(d,JSON.stringify(m[d]))})'
echo '```'
echo; echo "## 2. 返信のログの最後 25 行（10/27 以降の失敗の中身）"; echo '```'
tail -25 "$W/logs/comment-warmup.log" 2>/dev/null | cut -c1-260 | hide
echo '```'
echo; echo "## 3. 返信の入力欄が開けなかったときの画面（最新の保存 HTML から、見えている文字）"; echo '```'
F=$(ls -t /tmp/post-comment-no-textarea-*.html 2>/dev/null | head -1); echo "ファイル: $F（$(ls -t /tmp/post-comment-no-textarea-*.html 2>/dev/null | wc -l | tr -d ' ') 件）"
[ -n "$F" ] && "$NODE_BIN" -e '
const s=require("fs").readFileSync(process.argv[1],"utf8");
const t=s.replace(/<script[\s\S]*?<\/script>|<style[\s\S]*?<\/style>/g,"").replace(/<[^>]+>/g,"\n").replace(/&nbsp;/g," ").split("\n").map(x=>x.trim()).filter(x=>x&&x.length<160);
console.log("title:",(s.match(/<title>([^<]*)/)||[])[1]);console.log(t.slice(0,60).join(" | "));' "$F" | hide
echo '```'
echo; echo "## 4. 投稿キューの 10/27 以降（状態と失敗の段）"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const a=(q.queue||[]).filter(e=>e&&String(e.created_at||e.posted_at||e.scheduled_at||"")>="2026-10-27");
const m={};for(const e of a){const k=(e.kind||"")+":"+(e.status||"")+(e.x_tweet_id?":id":"");m[k]=(m[k]||0)+1}console.log(JSON.stringify(m));
for(const e of a.filter(e=>e.status!=="posted").slice(-5))console.log(e.id,e.status,String(e.last_error||e.error||"").slice(0,160));' "$W/data/post_queue.json" 2>&1 | hide
echo '```'
echo; echo "## 5. 自分の最新の投稿が見えるか（ログインしていない状態の公開 API で）"; echo '```'
curl -s -m 20 "https://cdn.syndication.twimg.com/timeline-profile/screen-name/heng_ji31590" | head -c 300; echo
echo '```'
echo; echo "## 6. Chrome のログイン状態（X の cookie があるか・値は出さない）"; echo '```'
cd "$W" && "$NODE_BIN" -e '
const {chromium}=require("playwright-core");(async()=>{try{const b=await chromium.connectOverCDP(process.env.CDP_URL||"http://127.0.0.1:18810",{timeout:30000});
const c=await b.contexts()[0].cookies("https://x.com");const names=c.map(x=>x.name);console.log("cookie:",["auth_token","ct0","twid"].map(n=>n+"="+(names.includes(n)?"あり":"なし")).join(" "));
const exp=c.find(x=>x.name==="auth_token");if(exp)console.log("auth_token の期限:",exp.expires>0?new Date(exp.expires*1000).toISOString():"セッション");}catch(e){console.log("読めない",e.message)}process.exit(0)})()' 2>&1
echo '```'
echo "**読んだだけ。押していない（\$0）。**"
} > "$OUT" 2>&1
echo "x370 / $(basename "$OUT")"
