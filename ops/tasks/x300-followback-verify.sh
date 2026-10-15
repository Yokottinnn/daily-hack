#!/bin/bash
# **x299 で直したフォロー返しの結果を読み、認証済みフォロワーの返し漏れを数え直す。何も押さない。費用 $0。**
# まだ走っていれば最大 4 分だけ待つ。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/followback-verify.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/"handles":\[[^\]]*\]/"handles":["<伏せ>"]/g'; }
{
echo "# フォロー返しの結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
w=0; while pgrep -f "badge-followback.js" >/dev/null 2>&1 && [ "$w" -lt 240 ]; do sleep 5; w=$((w+5)); done
pgrep -f "badge-followback.js" >/dev/null 2>&1 && echo "**まだ走っている（途中経過）**" || echo "- 終わっている"
echo '```'
grep -E "2026-10-15T1[5-9]:[5-9]|2026-10-15T1[6-9]|verified_followers|scanned=|\"ok\"|error" "$W/logs/badge-followback.log" | tail -12 | hide
echo "x299 以降に返した数: $(awk '/verified_followers: 読めた/{f=1} f' "$W/logs/badge-followback.log" | grep -c "followed back" | head -1)"
echo '```'
P="$W/.x300-scan.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://x.com/heng_ji31590/verified_followers", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserCell"]', { timeout: 25000 });
  const seen = new Map(); let still = 0;
  for (let i = 0; i < 40 && still < 4; i++) {
    const rows = await p.evaluate(() => [...document.querySelectorAll('[data-testid="UserCell"]')].map((c) => {
      const a = [...c.querySelectorAll('a[href^="/"]')].map((x) => x.getAttribute("href")).find((h) => /^\/[A-Za-z0-9_]{1,15}$/.test(h));
      const btn = c.querySelector('button[data-testid$="-follow"], button[data-testid$="-unfollow"]');
      const t = btn ? btn.getAttribute("data-testid") : "";
      return { h: a ? a.slice(1) : null, st: t.endsWith("-unfollow") ? "following" : (t.endsWith("-follow") ? "not" : "?") };
    }));
    const before = seen.size; for (const r of rows) if (r.h && !seen.has(r.h)) seen.set(r.h, r);
    still = seen.size === before ? still + 1 : 0;
    await p.evaluate(() => window.scrollBy(0, 2500)); await p.waitForTimeout(1800);
  }
  const hdr = await (async () => { await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForSelector('[data-testid="UserName"]', { timeout: 20000 }); await p.waitForTimeout(2000);
    return p.evaluate(() => { const g = (s) => { const a = document.querySelector(s); return a ? a.innerText.replace(/\s+/g, " ") : null; }; return { following: g('a[href="/heng_ji31590/following"]'), followers: g('a[href="/heng_ji31590/verified_followers"]') || g('a[href="/heng_ji31590/followers"]') }; }); })();
  await p.close();
  const all = [...seen.values()]; const c = (s) => all.filter((r) => r.st === s).length;
  console.log(JSON.stringify({ total: all.length, following: c("following"), not: c("not"), unknown: c("?"), hdr }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
echo
echo "## 認証済みフォロワーの一覧（数え直し）"
echo '```'
(cd "$W" && node "$P" 2>&1 | tail -1) | node -e 'let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);if(j.error){console.log("読めなかった: "+j.error)}else{console.log("読めた "+j.total+" 人 / フォロー中 "+j.following+" / **返していない "+j.not+"** / 判定不能 "+j.unknown);const n=(x)=>parseInt(String(x||"").replace(/[^0-9]/g,""),10);const a=n(j.hdr.following),b=n(j.hdr.followers);console.log("比率（ヘッダー）: "+j.hdr.following+" / "+j.hdr.followers+(a&&b?" → "+(a/b).toFixed(3):""))}}catch(e){console.log(s)}'
echo '```'
rm -f "$P"
echo
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "フォロー返しの結果を読み、返し漏れを数え直した / $(basename "$OUT")"
