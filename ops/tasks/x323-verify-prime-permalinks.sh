#!/bin/bash
# **x322 で出た感謝祭の告知の実物を読む（x323）。投稿しない・画面は撮らない。費用 $0。**
#   [1/2] 2111660452979847604 と [2/2] 2111660549784342885 の permalink を開き、
#   本文の頭と末尾・文字数・画像の枚数・[2/2] が [1/2] への返信として見えるかを出す。
# **ほかのアカウントのハンドルは伏せる。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-prime-permalinks.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x323-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const ids = ["2111660452979847604", "2111660549784342885"];
(async () => {
  const res = [];
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    for (const id of ids) {
      const url = "https://x.com/heng_ji31590/status/" + id;
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {});
      await page.waitForTimeout(6000);
      const items = await page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 4).map((a) => {
        const t = a.querySelector("time"); const p = t && t.closest("a"); const tx = a.querySelector('[data-testid="tweetText"]');
        const s = tx ? tx.innerText : "";
        return { href: p ? p.getAttribute("href") : null, len: s.length, head: s.slice(0, 60), tail: s.slice(-60),
          photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length, more: !!a.querySelector('[data-testid="tweet-text-show-more-link"]') };
      }));
      const missing = await page.$('text=このページは存在しません').catch(() => null);
      res.push({ id, url, missing: !!missing, items });
    }
    await page.close().catch(() => {});
  } catch (e) { res.push({ error: String(e && e.message).slice(0, 200) }); }
  console.log(JSON.stringify(res)); process.exit(0);
})();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" > "$W/.x323.json" 2>&1
{
echo "# 感謝祭の告知の実物（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
"$NODE_BIN" -e '
let j;try{j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());}catch(e){console.log("**読めない**");process.exit(0);}
for(const r of j){ if(r.error){console.log("**エラー: "+r.error+"**");continue;}
 console.log("## "+r.url+"\n\n- 存在しない表示: "+(r.missing?"**出た**":"出ていない")+"\n\n```");
 (r.items||[]).forEach(x=>console.log("  "+(x.href||"-")+" | 文字 "+x.len+" | 画像 "+x.photos+" | さらに表示 "+(x.more?"あり":"なし")+"\n    頭: "+x.head.replace(/\n/g," ")+"\n    末: "+x.tail.replace(/\n/g," ")));
 console.log("```\n"); }' "$W/.x323.json" 2>&1 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$W/.x323.json"
echo "x323 / $(basename "$OUT")"
