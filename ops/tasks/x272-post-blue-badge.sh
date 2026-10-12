#!/bin/bash
# **青バッジ（Premium）取得の報告を 1 投稿で出す。GIF 1 枚。費用 $0。**
#
# ## 承認の状態（2026-10-12）
#
#   利用者がダイアログで **「A 短い版」** と **「動く版 GIF」** を選んだ。画像はチャットに添付した実物（静止画・GIF）を見たうえで。
#   文面は `scripts/image-review/posts.lock.json` の `blue-badge-a[0]` とハッシュで照合してから出す（最上位ルール 18）。
#   「なるべく早めにしたい」と指示されている。
#
# ## 形
#
#   1 投稿（スレッドにしない）。`kind:"thread"` ／ `thread_chain` は 1 本だけ（x214 フォロワー 300 のお礼と同じ形）。
#   添付は public/images/blue-badge/x/1-card.gif（1.1MB・X の GIF 上限 15MB）。ALT は付けない（素材はキャラと自作の図だけ）。
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/post-blue-badge.md"
LOCK="$W/data/.x272-blue-badge.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-blue-badge"
SRCDIR="public/images/blue-badge/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
PVP="$W/scripts/post-via-playwright.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261012-blue-badge"
ALTF="$W/data/.x264-alts.json"
ME="heng_ji31590"

hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{ const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&e.id===process.argv[2]&&(e.status==="posted"||e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }' "$QJSON" "$ID" 2>/dev/null || echo -1
}

{
echo "# 青バッジ取得の報告を投稿する（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> **1 投稿・GIF 1 枚。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。"

echo
echo "## 00. 同じ ID のエントリが残っていれば自動投稿を止める"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"); const [qp,id]=process.argv.slice(1);
try{ const q=JSON.parse(fs.readFileSync(qp,"utf8")); const e=(q.queue||[]).find(x=>x&&x.id===id);
  if(!e){ console.log("  エントリは無い"); process.exit(0); }
  console.log("  いま: status="+e.status+" auto_publish="+e.auto_publish+" x_tweet_id="+(e.x_tweet_id||null));
  if(e.auto_publish!==false && !e.x_tweet_id){ e.auto_publish=false; fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp",qp); console.log("  → auto_publish を false にした"); }
}catch(err){ console.log("  読めない: "+err.message); }' "$QJSON" "$ID" 2>&1
echo '```'

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "- **キューが読めない。何もしない。**"; exit 1; fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then echo "- → **既に出ている。何もしない。**"; exit 0; fi
if [ -f "$LOCK" ]; then echo "- **ロックがある（$(cat "$LOCK")）。二重に走らせない。**"; exit 0; fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 1. 文面を origin/main から取り、ロックのハッシュと照合する"
echo
git -C "$REPO" fetch -q origin main 2>/dev/null || true
TXT="$W/data/.x264-texts.json"
git -C "$REPO" show origin/main:scripts/image-review/posts.json > "$W/data/.x264-posts.json" 2>/dev/null
git -C "$REPO" show origin/main:scripts/image-review/posts.lock.json > "$W/data/.x264-lock.json" 2>/dev/null
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),crypto=require("crypto");
const [pp,lp,out]=process.argv.slice(1);
const p=JSON.parse(fs.readFileSync(pp,"utf8"))["blue-badge-a"], l=JSON.parse(fs.readFileSync(lp,"utf8")).locked;
const sha=s=>crypto.createHash("sha256").update(s,"utf8").digest("hex");
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
const t=p&&p[0]; const L=l["blue-badge-a[0]"]; const m=t&&L&&L.sha256===sha(t);
console.log("  ロック "+(m?"一致":"**不一致**")+" ／ 重み "+(t?w(t):"-")+" / 280");
fs.writeFileSync(out, JSON.stringify(p||[]));
if(!m||w(t)>280){ console.log("  **出さない**"); process.exit(2); }' "$W/data/.x264-posts.json" "$W/data/.x264-lock.json" "$TXT" 2>&1
RC=$?
echo '```'
if [ "$RC" != "0" ]; then echo "- **文面が揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi
T1="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))[0])' "$TXT")"

echo
echo "## 3. GIF を origin/main から取り出す"
echo
mkdir -p "$IMGDIR"; IMGS=""; N=0
echo '```'
for f in 1-card.gif; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 200000 ]; then
    mv "$TMP" "$IMGDIR/$f"; printf '  取得  %-16s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"; N=$((N + 1))
  else printf '  **取れない** %s\n' "$f"; rm -f "$TMP"; fi
done
printf '  対象 1 枚 / 取れた %s 枚\n' "$N"
echo '```'
if [ "$N" != "1" ]; then echo "- **GIF が取れない。出さない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 4. キューに積む（同じ ID の未投稿エントリは消してから積む）"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs"); const [qp,id]=process.argv.slice(1);
const q=JSON.parse(fs.readFileSync(qp,"utf8")); const before=(q.queue||[]).length;
q.queue=(q.queue||[]).filter(x=>!(x&&x.id===id&&!x.x_tweet_id&&x.status!=="posted"));
if(q.queue.length!==before){ fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp",qp); console.log("{\"removed_old\":"+(before-q.queue.length)+"}"); }' "$QJSON" "$ID" 2>&1
"$NODE_BIN" -e '
const [id,t1,csv]=process.argv.slice(1);
console.log(JSON.stringify({ id, kind:"thread", text:t1, image_path:csv, auto_publish:false,
  scheduled_at:new Date(Date.now()-60000).toISOString(),
  thread_chain:[ {text:t1, role:"hook", image_path:csv} ] }));
' "$ID" "$T1" "$IMGS" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
echo '```'

echo
echo "## 5. Chrome は健全か"
echo
echo '```'
"$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"
echo '```'

echo
echo "## 6. 出す"
echo
PUB="$(env -u ALT_TEXTS_FILE "$RUNPUB" "$ID" 2>&1)"; PRC=$?
echo '```'
printf '%s\n' "$PUB" | tail -60 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 7. 出たか。出たならキューに書き戻す"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" -e '
const fs=require("fs");
let raw=""; process.stdin.on("data",d=>raw+=d).on("end",()=>{
  const [qp,id]=process.argv.slice(1);
  const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();
  if(!line){ console.log("  出力に JSON が無い。書き戻さない。"); return; }
  let r; try{ r=JSON.parse(line); }catch(e){ console.log("  JSON が読めない: "+e.message); return; }
  if(!r.ok){ console.log("  ok:false。書き戻さない。 step="+(r.step||"-")+" error="+(r.error||"")); return; }
  const t1=r.tweet_id||null, rs=r.thread_results||[], t2=(rs[1]&&(rs[1].reply_tweet_id||rs[1].tweet_id))||null;
  console.log("  tweet_id = "+(t1||"取れていない")); 
  if(!t1) return;
  const q=JSON.parse(fs.readFileSync(qp,"utf8")); const e=(q.queue||[]).find(x=>x&&x.id===id); if(!e) return;
  e.status="posted"; e.x_tweet_id=t1; e.posted_at=new Date().toISOString();
  if(Array.isArray(e.thread_chain)){ if(e.thread_chain[0]) e.thread_chain[0].x_tweet_id=t1; if(e.thread_chain[1]&&t2) e.thread_chain[1].x_tweet_id=t2; }
  fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2)); fs.renameSync(qp+".tmp", qp);
  console.log("  キューを posted に書き戻した");
});' "$QJSON" "$ID" 2>&1 | clean
echo '```'

echo
echo "## 8. 実物を読む（プロフィール → permalink。画像の枚数と alt）"
echo
PROBE="$W/.x264-proof.js"
cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, outdir] = process.argv.slice(2);
const read = (page) => page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 6).map((a) => {
  const t = a.querySelector("time"); const p = t && t.closest("a"); const tx = a.querySelector('[data-testid="tweetText"]');
  return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, text: tx ? tx.innerText : null,
    photos: [...a.querySelectorAll('[data-testid="tweetPhoto"] img')].map((i) => i.getAttribute("alt") || "") };
}));
(async () => {
  const r = {};
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 900, height: 1700 });
    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {});
    await page.waitForTimeout(6000);
    const hit = (await read(page)).find((x) => x.text && /青バッジ、付けたわよ/.test(x.text));
    if (hit && hit.href) {
      r.t1 = (hit.href.match(/status\/(\d+)/) || [])[1];
      await page.goto("https://x.com" + hit.href, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => {});
      await page.waitForTimeout(7000);
      r.thread = await read(page);
      await page.screenshot({ path: outdir + "/x272-post.png" });
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0);
})();
PROBEJS
rm -f "$OUTDIR"/x272-*.png
cd "$W" && "$NODE_BIN" "$PROBE" "$ME" "$OUTDIR" > "$W/.x264-proof.json" 2>&1
"$NODE_BIN" -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.error) console.log("**エラー: " + j.error + "**\n");
if (!j.t1) { console.log("**プロフィールに青バッジの投稿が見つからない**"); process.exit(0); }
const self = (j.thread || []).find((x) => x.href && x.href.includes("/status/" + j.t1));
console.log("### https://x.com/" + process.argv[2] + "/status/" + j.t1 + "\n");
console.log("```\n" + ((self && self.text) || "") + "\n```");
console.log("\n**判定: 投稿 " + (self ? "在る" : "**見えない**") + "**");
' "$W/.x264-proof.json" "$ME" 2>&1 | clean
rm -f "$PROBE" "$W/.x264-proof.json" "$TXT" "$ALTF" "$W/data/.x264-posts.json" "$W/data/.x264-lock.json" "$W/data/.x264-panels.json"
echo
echo "画面: $(ls "$OUTDIR"/x272-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null)"
echo
echo "**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then echo "**青バッジの報告を出した** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then echo "既に出ていたので何もしていない / $(basename "$OUT")"
else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
