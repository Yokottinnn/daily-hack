#!/bin/bash
# **x386 で直したあと（13 時の回）の外す処理の結果を読む（x388）。読むだけ・$0。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/x388-after-mark-fix.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 13 時の回の外す処理の結果（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① reply-followers-cleanup.log の 2026-10-31T04:00Z 以降"; echo '```'
L="$W/logs/reply-followers-cleanup.log"
awk '$0 ~ /^\[2026-10-31T/ && substr($0,2,13) >= "2026-10-31T04"' "$L" 2>/dev/null > /tmp/x388.txt
echo "行数 $(wc -l < /tmp/x388.txt | tr -d ' ')"
echo "外した: $(grep -cE ': unfollowed$' /tmp/x388.txt | head -1)"
echo "失敗: $(grep -cE 'failed|error' /tmp/x388.txt | head -1)"
echo "もうフォローしていない→解除済み: $(grep -c 'already not following' /tmp/x388.txt | head -1)"
echo "打ち切り（timeout・ETIMEDOUT）: $(grep -ciE 'timeout|ETIMEDOUT' /tmp/x388.txt | head -1)"
echo "--- 起動ごとの行"; grep -E 'due |done|完了|=== ' /tmp/x388.txt | tail -12 | cut -c1-180 | hide
echo "--- 最後の 8 行"; tail -8 /tmp/x388.txt | cut -c1-200 | hide
echo '```'
echo; echo "## ② reply-followers.json の unfollowed_at（2026-10-31T04:00Z 以降）"; echo '```'
"$NODE_BIN" -e '
const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const s=Date.parse("2026-10-31T04:00:00Z");const m={};let n=0;
for(const v of Object.values(r)){if(v.unfollowed_at&&Date.parse(v.unfollowed_at)>=s){n++;m[v.unfollow_source||"?"]=(m[v.unfollow_source||"?"]||0)+1}}
const due=Object.values(r).filter(v=>v.scheduled_unfollow_at&&!v.unfollowed_at&&Date.parse(v.scheduled_unfollow_at)<=Date.now()).length;
console.log("外した",n,JSON.stringify(m),"／ まだ外す予定が残っている",due);' "$W/data/reply-followers.json" 2>&1
echo '```'
echo; echo "## ③ 止まったままの node（30 分以上）"; echo '```'
ps -axo pid,etime,command | grep -E 'node .*scripts/' | grep -v grep | cut -c1-130 | hide
echo '```'
echo; echo "## ④ プロフィールのヘッダー"; echo '```'
PROBE="$W/.x388-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const r = {}; try { const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(6000);
  r.links = await p.$$eval('a[href$="/following"], a[href$="/verified_followers"]', (a) => a.map((x) => x.innerText.replace(/\s+/g, " ").trim()));
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1; rm -f "$PROBE" /tmp/x388.txt
echo '```'
echo "**読んだだけ（\$0）。**"
} > "$OUT" 2>&1
echo "x388 / $(basename "$OUT")"
