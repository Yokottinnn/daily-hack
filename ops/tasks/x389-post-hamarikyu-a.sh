#!/bin/bash
# **チームラボ 浜離宮（A 発見型）の告知を、いま 2 投稿のスレッドで出す（[1/2] に画像 4 枚）。費用 $0。**
POST_APPROVAL_QUOTE="内容は大丈夫なので投稿して"
POST_APPROVAL_AT="2026-10-31 JST（チャット）"
POST_SET_KEY="hamarikyu"
#
# 文面は posts.json の hamarikyu[0]・[1]（[1/2] は 2026-10-31 に利用者がレビューページで書き換えた版を取り込み済み）。
# 画像は public/images/teamlab-hamarikyu-2026/x/ の 4 枚。**順は 利用者のコメント「4枚目が一番重要なので、これを2枚目の位置に持っていって」に従う**
#   1-cover → 4-yoru-300 → 2-access → 3-vs-toyosu
# 形は感謝祭（x314/x322）と同じ：thread_chain = [hook（画像 4 枚）, cta]。[1/2] は長文（重み 949・冒頭 252）
# 出たあと、permalink を開いて本文と画像の有無を読む（画面は撮らない）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-hamarikyu-a.md"
LOCK="$W/data/.x389-hamarikyu.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-hamarikyu"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261031-hamarikyu-a"
ME="heng_ji31590"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# チームラボ 浜離宮の告知を出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## 関所の付いた X 系の処理が残っていないか"
ps eww -axo pid=,command= 2>/dev/null | grep -E 'node .*scripts/' | grep 'x-action-guard' | grep -v grep | awk '{print "残っている: pid="$1}' | head -5
echo "## 送り方（x369 の直し）が入っているか"
if grep -qE 'x369:|x377:' "$W/scripts/post-via-playwright.js"; then echo "- 入っている"; else echo "- **入っていない。出さない。**"; exit 1; fi
unset NODE_OPTIONS
"$NODE_BIN" "$W/lib/x-action-pacer.cjs" wait tweet 120 2>&1 | head -2
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
echo "## 1. 文面を origin/main から取る"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
get() { "$NODE_BIN" -e '
const {execFileSync}=require("child_process");const repo=process.argv[1],i=Number(process.argv[2]);
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["hamarikyu"][i];
if(!t||t.length<50){console.error("  文面が無い");process.exit(2);}
if(i===0&&!t.includes("チームラボが始まる前の穴場ね")){console.error("  利用者の書き換えが入っていない");process.exit(3);}
process.stdout.write(t);' "$REPO" "$1" 2>&1; }
T1="$(get 0)"; RC1=$?; T2="$(get 1)"; RC2=$?; RC=$(( RC1 + RC2 ))
echo "  [1/2] rc=$RC1 / 文字 ${#T1}"; echo "  [2/2] rc=$RC2 / 文字 ${#T2}"
echo '```'
if [ "$RC" != "0" ]; then echo "- **文面が揃わない。出さない。** $T1"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 2. 画像 4 枚を origin/main から取り出す（300円の夜の公開を 2 枚目に）"
echo
mkdir -p "$IMGDIR"; CSV=""; ok=1
for f in 1-cover.jpg 4-yoru-300.jpg 2-access.jpg 3-vs-toyosu.jpg; do
  G="$IMGDIR/$f"
  if git -C "$REPO" show "origin/main:public/images/teamlab-hamarikyu-2026/x/$f" > "$G" 2>/dev/null && [ "$(wc -c < "$G" | tr -d ' ')" -ge 50000 ]; then echo "- $f: $(wc -c < "$G" | tr -d ' ') bytes"; CSV="${CSV:+$CSV,}$G"; else echo "- **$f が取れない**"; ok=0; fi
done
if [ "$ok" != 1 ]; then echo "- **画像が揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi
G="$CSV"

echo "## 3. キューに積んで出す"
echo
echo '```'
"$NODE_BIN" -e '
const [id,t1,t2,csv]=process.argv.slice(1);
console.log(JSON.stringify({id,kind:"thread",text:t1,image_path:csv,auto_publish:false,scheduled_at:new Date(Date.now()-60000).toISOString(),thread_chain:[{text:t1,role:"hook",image_path:csv},{text:t2,role:"cta"}]}));' "$ID" "$T1" "$T2" "$G" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -5 | clean
PUB="$(cd "$W" && /bin/bash "$RUNPUB" "$ID" 2>&1)"; PRC=$?
printf '%s\n' "$PUB" | tail -30 | cut -c1-700 | clean
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
 e.auto_publish=false;const tr=(r&&r.thread_results)||[];const t1=(r&&r.tweet_id)||(tr[0]&&tr[0].tweet_id);const t2=tr[1]&&tr[1].tweet_id;
 if(t1){e.status="posted";e.x_tweet_id=t1;e.posted_at=new Date().toISOString();if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=t1;if(t2&&e.thread_chain&&e.thread_chain[1])e.thread_chain[1].x_tweet_id=t2;}
 // [1/2] だけ出て [2/2] が落ちても、二重に出ないよう posted に書き戻す（契約書 §4）
 if(!t1&&tr[0]&&tr[0].ok&&tr[0].tweet_id){e.status="posted";e.x_tweet_id=tr[0].tweet_id;}
 fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);
 console.log("  x_tweet_id="+(t1||"取れていない")+" [2/2] x_tweet_id="+(t2||"取れていない")+" ok="+(r&&r.ok)+(r&&!r.ok?(" step="+r.step+" error="+String(r.error||"").slice(0,200)+" child_stdout="+String(r.child_stdout||"").slice(0,400)):""));});' "$QJSON" "$ID" 2>&1 | clean
echo '```'

echo
echo "## 5. 実物を読む（permalink）"
echo
T1ID="$("$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);console.log((e&&e.x_tweet_id)||"")' "$QJSON" "$ID")"
if [ -n "$T1ID" ]; then
PROBE="$W/.x389-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, id] = process.argv.slice(2);
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto(`https://x.com/${me}/status/${id}`, { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
  r.items = await page.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 3).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const p = t && t.closest("a");
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
if grep -q 'x_tweet_id=[0-9]' "$OUT"; then echo "**浜離宮の告知を出した** / $(basename "$OUT")"; else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
