#!/bin/bash
# **x279（競合の認証済みフォロワーから上限 10 でフォロー）の結果を読む。何も押さない。費用 $0。**
#
# 読むもの: ① ジョブのログ ② 今日フォローした記録（verified の有無） ③ プロフィールのヘッダー（フォロー中・フォロワー・比率）
# ジョブがまだ走っていれば、最大 4 分だけ終わるのを待つ（それ以上は待たずに途中経過を出す・最上位ルール 15）。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/competitor-verified-result.md"
LOG="$W/logs/x279-competitor-verified.log"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 競合の認証済みフォロワーからのフォロー・結果（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
w=0; while pgrep -f "competitor-follower-follow.js" >/dev/null 2>&1 && [ "$w" -lt 240 ]; do sleep 5; w=$((w+5)); done
pgrep -f "competitor-follower-follow.js" >/dev/null 2>&1 && echo "**まだ走っている（途中経過）**" || echo "- ジョブは終わっている（待った秒数 $w）"
echo
echo "## ① ログ"
echo '```'
grep -E "start:|scraped|new targets|✅|❌|=== end" "$LOG" 2>/dev/null | sed -E 's/^\[[^]]*\] //' | hide | head -40
echo '```'
echo
echo "## ② 今日の記録（x279 の経路）"
echo '```'
node -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const t=new Date(Date.now()-30*60000).toISOString();
const rows=Object.values(j).filter(v=>v&&v.followed_at>=t&&String(v.source||"").startsWith("competitor-follower"));
const c={true:0,false:0,null:0};rows.forEach(r=>c[String(r.verified===true?true:r.verified===false?false:null)]++);
console.log("直近 30 分のフォロー "+rows.length+" 件 ／ 認証済み "+c.true+" ・未認証 "+c.false+" ・不明 "+c.null);
' "$W/data/reply-followers.json" 2>&1
echo '```'
echo
echo "## ③ ヘッダー（比率）"
P="$W/.x280-hdr.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => { const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage(); await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('[data-testid="UserName"]', { timeout: 20000 }); await p.waitForTimeout(2500);
  const r = await p.evaluate(() => { const g = (s) => { const a = document.querySelector(s); return a ? a.innerText.replace(/\s+/g, " ") : null; };
    return { following: g('a[href="/heng_ji31590/following"]'), followers: g('a[href="/heng_ji31590/verified_followers"]') || g('a[href="/heng_ji31590/followers"]') }; });
  await p.close(); console.log(JSON.stringify(r)); process.exit(0); })().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 150) })); process.exit(0); });
JS
cd "$W" && node "$P" 2>&1 | tail -1 | node -e 'let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);const n=(x)=>parseInt(String(x||"").replace(/[^0-9]/g,""),10);const a=n(j.following),b=n(j.followers);console.log(JSON.stringify(j)+(a&&b?"  → 比率 "+(a/b).toFixed(3)+"（帯 0.45〜0.65）":""))}catch(e){console.log(s)}'
rm -f "$P"
echo
echo "**何も押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "競合の認証済みフォロワーからのフォロー結果を読んだ / $(basename "$OUT")"
