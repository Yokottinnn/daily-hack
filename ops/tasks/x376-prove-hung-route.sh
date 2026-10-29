#!/bin/bash
# **止まった処理が X の通信を止めているかを、投稿せずに確かめる（x376）。押さない・$0。**
# ① 止まっている X 系の node に関所（NODE_OPTIONS）が付いているか ② 終わらせる前に、ページを開いて X の通信（/i/api/）が返ってくる数と返ってこない数を数える
# ③ 30 分以上動いている X 系の node を終わらせる ④ もう一度 ② を数える。前後で比べる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x376-prove-hung-route.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
unset NODE_OPTIONS
PROBE="$W/.x376-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = { sent: 0, done: 0, failed: 0, pending: [] }; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  const open = new Map();
  p.on("request", (q) => { if (/\/i\/api\//.test(q.url())) { r.sent++; open.set(q, q.url().replace(/\?.*/, "").split("/").slice(-1)[0]); } });
  p.on("requestfinished", (q) => { if (open.delete(q)) r.done++; });
  p.on("requestfailed", (q) => { if (open.delete(q)) r.failed++; });
  await p.goto("https://x.com/home", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(15000);
  r.pending = [...open.values()].slice(0, 10); r.pendingCount = open.size;
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r)); process.exit(0); })();
PJS
list() { ps -axo pid=,etime=,command= | grep -E 'node .*scripts/(unfollow-handle|follow-handle|post-comment|post-via-playwright|reply-followers-cleanup|follow-balance|mutual-prune|hashtag-follow|competitor-follower-follow)\.js' | grep -v grep; }
secs() { echo "$1" | awk -F'[-:]' '{n=NF; s=$n+$(n-1)*60; if(n>=3)s+=$(n-2)*3600; if(n>=4)s+=$(n-3)*86400; print s}'; }
{
echo "# 止まった処理が X の通信を止めているか（$(date '+%Y-%m-%d %H:%M:%S') JST・押さない・\$0）"
echo; echo "## ① 動いている X 系の node と、関所が付いているか"; echo '```'
list | while read -r pid et cmd; do g=$(ps eww -p "$pid" 2>/dev/null | grep -o 'x-action-guard' | head -1); echo "pid=$pid 経過 $et 関所=${g:-なし} $(echo "$cmd" | awk '{print $2}' | xargs basename)"; done
echo '```'
echo; echo "## ② 終わらせる前：X の通信（15 秒）"; echo '```'; cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1; echo '```'
echo; echo "## ③ 30 分以上動いている X 系の node を終わらせる"; echo '```'
list | while read -r pid et cmd; do s=$(secs "$et"); if [ "${s:-0}" -ge 1800 ]; then kill -TERM "$pid" 2>/dev/null; sleep 2; kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null; echo "終わらせた: pid=$pid 経過 $et"; fi; done
sleep 3; echo "--- 残り"; list
echo '```'
echo; echo "## ④ 終わらせた後：X の通信（15 秒）"; echo '```'; cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1; echo '```'
echo "**押していない（\$0）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x376 / $(basename "$OUT")"
