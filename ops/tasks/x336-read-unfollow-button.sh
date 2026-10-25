#!/bin/bash
# **follow-balance が「押したが外れていない（購入する）」になる原因を読む（x336）。読むだけ。外さない・押さない。費用 $0。**
# x335: 10/25 の回で外せたのは 2 件だけ。押したボタンの名前が「購入する」で、フォロー中のボタンではなかった。
# ① 外す処理のコード（ボタンの選び方）を読む ② 片思いの候補 1 件のプロフィールで、ボタンの並び（testid・aria-label・文字）を読む。
# **押さない。画面は撮らない。ハンドルは伏せる。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/unfollow-button.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g'; }
FB="$(ls "$S"/follow-balance.js 2>/dev/null || ls "$S"/*follow-balance*.js 2>/dev/null | head -1)"
{
echo "# 外すボタンの押し間違いを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## 1. 外す処理のコード（$(basename "$FB")・ボタンに関わる行の前後）"; echo '```'
grep -n -E 'unfollow|フォロー中|Following|aria-label|data-testid|confirmationSheet|購入|外れていない|button' "$FB" | head -60 | cut -c1-220 | hide
echo '```'
echo; echo "## 2. 片思いの候補 1 件のプロフィールのボタン（押さない）"; echo '```'
CAND="$("$NODE_BIN" -e '
const fs=require("fs"),path=require("path");const d=process.argv[1];
const files=fs.readdirSync(d).filter(f=>/follow|following|unfollow|one.?way/i.test(f)&&f.endsWith(".json")).map(f=>path.join(d,f));
for(const f of files){try{const j=JSON.parse(fs.readFileSync(f,"utf8"));const s=JSON.stringify(j);const m=s.match(/"(?:handle|screen_name|username)"\s*:\s*"([A-Za-z0-9_]{2,15})"/);if(m&&m[1]!=="heng_ji31590"){console.log(m[1]);process.exit(0)}}catch(e){}}' "$W/data" 2>/dev/null)"
if [ -z "$CAND" ]; then echo "  候補のハンドルがデータから取れない"; else
PROBE="$W/.x336-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/" + process.argv[2], { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForTimeout(7000);
  r.buttons = await page.$$eval('[data-testid="primaryColumn"] [role="button"], [data-testid="primaryColumn"] button', (bs) => bs.slice(0, 40).map((x) => ({
    testid: x.getAttribute("data-testid") || "", aria: (x.getAttribute("aria-label") || "").slice(0, 60), text: (x.innerText || "").trim().slice(0, 30) })).filter((x) => x.testid || x.aria || x.text));
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" "$CAND" 2>&1 | tail -1 | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let r={};try{r=JSON.parse(s)}catch(e){console.log("  読めない: "+s.slice(0,200));return}
if(r.error)console.log("  エラー: "+r.error);(r.buttons||[]).forEach(b=>console.log("  testid="+b.testid+" | aria="+b.aria+" | text="+b.text.replace(/\n/g," ")))})' | hide
rm -f "$PROBE"; fi
echo '```'
echo; echo "**押していない・外していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x336 / $(basename "$OUT")"
