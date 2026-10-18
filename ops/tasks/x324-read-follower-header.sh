#!/bin/bash
# **プロフィールのヘッダーからフォロワー数・フォロー数を読む（x324）。500 人突破の投稿の前に、数を一次情報で確かめる。費用 $0。**
# 走査（/following の DOM）は「おすすめ」が混ざるので使わない（最上位ルール 19）。画面は撮らない。投稿しない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follower-header.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x324-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => {
  const r = {};
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('a[href$="/verified_followers"], a[href$="/followers"]', { timeout: 25000 }).catch(() => {});
    await page.waitForTimeout(4000);
    r.links = await page.$$eval('a[href$="/following"], a[href$="/followers"], a[href$="/verified_followers"]',
      (as) => as.map((a) => ({ href: a.getAttribute("href"), text: a.innerText.replace(/\s+/g, " ").trim() })));
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0);
})();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" > "$W/.x324.json" 2>&1
{
echo "# プロフィールのヘッダーの数（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo
echo '```'
"$NODE_BIN" -e 'let j;try{j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());}catch(e){console.log("読めない");process.exit(0);}
if(j.error)console.log("エラー: "+j.error);(j.links||[]).forEach(l=>console.log("  "+l.href+" | "+l.text));' "$W/.x324.json"
echo '```'
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$W/.x324.json"
echo "x324 / $(basename "$OUT")"
