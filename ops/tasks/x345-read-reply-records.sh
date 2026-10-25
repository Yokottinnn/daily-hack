#!/bin/bash
# **返信の効果を測る仕組みの下調べ（x345）。読むだけ。費用 $0。**
# 利用者が「返信の効果を測る」を選んだ（2026-10-26）。増えたフォロワーの大半は返信経由と見立てている（分析ページ KS8ninpfJMt7KVtJ2UMS5A）。
# ① 返信を出すジョブの記録に、自分の返信の投稿 ID・相手・時刻が残っているか ② 自分の返信 1 件の分析画面（/analytics）で、表示・プロフィールへのアクセス・フォローが読めるか
# **返信しない・押さない・画面は撮らない。他人のハンドルは出さない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-records.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g'; }
{
echo "# 返信の記録と分析画面（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. 返信の記録になりそうなファイル（data/ と logs/）"; echo '```'
ls -la "$W"/data 2>/dev/null | grep -iE 'comment|reply|warmup|orchestr|posted' | awk '{print $5, $6, $7, $8, $9}'
ls -la "$W"/logs 2>/dev/null | grep -iE 'comment|reply|warmup|orchestr' | awk '{print $5, $6, $7, $8, $9}'
echo '```'
echo; echo "## 2. それぞれの中身の形（項目名と件数・値は出さない）"; echo '```'
"$NODE_BIN" -e '
const fs=require("fs"),path=require("path");const D=process.argv[1];
for(const f of fs.readdirSync(D).filter(f=>/comment|reply|warmup|orchestr|posted/i.test(f)&&f.endsWith(".json"))){
  let j;try{j=JSON.parse(fs.readFileSync(path.join(D,f),"utf8"))}catch(e){console.log("--- "+f+" 読めない");continue}
  const rows=Array.isArray(j)?j:(j&&typeof j==="object"?(Array.isArray(j.items)?j.items:Array.isArray(j.history)?j.history:Object.values(j)):[]);
  const keys={};rows.filter(r=>r&&typeof r==="object").slice(-300).forEach(r=>Object.keys(r).forEach(k=>keys[k]=(keys[k]||0)+1));
  const idk=Object.keys(keys).filter(k=>/reply.*id|tweet_id|posted_id|my_.*id|status_id|url/i.test(k));
  const tk=Object.keys(keys).find(k=>/posted_at|replied_at|created_at|^at$|ts/i.test(k));
  const recent=tk?rows.filter(r=>r&&r[tk]&&String(r[tk])>="2026-10-19").length:"?";
  console.log("--- "+f+"（"+rows.length+" 件・直近 7 日 "+recent+" 件）項目: "+Object.keys(keys).slice(0,25).join(",")+" ／ ID らしい項目: "+(idk.join(",")||"なし"));
}' "$W/data" 2>&1 | head -40
echo '```'
echo; echo "## 3. 自分の返信 1 件の分析画面（押さない）"; echo '```'
PROBE="$W/.x345-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/heng_ji31590/with_replies", { waitUntil: "domcontentloaded", timeout: 40000 }); await page.waitForTimeout(7000);
  const ids = await page.$$eval('article[data-testid="tweet"]', (as) => as.map((a) => { const t = a.querySelector("time"); const p = t && t.closest("a"); const h = p ? p.getAttribute("href") : "";
    return { href: h, reply: !!a.innerText.match(/返信先|Replying to/) }; }).filter((x) => /\/heng_ji31590\/status\//.test(x.href)));
  r.found = ids.length; const pick = ids.find((x) => x.reply) || ids[0];
  if (pick) { r.pickIsReply = pick.reply;
    await page.goto("https://x.com" + pick.href + "/analytics", { waitUntil: "domcontentloaded", timeout: 40000 }); await page.waitForTimeout(8000);
    const txt = await page.evaluate(() => (document.querySelector('[role="dialog"]') || document.querySelector("main") || document.body).innerText);
    r.analytics = txt.replace(/\s+\n/g, "\n").split("\n").map((s) => s.trim()).filter((s) => s && s.length < 40).slice(0, 60); }
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -1 | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let r={};try{r=JSON.parse(s)}catch(e){console.log("読めない "+s.slice(0,200));return}
console.log("返信タブで見つけた自分の投稿: "+r.found+" 件 ／ 選んだのは返信か: "+r.pickIsReply+(r.error?" ／ エラー: "+r.error:""));(r.analytics||[]).forEach(l=>console.log("  "+l))})' | hide
rm -f "$PROBE"
echo '```'
echo "**読んだだけ。返信・クリックはしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x345 / $(basename "$OUT")"
