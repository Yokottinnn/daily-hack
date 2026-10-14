#!/bin/bash
# **x291 で走らせた mutual-prune（15 件）の結果と、いまの比率を読む。何も押さない。費用 $0。**
# 終わっていなければ最大 4 分だけ待つ。**LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/mutual-prune-result-2.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 相互フォローの整理の結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
w=0; while pgrep -f "mutual-prune.js" >/dev/null 2>&1 && [ "$w" -lt 240 ]; do sleep 5; w=$((w+5)); done
pgrep -f "mutual-prune.js" >/dev/null 2>&1 && echo "**まだ走っている（途中経過）**" || echo "- 終わっている"
echo '```'
grep -E "2026-10-14T1[3-9]" "$W/logs/mutual-prune.log" | grep -E "start|相互フォロー:|見たプロフィール|外れた|done" | sed -E 's/^\[[^]]*\] //' | awk '!seen[$0]++' | hide | tail -25
echo '```'
P="$W/.x292-hdr.js"
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
echo "**何も押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "相互フォローの整理の結果を読んだ / $(basename "$OUT")"
