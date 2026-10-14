#!/bin/bash
# **相互フォローの整理（mutual-prune・x285 で本番化した「未認証で釣り合い ≥0.8」を含む）をいま 1 回走らせる。費用 $0。**
#
# 利用者の選択（2026-10-14）「相互の整理をいま 1 回走らせる」。launchd の正規ジョブを kickstart する（ops から切り離される）。
# 1 回に外すのは plist の MAX_UNFOLLOW=15 まで（x289 で 8 → 15）。最大 4 分半だけ終わりを待ち、外した相手の理由と、外した後の比率を出す。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-now-2.md"
LABEL="ai.openclaw.mutual-prune"
LOG="$W/logs/mutual-prune.log"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 相互フォローの整理をいま 1 回（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
START="$(date -u +%Y-%m-%dT%H:%M)"
launchctl print "gui/$(id -u)/$LABEL" 2>&1 | grep -E "MUTUAL_RATIO_CUT|MAX_UNFOLLOW" | head -2
launchctl kickstart "gui/$(id -u)/$LABEL" 2>&1 | head -2; echo "kickstart rc=$?"
sleep 10
w=10; while pgrep -f "mutual-prune.js" >/dev/null 2>&1 && [ "$w" -lt 270 ]; do sleep 5; w=$((w+5)); done
pgrep -f "mutual-prune.js" >/dev/null 2>&1 && echo "**まだ走っている（途中経過・$w 秒）**" || echo "- 終わった（$w 秒）"
echo
echo '```'
awk -v s="[$START" '$0 >= s' "$LOG" 2>/dev/null | grep -E "start|相互フォロー:|外す候補|✂|外した|unfollow|失敗|end" | sed -E 's/^\[[^]]*\] //' | hide | head -40
echo '```'
echo
P="$W/.x291-hdr.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage(); await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserName"]', { timeout: 20000 }); await p.waitForTimeout(2500);
  const r = await p.evaluate(() => { const g = (s) => { const a = document.querySelector(s); return a ? a.innerText.replace(/\s+/g, " ") : null; };
    return { following: g('a[href="/heng_ji31590/following"]'), followers: g('a[href="/heng_ji31590/verified_followers"]') || g('a[href="/heng_ji31590/followers"]') }; });
  await p.close(); console.log(JSON.stringify(r)); process.exit(0); })().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 150) })); process.exit(0); });
JS
echo "比率（ヘッダー）: $(cd "$W" && node "$P" 2>&1 | tail -1 | node -e 'let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);const n=(x)=>parseInt(String(x||"").replace(/[^0-9]/g,""),10);const a=n(j.following),b=n(j.followers);console.log(j.following+" / "+j.followers+(a&&b?" → "+(a/b).toFixed(3):""))}catch(e){console.log(s)}')"
rm -f "$P"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "相互フォローの整理をいま 1 回走らせた / $(basename "$OUT")"
