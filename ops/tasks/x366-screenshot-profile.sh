#!/bin/bash
# **プロフィール・通知・検索が読めなくなった原因を、画面で確かめる（x366）。開いて撮るだけ・押さない・$0。**
# x358 は「投稿したが ID が取れない」と返したが X 上に出ていない（x359・x360）。返信の入力欄も今日 3 回 開けていない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
D="${OPS_REPORT_DIR:-/tmp}/x366"; mkdir -p "$D"
OUT="${OPS_REPORT_DIR:-/tmp}/x366-compose-screen.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x366-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const D = process.argv[2];
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
  const look = async (name, url) => { await p.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(8000);
    await p.screenshot({ path: `${D}/${name}.png` }).catch(() => {});
    return await p.evaluate(() => ({ url: location.href, title: document.title,
      alerts: [...document.querySelectorAll('[role="alert"],[data-testid="toast"],[role="dialog"]')].map((e) => e.innerText.slice(0, 200)),
      textarea: !!document.querySelector('[data-testid="tweetTextarea_0"]'), postBtn: !!document.querySelector('[data-testid="tweetButton"],[data-testid="tweetButtonInline"]'),
      body: document.body.innerText.replace(/\s+/g, " ").slice(0, 400) })); };
  r.profile = await look("1-profile", "https://x.com/heng_ji31590");
  r.notifications = await look("2-notifications", "https://x.com/notifications");
  r.search = await look("3-search", "https://x.com/search?q=" + encodeURIComponent("from:heng_ji31590") + "&f=live");
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# 投稿画面を撮る（$(date '+%Y-%m-%d %H:%M:%S') JST・押さない・\$0）"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$D" 2>&1 | tail -40 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo "画像: reports/x366/1-profile.png・2-notifications.png・3-search.png"; ls -la "$D"
echo "**開いて撮っただけ。押していない（\$0）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x366 / $(basename "$OUT")"
