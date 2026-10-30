#!/bin/bash
# **関所を外したあと、投稿・返信・フォロー・フォロー解除が実際に動いているかを一次情報で確かめる（x378）。読むだけ・$0。**
# 利用者「いま投稿や返信・フォローアンフォローなどすべて正常に動いている？」（2026-10-30）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x378-health.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 関所を外したあとの動き（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. キュー：2026-10-30 01:00 JST 以降に出たもの（x_tweet_id あり）と、積んだまま出ていないもの"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const since="2026-10-29T16:00:00Z";
const a=(q.queue||[]).filter(e=>e&&String(e.posted_at||e.created_at||e.enqueued_at||"")>=since);
const posted=a.filter(e=>e.x_tweet_id), pend=a.filter(e=>!e.x_tweet_id);
const k=x=>x.reduce((m,e)=>(m[e.kind||"?"]=(m[e.kind||"?"]||0)+1,m),{});
console.log("出た:",JSON.stringify(k(posted)),"／ 出ていない:",JSON.stringify(k(pend)));
posted.slice(-8).forEach(e=>console.log("  出た",e.kind,e.posted_at,"https://x.com/heng_ji31590/status/"+e.x_tweet_id));
pend.slice(-5).forEach(e=>console.log("  未",e.kind,e.id,e.status));' "$W/data/post_queue.json" 2>&1
echo '```'
echo; echo "## 2. フォロー・フォロー解除：2026-10-30 01:00 JST 以降（reply-followers.json）"; echo '```'
"$NODE_BIN" -e '
const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const since=Date.parse("2026-10-29T16:00:00Z");
let f=0,u=0;const fs={},us={};for(const v of Object.values(r)){if(v.followed_at&&Date.parse(v.followed_at)>=since){f++;fs[v.source||"?"]=(fs[v.source||"?"]||0)+1}if(v.unfollowed_at&&Date.parse(v.unfollowed_at)>=since){u++;us[v.unfollow_source||"?"]=(us[v.unfollow_source||"?"]||0)+1}}
console.log("フォロー",f,JSON.stringify(fs));console.log("フォロー解除",u,JSON.stringify(us));' "$W/data/reply-followers.json" 2>&1
echo '```'
echo; echo "## 3. 各ジョブのログの最後（失敗の有無）"; echo '```'
for L in comment-warmup follow-balance mutual-prune hashtag-follow competitor-follower-follow incoming-reply-watcher; do
  F="$W/logs/$L.log"; [ -f "$F" ] || continue
  echo "--- $L（最終更新 $(stat -f '%Sm' -t '%m/%d %H:%M' "$F")）"; tail -4 "$F" | cut -c1-200 | hide
done
echo '```'
echo; echo "## 4. 関所の付いた処理が残っていないか・30 分以上動いている X 系の node"; echo '```'
ps eww -axo pid=,command= 2>/dev/null | grep -E 'node .*scripts/' | grep -c 'x-action-guard' | head -1
ps -axo pid,etime,command | grep -E 'node .*scripts/' | grep -v grep | cut -c1-140
echo '```'
echo; echo "## 5. X 上の実物：自分の投稿（最新順）"; echo '```'
PROBE="$W/.x378-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/search?q=" + encodeURIComponent("from:heng_ji31590") + "&f=live", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await p.waitForTimeout(5000);
  r.latest = await p.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 8).map((a) => { const t = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]'); return (t ? t.getAttribute("datetime") : "") + " " + (tx ? tx.innerText.slice(0, 24).replace(/\s+/g, " ") : ""); }));
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -12 | hide; rm -f "$PROBE"
echo '```'
echo "**読んだだけ（\$0）。**"
} > "$OUT" 2>&1
echo "x378 / $(basename "$OUT")"
