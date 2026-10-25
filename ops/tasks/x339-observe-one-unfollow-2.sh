#!/bin/bash
# **follow-balance が「押したが外れていない（購入する）」とした相手 1 件で、「〇〇さんのフォローを解除」のボタン（x338 で見つけた本当の外すボタン）を 1 回だけ押し、各段階のボタンを記録する（x339）。費用 $0。**
# 相手は follow-balance が「片思い（24 時間を過ぎて返っていない）」として外そうとした相手（最上位ルール 19 で外してよい）。外すのは 1 件だけ。
# ① 押す前 ② フォロー中を押した直後（確認画面の中身） ③ 確定を押した直後 ④ ページを読み直したあと、のボタンを記録する。
# **フォローはしない。画面は撮らない。ハンドルは伏せる。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/observe-one-unfollow-2.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g; s#\b\d{8,20}-(un)?follow#<id>-$1follow#g'; }
H="$(grep -E '押したが外れていない（購入する）' "$W/logs/follow-balance.log" 2>/dev/null | tail -1 | perl -ne 'print $1 if /@([A-Za-z0-9_]{2,15}):/')"
{
echo "# 外す操作を 1 件だけ観察する（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
if [ -z "$H" ]; then echo "- 対象が見つからない。何もしない"; exit 0; fi
PROBE="$W/.x339-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const dump = (page, sel) => page.$$eval(sel, (bs) => bs.map((x) => ({ t: x.getAttribute("data-testid") || "", a: (x.getAttribute("aria-label") || "").slice(0, 50), x: (x.innerText || "").trim().slice(0, 30) }))
  .filter((b) => /follow|confirm|cancel|subscri|購入|フォロー|サブスク|解除/i.test(b.t + " " + b.a + " " + b.x)));
(async () => { const r = { steps: {} }; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  const go = async () => { await page.goto("https://x.com/" + process.argv[2], { waitUntil: "domcontentloaded", timeout: 40000 }); await page.waitForTimeout(6000); };
  await go(); r.steps["1_before"] = await dump(page, "button,[role=button]");
  const clicked = await page.evaluate(() => { const bs = Array.from(document.querySelectorAll("button,[role=button]"));
    const t = bs.find((b) => /さんのフォローを解除$|^Unfollow @/.test(b.getAttribute("aria-label") || "")); if (t) { t.click(); return true; } return false; });
  r.clicked = clicked; await page.waitForTimeout(1500);
  r.steps["2_after_click_dialog"] = await dump(page, '[role="dialog"] button, [role="dialog"] [role=button], [data-testid="sheetDialog"] [role=button]');
  r.steps["2_after_click_all"] = await dump(page, "button,[role=button]");
  r.confirmFound = await page.evaluate(() => { const c = document.querySelector("[data-testid=confirmationSheetConfirm]"); if (c) { c.click(); return (c.innerText || "").trim(); } return null; });
  await page.waitForTimeout(2500);
  r.steps["3_after_confirm"] = await dump(page, "button,[role=button]");
  await go(); r.steps["4_reloaded"] = await dump(page, "button,[role=button]");
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$H" 2>&1 | tail -1 | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let r={};try{r=JSON.parse(s)}catch(e){console.log("読めない "+s.slice(0,200));return}
console.log("clicked="+r.clicked+" confirm="+JSON.stringify(r.confirmFound)+(r.error?" error="+r.error:""));
for(const [k,v] of Object.entries(r.steps||{})){console.log("["+k+"]");(v||[]).slice(0,12).forEach(b=>console.log("   t="+b.t+" | a="+b.a+" | x="+b.x.replace(/\n/g," ")))}})' | hide
rm -f "$PROBE"
echo '```'
echo; echo "**外したのは 1 件だけ（片思いとして外す予定だった相手）。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x339 / $(basename "$OUT")"
