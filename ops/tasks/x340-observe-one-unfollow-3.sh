#!/bin/bash
# **x338・x339 と同じ片思い 1 件で、外すボタンを「マウスで押す」形で試し、出てくる画面を記録する（x340）。費用 $0。**
# x339: 「〇〇さんのフォローを解除」を JS の click() で押しても確認画面が出なかった。
# ① そのボタンを Playwright のマウス操作で押す → 出た dialog / menu の中身を記録 → 確定ボタンがあれば押す
# ② まだ外れていなければ「もっと見る」（userActions）のメニュー項目を記録する（押さない）
# **外すのはこの 1 件だけ（片思いとして外す予定だった相手）。フォローしない。画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/observe-one-unfollow-3.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x\.com/)(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1<伏せ>#g; s#\b\d{8,20}-(un)?follow#<id>-$1follow#g'; }
H="$(grep -E '押したが外れていない（購入する）' "$W/logs/follow-balance.log" 2>/dev/null | tail -1 | perl -ne 'print $1 if /@([A-Za-z0-9_]{2,15}):/')"
{
echo "# 外すボタンをマウスで押してみる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
if [ -z "$H" ]; then echo "- 対象が見つからない"; exit 0; fi
PROBE="$W/.x340-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const pick = (page, sel) => page.$$eval(sel, (bs) => bs.map((x) => ({ t: x.getAttribute("data-testid") || "", r: x.getAttribute("role") || x.tagName, a: (x.getAttribute("aria-label") || "").slice(0, 50), x: (x.innerText || "").trim().slice(0, 40) })).filter((b) => b.t || b.a || b.x).slice(0, 15));
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/" + process.argv[2], { waitUntil: "domcontentloaded", timeout: 40000 }); await page.waitForTimeout(6000);
  const btn = page.locator('[aria-label$="さんのフォローを解除"]').first();
  r.count = await page.locator('[aria-label$="さんのフォローを解除"]').count();
  r.box = await btn.boundingBox().catch(() => null);
  r.tag = await btn.evaluate((e) => e.tagName + " role=" + (e.getAttribute("role") || "") + " visible=" + (e.offsetWidth > 0 && e.offsetHeight > 0) + " parent=" + (e.parentElement ? e.parentElement.getAttribute("data-testid") || e.parentElement.tagName : "")).catch((e) => "err " + e.message);
  await btn.click({ timeout: 8000 }).then(() => { r.clicked = true; }).catch((e) => { r.clicked = "err " + String(e.message).slice(0, 120); });
  await page.waitForTimeout(1800);
  r.layers = await pick(page, '[role="dialog"] [role="button"], [role="dialog"] button, [role="menu"] [role="menuitem"], [data-testid="sheetDialog"] *[role]');
  const c = page.locator('[data-testid="confirmationSheetConfirm"]');
  r.confirm = await c.count();
  if (r.confirm) { r.confirmText = (await c.first().innerText()).trim(); await c.first().click({ timeout: 5000 }).catch(() => {}); await page.waitForTimeout(2500); }
  await page.goto("https://x.com/" + process.argv[2], { waitUntil: "domcontentloaded", timeout: 40000 }); await page.waitForTimeout(6000);
  r.afterUnfollowAria = await page.locator('[aria-label$="さんのフォローを解除"]').count();
  r.afterMain = await pick(page, '[data-testid="placementTracking"] [role="button"], [data-testid$="-unfollow"], [data-testid$="-follow"]');
  if (r.afterUnfollowAria) {
    await page.locator('[data-testid="userActions"]').first().click({ timeout: 5000 }).catch(() => {});
    await page.waitForTimeout(1500);
    r.menu = await pick(page, '[role="menu"] [role="menuitem"]');
    await page.keyboard.press("Escape").catch(() => {});
  }
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$H" 2>&1 | tail -1 | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{let r={};try{r=JSON.parse(s)}catch(e){console.log("読めない "+s.slice(0,300));return}
const show=(k,v)=>{console.log("["+k+"]");(v||[]).forEach(b=>console.log("   t="+b.t+" | r="+b.r+" | a="+b.a+" | x="+b.x.replace(/\n/g," ")))};
console.log("count="+r.count+" box="+JSON.stringify(r.box)+" tag="+r.tag+" clicked="+r.clicked+" confirm="+r.confirm+" confirmText="+(r.confirmText||"")+(r.error?" error="+r.error:""));
show("出てきた画面",r.layers);console.log("読み直し後: フォローを解除ボタン="+r.afterUnfollowAria);show("読み直し後のボタン",r.afterMain);if(r.menu)show("もっと見るのメニュー（押していない）",r.menu)})' | hide
rm -f "$PROBE"
echo '```'
echo; echo "**外したのは最大 1 件（片思いとして外す予定だった相手）。フォローしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "x340 / $(basename "$OUT")"
