#!/bin/bash
# **x358 の投稿が見えない理由を読む（x360）。読むだけ・押さない・$0。**
# ① X の検索（自分の投稿・最新）で「ユナイテッドシネマ」を探す ② プロフィールをもう一度 ③ post-via-playwright の失敗時の記録
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x360-why-cinema.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x360-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  const grab = async () => p.$$eval('article[data-testid="tweet"]', (as) => as.slice(0, 5).map((a) => { const tx = a.querySelector('[data-testid="tweetText"]'); const t = a.querySelector("time"); const l = t && t.closest("a"); return { href: l ? l.getAttribute("href") : null, time: t ? t.getAttribute("datetime") : null, head: tx ? tx.innerText.slice(0, 30) : "", media: a.querySelectorAll('[data-testid="tweetPhoto"]').length }; }));
  await p.goto("https://x.com/search?q=" + encodeURIComponent("from:heng_ji31590 ユナイテッドシネマ") + "&src=typed_query&f=live", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(7000); r.search = await grab();
  await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(7000); r.profile = await grab();
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
{
echo "# 豊洲の映画館の投稿が見えない理由（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo; echo "## 投稿まわりのログ（直近・豊洲／fallback／CreateTweet）"; echo '```'
ls -t /tmp/post-* /tmp/*playwright* 2>/dev/null | head -5
grep -hE 'fallback|CreateTweet|cinema|captured|error' "$W"/logs/*publish*.log "$W"/logs/run-publish*.log 2>/dev/null | tail -15 | cut -c1-240
echo '```'
echo "**読んだだけ（\$0）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x360 / $(basename "$OUT")"
