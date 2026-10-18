#!/bin/bash
# **10/18 12:00 の感謝祭の告知（x314・x315）が出たかを読む。投稿しない・画面は撮らない。費用 $0。**
#
#   ① キューの行（status / x_tweet_id / thread_chain の各 x_tweet_id / last_result）＝一次情報 ①
#   ② 1 回だけのジョブのログ（logs/publish-prime-oneshot*.log）の全体
#   ③ 取れた tweet_id の permalink を開き、本文の頭・画像の枚数・自分の返信（[2/2]）を読む＝一次情報 ②
#   ④ ジョブがまだ載っているか（launchctl print）
# **ほかのアカウントのハンドルは伏せる。秘密は出さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-prime-post.md"
ID="blog-promo-20261018-prime-vs-rakuten"
ME="heng_ji31590"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 感謝祭の告知は出たか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo "## 1. キューの行（一次情報 ①）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const [qp,id]=process.argv.slice(1);
const q=JSON.parse(fs.readFileSync(qp,"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts);
const e=rows.find(x=>x&&x.id===id); if(!e){console.log("  エントリが無い");process.exit(0);}
console.log("  status="+e.status+" auto_publish="+e.auto_publish+" x_tweet_id="+(e.x_tweet_id||"無い")+" posted_at="+(e.posted_at||"-"));
(e.thread_chain||[]).forEach((c,i)=>console.log("  ["+(i+1)+"/2] x_tweet_id="+(c.x_tweet_id||"無い")));
console.log("  last_result="+JSON.stringify(e.last_result||null));' "$W/data/post_queue.json" "$ID" 2>&1 | clean
echo '```'
echo
echo "## 2. ジョブのログ"
echo
echo '```'
for f in "$W/logs/publish-prime-oneshot.log" "$W/logs/publish-prime-oneshot-out.log" "$W/logs/publish-prime-oneshot-err.log"; do
  if [ -f "$f" ]; then echo "--- $(basename "$f")（$(wc -l < "$f" | tr -d ' ') 行）"; tail -40 "$f" | cut -c1-400 | clean; else echo "--- $(basename "$f") は無い"; fi
done
echo '```'
echo
echo "## 3. ジョブはまだ載っているか"
echo
echo '```'
for L in com.dailyhack.publish-prime-oneshot ai.openclaw.publish-prime-oneshot; do
  if launchctl print "gui/$(id -u)/$L" >/dev/null 2>&1; then echo "  $L: 載っている（$(launchctl print "gui/$(id -u)/$L" | grep -E '^\s+runs ' | tr -s ' ')）"; else echo "  $L: 載っていない"; fi
done
echo '```'
echo
echo "## 4. 投稿の実物（一次情報 ②）"
echo
T1="$("$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=(Array.isArray(q)?q:(q.queue||[])).find(x=>x&&x.id===process.argv[2]);console.log((r&&r.x_tweet_id)||"")' "$W/data/post_queue.json" "$ID" 2>/dev/null)"
PROBE="$W/.x319-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, t1] = process.argv.slice(2);
const read = (page) => page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 8).map((a) => {
  const t = a.querySelector("time"); const p = t && t.closest("a"); const tx = a.querySelector('[data-testid="tweetText"]');
  return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, head: tx ? tx.innerText.slice(0, 80) : null,
    photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length };
}));
(async () => {
  const r = {};
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    let url = t1 ? `https://x.com/${me}/status/${t1}` : `https://x.com/${me}`;
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {});
    await page.waitForTimeout(7000);
    r.url = url; r.items = await read(page);
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0);
})();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" "$ME" "$T1" > "$W/.x319.json" 2>&1
"$NODE_BIN" -e '
let j;try{j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());}catch(e){console.log("**読めない**");process.exit(0);}
if(j.error)console.log("**エラー: "+j.error+"**");
console.log("開いた: "+(j.url||"-")+"\n");console.log("```");
(j.items||[]).forEach(x=>console.log("  "+(x.href||"-")+" | "+(x.at||"-")+" | 画像 "+x.photos+" | "+(x.head||"").replace(/\n/g," ")));
console.log("```");' "$W/.x319.json" 2>&1 | clean
rm -f "$PROBE" "$W/.x319.json"
echo
echo "**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "感謝祭の告知の確認 / $(basename "$OUT")"
