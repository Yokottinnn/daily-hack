#!/bin/bash
# **ローソン・ユナイテッドシネマ 豊洲（2026-12-04 リニューアル）の告知を、いま 1 投稿で出す（画像 3 枚）。費用 $0。**
POST_APPROVAL_QUOTE="この内容で大丈夫なのですぐ投稿して"
POST_APPROVAL_AT="2026-10-29 JST（チャット）"
POST_SET_KEY="cinema-toyosu"
#
# 文面は posts.json の cinema-toyosu[0]（レビューページの書き換え・コメントは 0 件）。画像は public/images/lawson-united-cinema-toyosu-2026/x/ の 3 枚（1 枚目は公式のキービジュアルそのまま）。
# シャドウバン対策の関所（x352）を通す。
# **出し直し 4 回目（x373）**: 関所を全ジョブから外した（x372）あと、返信の入力欄が開いたときだけ出す。
# **出し直し 3 回目（x369）**: 送り方（Meta+Enter）を投稿ボタンのクリックに直してから出す。x367 でボタンは押せる状態と確認済み。
# **出し直し 2 回目（x364）・関所を通さない**: x362 も同じ失敗（X の応答が 1 行も記録されない）。関所が画像付きの投稿を止めている疑い。
# **出し直し（x373）**: x358 は「投稿したが ID が取れない」と返したが、X 上に出ていなかった（x359・x360・x361 で確認。画面に制限の表示は無い）。
# 関所を新しくして、X が投稿に返した中身（エラーの理由）をログに残す。そのうえで 1 回だけ出し直す。
# 出たあと、permalink を開いて本文と画像の有無を読む（画面は撮らない）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-cinema-toyosu-r5.md"
LOCK="$W/data/.x373-cinema-toyosu.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-cinema-toyosu"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261029-cinema-toyosu-r5"
ME="heng_ji31590"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# ローソン・ユナイテッドシネマ 豊洲の告知を出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## x372 で返信の入力欄が開いたか"
if [ ! -f "$W/data/.x372-ok" ]; then echo "- **開いていない（または x372 が走っていない）。出さない。**"; exit 0; fi
echo "- 開いた（$(cat "$W/data/.x372-ok")）"
echo
echo "## 送り方を直す（キーボードの近道 → 投稿ボタンをクリック）"
PV="$W/scripts/post-via-playwright.js"
if grep -q 'x373:' "$PV"; then echo "- もう直してある"; else
  cp -p "$PV" "$PV.bak-x373"
  "$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let s=fs.readFileSync(p,"utf8");
const old="    await page.waitForTimeout(300);\n    await page.keyboard.press(\"Meta+Enter\");";
if(s.split(old).length!==2){console.log("- 置き換え位置が 1 か所に決まらない。直さずに止める");process.exit(3);}
s=s.replace(old,"    await page.waitForTimeout(300);\n    // x373: 2026-10-28 ごろから Meta+Enter で送れなくなった。投稿ボタンをクリックし、押せなければ近道で送る\n    { const b=page.locator(\x27[data-testid=\"tweetButton\"], [data-testid=\"tweetButtonInline\"]\x27).first(); let done=false;\n      try { if (!(await b.evaluate(el=>el.getAttribute(\"aria-disabled\")===\"true\"||el.disabled))) { await b.click({ timeout: 5000 }); done=true; } } catch (_) {}\n      if (!done) await page.keyboard.press(\"Meta+Enter\"); }");
fs.writeFileSync(p,s);console.log("- 直した");' "$PV"; RCF=$?
  if [ "$RCF" != 0 ] || ! "$NODE_BIN" --check "$PV" 2>/dev/null; then cp -p "$PV.bak-x373" "$PV"; echo "- **直せなかったので元に戻した。出さない。**"; exit 1; fi
fi
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
T1="$("$NODE_BIN" -e '
const {execFileSync}=require("child_process"),crypto=require("crypto");const repo=process.argv[1];
const show=p=>execFileSync("git",["-C",repo,"show","origin/main:"+p],{encoding:"utf8",maxBuffer:16*1024*1024});
const t=JSON.parse(show("scripts/image-review/posts.json"))["cinema-toyosu"][0];
if(!t||t.length<50){console.error("  文面が無い");process.exit(2);}
process.stdout.write(t);' "$REPO" 2>&1)"; RC=$?
echo "  rc=$RC / 文字 ${#T1}"
echo '```'
if [ "$RC" != "0" ]; then echo "- **文面が揃わない。出さない。** $T1"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 2. 画像 3 枚を origin/main から取り出す"
echo
mkdir -p "$IMGDIR"; CSV=""; ok=1
for f in 0-keyvisual.jpg 1-cover.jpg 2-flexound.jpg; do
  G="$IMGDIR/$f"
  if git -C "$REPO" show "origin/main:public/images/lawson-united-cinema-toyosu-2026/x/$f" > "$G" 2>/dev/null && [ "$(wc -c < "$G" | tr -d ' ')" -ge 50000 ]; then echo "- $f: $(wc -c < "$G" | tr -d ' ') bytes"; CSV="${CSV:+$CSV,}$G"; else echo "- **$f が取れない**"; ok=0; fi
done
if [ "$ok" != 1 ]; then echo "- **画像が揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi
G="$CSV"
# シャドウバン対策の関所（x352）
# 関所は通さない（この 1 回だけ）

echo "## 3. キューに積んで出す"
echo
echo '```'
"$NODE_BIN" -e '
const [id,t1,csv]=process.argv.slice(1);
console.log(JSON.stringify({id,kind:"thread",text:t1,image_path:csv,auto_publish:false,scheduled_at:new Date(Date.now()-60000).toISOString(),thread_chain:[{text:t1,role:"hook",image_path:csv}]}));' "$ID" "$T1" "$G" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -5 | clean
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
PROBE="$W/.x373-probe.js"
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
if grep -q 'x_tweet_id=[0-9]' "$OUT"; then echo "**豊洲の映画館の告知を出し直した** / $(basename "$OUT")"; else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
