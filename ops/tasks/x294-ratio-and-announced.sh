#!/bin/bash
# **いまの比率・x291 以降に外した件数・告知済みの記事の一覧を読む。何も押さない。費用 $0。**
# 利用者の選択「今の比率と外した件数を読む」「ほかに告知していないブログがあれば教えて」（2026-10-15）。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/ratio-and-announced.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 比率・外した件数・告知済みの記事（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## mutual-prune（10/14 夜〜）"
echo '```'
grep -E "2026-10-1[45]T" "$W/logs/mutual-prune.log" 2>/dev/null | grep -E "start|相互フォロー:|見たプロフィール|外れた|done" | sed -E 's/^\[[^]]*\] //' | awk '!seen[$0]++' | hide | tail -15
echo "✂ の行数（10/14〜）: $(grep -E "2026-10-1[45]T" "$W/logs/mutual-prune.log" 2>/dev/null | grep -c "✂" | head -1)"
echo '```'
echo
echo "## follow-balance（10/14〜）"
echo '```'
F="$(ls "$W"/logs/follow-balance*.log 2>/dev/null | head -1)"
echo "ログ: $(basename "${F:-なし}")"
[ -n "$F" ] && grep -E "2026-10-1[45]T" "$F" | grep -E "比率|外し|unfollow|done|上限|quota" | sed -E 's/^\[[^]]*\] //' | awk '!seen[$0]++' | hide | tail -20
echo '```'
echo
P="$W/.x294-hdr.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage(); await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserName"]', { timeout: 20000 }); await p.waitForTimeout(2500);
  const r = await p.evaluate(() => { const g = (s) => { const a = document.querySelector(s); return a ? a.innerText.replace(/\s+/g, " ") : null; };
    return { following: g('a[href="/heng_ji31590/following"]'), followers: g('a[href="/heng_ji31590/verified_followers"]') || g('a[href="/heng_ji31590/followers"]') }; });
  await p.close(); console.log(JSON.stringify(r)); process.exit(0); })().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 150) })); process.exit(0); });
JS
echo "## 比率（ヘッダー）: $(cd "$W" && node "$P" 2>&1 | tail -1 | node -e 'let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);const n=(x)=>parseInt(String(x||"").replace(/[^0-9]/g,""),10);const a=n(j.following),b=n(j.followers);console.log(j.following+" / "+j.followers+(a&&b?" → "+(a/b).toFixed(3):""))}catch(e){console.log(s)}')"
rm -f "$P"
echo
echo "## 告知済みの記事（キューで x_tweet_id があるもの）"
echo '```'
node -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).queue||[];
const seen=new Set();
for(const e of q){ const s=JSON.stringify(e); const m=s.match(/daily-hack[^"\\s]*?\/posts\/([a-z0-9-]+)/g)||[];
  const id=e.x_tweet_id||e.tweet_id; if(!id) continue;
  for(const u of m){ const slug=u.replace(/.*\/posts\//,""); if(!seen.has(slug)){seen.add(slug); console.log(slug+"\t"+id+"\t"+(e.posted_at||e.updated_at||""));} } }
console.log("件数: "+seen.size);
' "$W/data/post_queue.json" 2>&1 | tail -120
echo '```'
echo
echo "**何も押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "比率・外した件数・告知済みの記事を読んだ / $(basename "$OUT")"
