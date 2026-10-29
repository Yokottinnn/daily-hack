#!/bin/bash
# **x358 の投稿が出ているかを、プロフィールの実物で確かめる（x359）。読むだけ（見つかればキューに ID を書き戻す）・$0。**
# x358 は「投稿はしたが ID が取れない（fallback-scrape）」で終わった。押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x359-verify-cinema.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
QJSON="$W/data/post_queue.json"; ID="blog-promo-20261029-cinema-toyosu"
PROBE="$W/.x359-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(6000);
  r.items = await p.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 6).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const l = t && t.closest("a");
    return { href: l ? l.getAttribute("href") : null, time: t ? t.getAttribute("datetime") : null, head: tx ? tx.innerText.slice(0, 30) : "", media: a.querySelectorAll('[data-testid="tweetPhoto"]').length }; }));
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
{
echo "# 豊洲の映画館の投稿を確かめる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
RES=$(cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1); echo "$RES" | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
printf '%s' "$RES" | "$NODE_BIN" -e '
const fs=require("fs");let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let r={};try{r=JSON.parse(s)}catch(e){}
 const hit=(r.items||[]).find(i=>/heng_ji31590\/status\/\d+$/.test(i.href||"")&&/豊洲のユナイテッド/.test(i.head));
 if(!hit){console.log("**見つからない**");return;} const id=hit.href.split("/").pop();
 const [qp,eid]=process.argv.slice(1);const q=JSON.parse(fs.readFileSync(qp,"utf8"));const e=(q.queue||[]).find(x=>x&&x.id===eid);
 if(e&&!e.x_tweet_id){e.status="posted";e.x_tweet_id=id;e.posted_at=hit.time||new Date().toISOString();fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);}
 console.log("**出ている** x_tweet_id="+id+" 画像 "+hit.media+" 枚 時刻 "+hit.time+"\nURL: https://x.com/heng_ji31590/status/"+id);});' "$QJSON" "$ID"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x359 / $(basename "$OUT")"
