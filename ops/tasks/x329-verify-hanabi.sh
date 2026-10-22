#!/bin/bash
# **x325 の花火の告知（B 案）は出たか。プロフィールを読み、出ていればキューに書き戻す（x329）。再送しない。費用 $0。**
# x325 は GIF 付きで parse-main-result（stdout が空）に落ちた。契約書 §4 のとおり、この症状は「出ている」ことがある（x214）。
# **ok:false を「出ていない」と読んで再送すると二重投稿になる。** だから読むだけ。画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-hanabi.md"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261023-tokyo-bay-hanabi"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x329-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
  r.items = await page.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 6).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const p = t && t.closest("a");
    return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, head: tx ? tx.innerText.slice(0, 40) : "", len: tx ? tx.innerText.length : 0,
      media: a.querySelectorAll('[data-testid="tweetPhoto"], video, [data-testid="videoPlayer"], [data-testid="tweetGif"]').length }; }));
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" > "$W/.x329.json" 2>&1
{
echo "# 花火の告知（B 案）は出たか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const [jp,qp,id]=process.argv.slice(1);
let j;try{j=JSON.parse(fs.readFileSync(jp,"utf8").trim().split("\n").pop())}catch(e){console.log("  読めない");process.exit(0)}
if(j.error)console.log("  エラー: "+j.error);
(j.items||[]).forEach(x=>console.log("  "+(x.href||"-")+" | "+(x.at||"-")+" | 文字 "+x.len+" | 画像/動画 "+x.media+" | "+x.head.replace(/\n/g," ")));
const hit=(j.items||[]).find(x=>x.head&&x.head.includes("あんたにだけ教えるわね")&&x.href&&x.href.startsWith("/heng_ji31590/status/"));
if(!hit){console.log("\n  → **プロフィールに見当たらない**");process.exit(0)}
const tid=(hit.href.match(/status\/(\d+)/)||[])[1];
const q=JSON.parse(fs.readFileSync(qp,"utf8"));const e=(q.queue||[]).find(x=>x&&x.id===id);
if(e&&!e.x_tweet_id){e.status="posted";e.x_tweet_id=tid;e.posted_at=hit.at;e.auto_publish=false;if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=tid;
 fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);console.log("\n  → 出ていた。キューを posted に書き戻した x_tweet_id="+tid);}
else console.log("\n  → 出ていた x_tweet_id="+tid+"（キューは書き戻し済み、またはエントリなし）");
console.log("  URL: https://x.com/heng_ji31590/status/"+tid);' "$W/.x329.json" "$QJSON" "$ID" 2>&1 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo
echo "**再送していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$W/.x329.json"
echo "x329 / $(basename "$OUT")"
# 予約ジョブのログの末尾も添える（秘密とハンドルは伏せる）
{ echo; echo "## 予約ジョブのログ（末尾）"; echo '```'; tail -n 15 "$HOME/.openclaw/workspace/logs/publish-hanabi-oneshot.log" 2>/dev/null | cut -c1-300 | sed -E 's#(auth_token=|ct0=)[A-Za-z0-9]+#\1<MASKED>#g' | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; echo '```'; } >> "${OPS_REPORT_DIR:-/tmp}/verify-hanabi.md"
