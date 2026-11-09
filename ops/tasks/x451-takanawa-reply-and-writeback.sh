#!/bin/bash
# x451（2026-11-10）: 高輪の [1/2] は 00:37 に出た（2119816597372272853・画像 4 枚・x450 で確認）。[2/2] の返信は送信まで進んだが ID が取れずに落ちた。
# [1/2] を開いて自分の返信（「グランドオープンから半年」）がぶら下がっているかを見て、**無いときだけ** post-comment.js で [2/2] を付ける（x245/x248 の作り）。
# そのあとキューを posted・auto_publish:false に書き戻す。
POST_APPROVAL_QUOTE="いますぐ投稿して頼むから"
POST_APPROVAL_AT="2026-11-10 00:2x JST（チャット）"
POST_SET_KEY="takanawa"
# LLM を呼ばない（$0）。
set -uo pipefail
ID="x-news-20261109-takanawa"; T1="2119816597372272853"; URL1="https://x.com/heng_ji31590/status/$T1"
W="$HOME/.openclaw/workspace"; D="$W/data"; S="$W/scripts"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x451-takanawa-reply-and-writeback.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"; PJS="$S/.x451-$STAMP.js"; RAW="$W/.x451-$STAMP.out"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
cat > "$PJS" <<'JSEOF'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage(); const res = { rows: [] };
  try { await p.goto(process.argv[2], { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(8000);
    for (let i = 0; i < 3; i++) { await p.mouse.wheel(0, 1500); await p.waitForTimeout(1500); }
    res.rows = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 12).map((a) => { const tm = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null, text: tx ? tx.innerText.slice(0, 40).replace(/\n/g, " ") : null }; }));
  } catch (e) { res.error = String(e && e.message).slice(0, 200); }
  const hit = res.rows.find((r) => r.href && r.href.startsWith("/heng_ji31590/") && r.text && /グランドオープンから半年/.test(r.text)); res.reply = hit ? hit.href.split("/").pop() : null;
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0); })().catch(e => { console.log(JSON.stringify({ fatal: String(e.message).slice(0, 200) })); process.exit(0); });
JSEOF
look() { (cd "$S" && node "$PJS" "$URL1" 2>&1 | tail -n 1); }
{
echo "# 高輪の [2/2] を付けて書き戻す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## 1. [1/2] の下を見る"; echo '```'; L1="$(look)"; echo "$L1" | clean; echo '```'
R2="$(printf '%s' "$L1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).reply||"")}catch(e){console.log("ERR")}})')"
echo; echo "## 2. [2/2]"; echo '```'
if [ "$R2" = "ERR" ] || printf '%s' "$L1" | grep -q '"fatal"\|"error"'; then echo "  **[1/2] の下が読めない。重複を避けて返信しない。**"; R2=""
elif [ -n "$R2" ]; then echo "  もう付いている: https://x.com/heng_ji31590/status/$R2（付け直さない）"
else
  git -C "$REPO" fetch -q origin main 2>/dev/null || true
  TXT="$(git -C "$REPO" show origin/main:scripts/image-review/posts.json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{process.stdout.write(JSON.parse(s).takanawa[1])})')"
  B64="$(printf '%s' "$TXT" | base64 | tr -d '\n')"
  echo "  付いていない → 付ける（文字 $(printf '%s' "$TXT" | wc -m | tr -d ' ')）"
  (cd "$W" && node scripts/post-comment.js "$B64" "$URL1" > "$RAW" 2>&1); echo "  post-comment rc=$?"; grep -v '^\[step\]' "$RAW" | tail -n 4 | cut -c1-300 | clean
  sleep 5; L2="$(look)"; R2="$(printf '%s' "$L2" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).reply||"")}catch(e){console.log("")}})')"
  echo "  付けたあと: ${R2:+https://x.com/heng_ji31590/status/$R2}${R2:-（見つからない）}"
fi
echo '```'
echo; echo "## 3. キューに書き戻す"; echo '```'
node -e 'const fs=require("fs");const [qp,id,t1,t2]=process.argv.slice(1);const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
const e=rows.find(x=>x&&x.id===id);if(!e){console.log("entry なし");process.exit(0)}e.status="posted";e.auto_publish=false;e.x_tweet_id=t1;e.posted_at=e.posted_at||"2026-11-09T15:37:15.000Z";
if(e.thread_chain&&e.thread_chain[0])e.thread_chain[0].x_tweet_id=t1;if(e.thread_chain&&e.thread_chain[1]&&t2)e.thread_chain[1].x_tweet_id=t2;
fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);JSON.parse(fs.readFileSync(qp,"utf8"));console.log("posted t1="+t1+" t2="+(t2||"なし"))' "$D/post_queue.json" "$ID" "$T1" "$R2" 2>&1 | clean
echo '```'
} > "$OUT" 2>&1
rm -f "$PJS" "$RAW"
grep -E 'status/|読めない|posted t1' "$OUT" | head -3 | cut -c1-200
exit 0
