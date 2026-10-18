#!/bin/bash
# **フォロワー500人のお礼を、いま 1 投稿で出す（GIF 1 枚）。費用 $0。**
POST_APPROVAL_QUOTE="この内容で大丈夫！ いますぐ投稿して！"
POST_APPROVAL_AT="2026-10-18 21時台 JST（チャット）"
#
# 文面は posts.json の follower-500[0]（ロックのハッシュと照合）。画像は public/images/follower-500/x/1-card.gif（A 版の動く版・コメント 6 件反映済み）。
# 出たあと、permalink を開いて本文と画像の有無を読む（画面は撮らない）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-follower-500.md"
LOCK="$W/data/.x325-follower-500.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-follower-500"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261018-follower-500"
ME="heng_ji31590"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# フォロワー500人のお礼を出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## 0. もう出ていないか"
echo
BEFORE="$("$NODE_BIN" -e 'try{const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log((q.queue||[]).filter(e=>e&&e.id===process.argv[2]&&(e.status==="posted"||e.x_tweet_id)).length)}catch(e){console.log(-1)}' "$QJSON" "$ID")"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "- **キューが読めない。何もしない。**"; exit 1; fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then echo "- **既に出ている。何もしない。**"; exit 0; fi
if [ -f "$LOCK" ]; then echo "- **ロックがある。二重に走らせない。**"; exit 0; fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 1. 文面を origin/main から取り、ロックと照合する"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
T1="$("$NODE_BIN" -e '
const {execFileSync}=require("child_process"),crypto=require("crypto");const repo=process.argv[1];
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["follower-500"][0];
const L=JSON.parse(show("scripts/image-review/posts.lock.json")).locked["follower-500[0]"];
const ok=L&&L.sha256===crypto.createHash("sha256").update(t,"utf8").digest("hex");
if(!ok){console.error("  ロック **不一致**");process.exit(2);}
process.stdout.write(t);' "$REPO" 2>&1)"; RC=$?
echo "  rc=$RC / 文字 ${#T1}"
echo '```'
if [ "$RC" != "0" ]; then echo "- **文面が揃わない。出さない。** $T1"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 2. GIF を origin/main から取り出す"
echo
mkdir -p "$IMGDIR"; G="$IMGDIR/1-card.gif"
if git -C "$REPO" show "origin/main:public/images/follower-500/x/1-card.gif" > "$G" 2>/dev/null && [ "$(wc -c < "$G" | tr -d ' ')" -ge 500000 ]; then echo "- 取得 $(wc -c < "$G" | tr -d ' ') bytes"; else echo "- **GIF が取れない。出さない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 3. キューに積んで出す"
echo
echo '```'
"$NODE_BIN" -e '
const [id,t1,csv]=process.argv.slice(1);
console.log(JSON.stringify({id,kind:"thread",text:t1,image_path:csv,auto_publish:false,scheduled_at:new Date(Date.now()-60000).toISOString(),thread_chain:[{text:t1,role:"hook",image_path:csv}]}));' "$ID" "$T1" "$G" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -5 | clean
PUB="$(cd "$W" && /bin/bash "$RUNPUB" "$ID" 2>&1)"; PRC=$?
printf '%s\n' "$PUB" | tail -15 | cut -c1-500 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 4. キューへ書き戻す"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" -e '
const fs=require("fs");let raw="";process.stdin.on("data",d=>raw+=d).on("end",()=>{
 const [qp,id]=process.argv.slice(1);const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();
 let r=null;try{r=JSON.parse(line)}catch(e){}
 const q=JSON.parse(fs.readFileSync(qp,"utf8"));const e=(q.queue||[]).find(x=>x&&x.id===id);if(!e){console.log("  エントリなし");return;}
 e.auto_publish=false;const t1=r&&r.ok&&r.tweet_id;
 if(t1){e.status="posted";e.x_tweet_id=t1;e.posted_at=new Date().toISOString();if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=t1;}
 fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);
 console.log("  x_tweet_id="+(t1||"取れていない")+" ok="+(r&&r.ok)+(r&&!r.ok?(" step="+r.step+" error="+String(r.error||"").slice(0,200)+" child_stdout="+String(r.child_stdout||"").slice(0,400)):""));});' "$QJSON" "$ID" 2>&1 | clean
echo '```'

echo
echo "## 5. 実物を読む（permalink）"
echo
T1ID="$("$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);console.log((e&&e.x_tweet_id)||"")' "$QJSON" "$ID")"
if [ -n "$T1ID" ]; then
PROBE="$W/.x325-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, id] = process.argv.slice(2);
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto(`https://x.com/${me}/status/${id}`, { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
  r.items = await page.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 2).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const p = t && t.closest("a");
    return { href: p ? p.getAttribute("href") : null, len: tx ? tx.innerText.length : 0, head: tx ? tx.innerText.slice(0, 40) : "", media: a.querySelectorAll('[data-testid="tweetPhoto"], video, [data-testid="videoPlayer"], [data-testid="tweetGif"]').length }; }));
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$ME" "$T1ID" 2>&1 | tail -1 | clean
echo '```'
rm -f "$PROBE"
echo
echo "URL: https://x.com/$ME/status/$T1ID"
fi
echo
echo "**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
if grep -q 'x_tweet_id=[0-9]' "$OUT"; then echo "**フォロワー500人のお礼を出した** / $(basename "$OUT")"; else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
