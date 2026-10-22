#!/bin/bash
# **run-publish.sh の「画像 2 枚以上だと黙って画像なしで出す」穴をふさぎ、花火の告知（B 案）を画像 4 枚で出し直す（x332）。費用 $0。**
POST_APPROVAL_QUOTE="わたしの方で消した。再度すぐ投稿して。また、再発防止策を考えて実装までして"
POST_APPROVAL_AT="2026-10-23 08:2x JST（ダイアログへの回答）"
POST_SET_KEY="hanabi-b"
#
# ## 何が起きたか（x330・x331 で実物を読んだ）
#
#   10/23 08:00 の予約（x328）は 1 本だけの投稿なので run-publish.sh の「Branch 2（単発）」を通った。
#   そこは `[ -f "$IMAGE_PATH" ]` で画像の有無を判定していて、**IMAGE_PATH が「a.jpg,b.jpg,…」のカンマ区切りだと
#   1 個のファイルとして存在しないので偽になり、画像なしの呼び出しに切り替わっていた。** エラーは出ない。
#   1 枚だけの投稿（フォロワー500人の GIF）は付いた。2 本以上のスレッド（プライム）は別の経路なので付いた。
#
# ## 直し方
#
#   ① その if を「カンマで分けて全部あるか」に置き換える。**画像を指定しているのに 1 枚でも無ければ、投稿せずに止める**
#      （画像なしで出すより、出さないほうがよい・最上位ルール 4）。元は run-publish.sh.bak-x332 に残す
#   ② 直したことを実物で確かめる（置き換わった行を出す・bash -n）
#   ③ 新しい id で積み、run-publish.sh で出す（利用者が 08:2x に元の投稿を手で消した）
#   ④ 投稿のページで**画像の枚数を数える**。4 枚でなければそう報告する（消さない・再送しない）
#
# **画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"
RP="$S/run-publish.sh"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
ID="blog-promo-20261023-tokyo-bay-hanabi-r2"
IMGDIR="$D/x-tokyo-bay-hanabi-weekend"
SRCDIR="public/images/tokyo-bay-hanabi-2026-weekend/x"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/repost-hanabi.md"
clean() { sed -E -e 's#(auth_token=|ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 画像の穴をふさいで花火の告知を出し直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"

echo; echo "## 1. run-publish.sh の判定を直す"; echo '```'
OLD='if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then'
if grep -qF "$OLD" "$RP"; then
  cp "$RP" "$RP.bak-x332"
  OLD="$OLD" "$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let s=fs.readFileSync(p,"utf8");const old=process.env.OLD;
const neu=[
"# 2026-10-23 x332: IMAGE_PATH はカンマ区切りで最大 4 枚。旧判定 [ -f \"$IMAGE_PATH\" ] は 2 枚以上で偽になり、黙って画像なしで出していた",
"IMG_STATE=$(IMAGE_PATH=\"$IMAGE_PATH\" /usr/local/bin/node -e \x27const fs=require(\"fs\");const p=(process.env.IMAGE_PATH||\"\").split(\",\").map(s=>s.trim()).filter(Boolean);process.stdout.write(p.length===0?\"none\":(p.every(x=>fs.existsSync(x))?\"ok\":\"missing\"))\x27)",
"if [ \"$IMG_STATE\" = \"missing\" ]; then",
"  echo \x27{\"ok\":false,\"step\":\"image-missing\",\"error\":\"image_path is set but some files are missing - refusing to post without images\"}\x27",
"  exit 1",
"fi",
"if [ \"$IMG_STATE\" = \"ok\" ]; then"].join("\n");
if(s.split(old).length!==2){console.log("  置き換え対象が 1 箇所ではない。止まる");process.exit(1);}
s=s.replace(old,neu);fs.writeFileSync(p,s);console.log("  置き換えた");' "$RP"
  bash -n "$RP" && echo "  bash -n: OK" || { echo "  **bash -n が通らない。元に戻して止まる**"; cp "$RP.bak-x332" "$RP"; exit 1; }
elif grep -q 'x332: IMAGE_PATH' "$RP"; then echo "  もう直っている"
else echo "  **判定の行が見つからない。止まる**"; exit 1; fi
grep -n -A7 'x332: IMAGE_PATH' "$RP" | cut -c1-220
echo '```'

echo; echo "## 2. 画像 4 枚と文面を origin/main から取る"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null || true
mkdir -p "$IMGDIR"; CSV=""; N=0
for f in 1-checklist.jpg 2-alcohol.jpg 3-roads.jpg 4-no-ticket.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f" 2>/dev/null && [ "$(wc -c < "$IMGDIR/$f" | tr -d ' ')" -ge 50000 ]; then
    printf '  %-16s %8s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"; CSV="${CSV:+$CSV,}$IMGDIR/$f"; N=$((N+1)); fi
done
echo "  対象 4 枚 / 取れた $N 枚"
T1="$("$NODE_BIN" -e '
const {execFileSync}=require("child_process"),crypto=require("crypto");const repo=process.argv[1];
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["hanabi-b"][0];
const L=JSON.parse(show("scripts/image-review/posts.lock.json")).locked["hanabi-b[0]"];
if(!(L&&L.sha256===crypto.createHash("sha256").update(t,"utf8").digest("hex"))){process.exit(2);}
process.stdout.write(t);' "$REPO" 2>/dev/null)"; TRC=$?
echo "  文面: rc=$TRC / 文字 ${#T1}（ロックと照合）"
echo '```'
if [ "$N" != "4" ] || [ "$TRC" != "0" ]; then echo "- **画像か文面が揃わない。出さない。**"; exit 1; fi

echo; echo "## 3. 積んで出す"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const [qp,id,t,csv]=process.argv.slice(1);const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=q.queue||q;
if(rows.some(r=>r&&r.id===id)){console.log("  同じ id がもう在る。止まる");process.exit(1);}
rows.push({id,kind:"thread",status:"awaiting_approval",auto_publish:false,scheduled_at:new Date(Date.now()-60000).toISOString(),created_at:new Date().toISOString(),text:t,image_path:csv,thread_chain:[{text:t,role:"hook",image_path:csv}],_note:"2026-10-23 利用者が元の投稿（画像なし）を消して出し直しを指示。x332"});
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);console.log("  積んだ: "+id);' "$D/post_queue.json" "$ID" "$T1" "$CSV" 2>&1 || exit 1
PUB="$(cd "$W" && /bin/bash "$RP" "$ID" 2>&1)"; PRC=$?
printf '%s\n' "$PUB" | grep -E 'attached|alt set|"ok"|image-missing|error' | tail -8 | cut -c1-400 | clean
echo "  (rc=$PRC)"
echo '```'

echo; echo "## 4. プロフィールと投稿のページで、出たか・画像が何枚かを数える"; echo '```'
PROBE="$W/.x332-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
  const hits = await page.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 6).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const p = t && t.closest("a");
    return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, head: tx ? tx.innerText.slice(0, 20) : "" }; }));
  const hit = hits.find((x) => x.head.startsWith("あんたにだけ教えるわね") && x.at && Date.now() - Date.parse(x.at) < 30 * 60 * 1000);
  r.hit = hit || null;
  if (hit) { await page.goto("https://x.com" + hit.href, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
    r.media = await page.$$eval('article[data-testid="tweet"]', (as) => as[0] ? as[0].querySelectorAll('[data-testid="tweetPhoto"]').length : -1); }
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
RES="$(cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1)"; rm -f "$PROBE"
echo "  $RES" | cut -c1-400 | clean
RES="$RES" "$NODE_BIN" -e '
const fs=require("fs");let r={};try{r=JSON.parse(process.env.RES)}catch(e){}
const [qp,id]=process.argv.slice(1);
if(!r.hit){console.log("  → **プロフィールに見当たらない**");process.exit(0)}
const tid=(r.hit.href.match(/status\/(\d+)/)||[])[1];
const q=JSON.parse(fs.readFileSync(qp,"utf8"));const e=(q.queue||q).find(x=>x&&x.id===id);
if(e){e.status="posted";e.x_tweet_id=tid;e.posted_at=r.hit.at;e.auto_publish=false;if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=tid;fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);}
console.log("  → 出た x_tweet_id="+tid+" ／ 画像 "+r.media+" 枚"+(r.media===4?"":"  **4 枚ではない**"));
console.log("  URL: https://x.com/heng_ji31590/status/"+tid);' "$D/post_queue.json" "$ID" 2>&1
echo '```'
echo; echo "**再送していない（1 回だけ出した）。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x332 / $(basename "$OUT")"
