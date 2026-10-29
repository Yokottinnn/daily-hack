#!/bin/bash
# **止まったまま Chrome につながっている X の処理を終わらせ、X の画面が正常に読めるかを確かめる（x374）。押さない・$0。**
# x372 で関所を外した後も「問題が発生しました」が残った。unfollow-handle.js が 2 時間 39 分止まったまま（関所付きで Chrome につながっている疑い）。
# 30 分以上動いている X 系の node（unfollow-handle / follow-handle / post-comment / post-via-playwright / reply-followers-cleanup）だけ終わらせる。tab-guard など見張り役は触らない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x374-kill-hung.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
rm -f "$W/data/.x374-ok"
{
echo "# 止まっている X の処理を終わらせる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"; echo '```'
ps -axo pid=,etimes=,command= 2>/dev/null | grep -E 'node .*scripts/(unfollow-handle|follow-handle|post-comment|post-via-playwright|reply-followers-cleanup)\.js' | grep -v grep | while read -r pid et cmd; do
  if [ "${et:-0}" -ge 1800 ]; then echo "終わらせる: pid=$pid 経過 $((et/60)) 分 $(echo "$cmd" | awk '{print $2}' | xargs basename)"; kill -TERM "$pid" 2>/dev/null; sleep 2; kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null; else echo "残す: pid=$pid 経過 $((et/60)) 分"; fi
done
sleep 3
echo "--- 残っている X 系の node"; ps -axo pid,etime,command | grep -E 'node .*scripts/' | grep -v grep | cut -c1-140
echo '```'
echo; echo "## X の画面が読めるか（押さない）"; echo '```'
PROBE="$W/.x374-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590/status/2113412348195283225", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]', { timeout: 25000 }).then(() => r.textarea = true).catch(() => r.textarea = false);
  await p.waitForTimeout(4000);
  r.errorText = await p.evaluate(() => /問題が発生しました/.test(document.body.innerText));
  await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(8000);
  r.profileTweets = await p.$$eval('article[data-testid="tweet"]', (a) => a.length);
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0); })();
PJS
RES=$(cd "$W" && unset NODE_OPTIONS && "$NODE_BIN" "$PROBE" 2>&1 | tail -1); echo "$RES"; rm -f "$PROBE"
echo '```'
case "$RES" in *'"textarea":true'*'"profileTweets":'[1-9]*) date -u +%Y-%m-%dT%H:%M:%SZ > "$W/data/.x374-ok"; echo "**正常に読めた。**";; *) echo "**まだ正常ではない。告知は出さない。**";; esac
} > "$OUT" 2>&1
echo "x374 / $(basename "$OUT")"
