#!/bin/bash
# **青バッジ取得後の出発点を読む。何も押さない・投稿しない。費用 $0。**
#
# ## なぜ（2026-10-12）
#
#   利用者が Premium（青バッジ）を購入した。戦略を作り直す前に、**推測ではなく実物の数字**を取る
#   （最上位ルール 20）。収益化（Original Content Rewards）の条件は
#   「認証済みフォロワー 500」「直近 90 日の認証済みユーザーからのホーム表示 50 万（返信は除く）」と
#   報じられているが、**公式ページはクラウドから 403 で読めない**ので Mac に読ませる。
#
#   ① 自分のプロフィールのヘッダー（フォロー中・フォロワー・青バッジが付いたか）
#   ② 認証済みフォロワーの数（/verified_followers をスクロールして数える）
#   ③ 収益化の画面（/settings/monetization）とアナリティクス（/i/account_analytics）の本文と画面
#   ④ 公式ヘルプ（Original Content Rewards / Creator Revenue Sharing）の本文
#   ⑤ これまでのフォローの記録で、**相手が認証済みかどうかでフォロバ率がどれだけ違うか**
#
# **何も押さない。LLM を呼ばない（$0／回・$0／日・$0／月）。** 3 分で終わる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/badge-baseline.md"
PROBE="$W/.x269-probe.js"
RAW="$W/.x269-out.json"
ME="heng_ji31590"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

cat > "$PROBE" <<'PROBEJS'
// x269: 読むだけ。クリックは「スクロール」以外しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, outdir] = process.argv.slice(2);
const text = (page) => page.evaluate(() => (document.querySelector("main") || document.body).innerText.slice(0, 4000));
(async () => {
  const r = {};
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const ctx = b.contexts()[0];
  const page = await ctx.newPage();
  await page.setViewportSize({ width: 1280, height: 1400 });
  // ① ヘッダー
  try {
    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('[data-testid="UserName"]', { timeout: 20000 });
    await page.waitForTimeout(2500);
    r.header = await page.evaluate((me) => {
      const pick = (sel) => { const a = document.querySelector(sel); return a ? a.innerText.replace(/\s+/g, " ").trim() : null; };
      const name = document.querySelector('[data-testid="UserName"]');
      return {
        following: pick('a[href="/' + me + '/following"]'),
        followers: pick('a[href="/' + me + '/verified_followers"]') || pick('a[href="/' + me + '/followers"]'),
        badge: !!(name && name.querySelector('[data-testid="icon-verified"], svg[aria-label*="認証"], svg[aria-label*="erified"]')),
      };
    }, me);
    await page.screenshot({ path: outdir + "/x269-1-profile.png", clip: { x: 0, y: 0, width: 1280, height: 700 } });
  } catch (e) { r.headerError = String(e && e.message).slice(0, 200); }
  // ② 認証済みフォロワー
  try {
    await page.goto("https://x.com/" + me + "/verified_followers", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(3000);
    const seen = new Set();
    let still = 0;
    const t0 = Date.now();
    while (Date.now() - t0 < 75000 && still < 4) {
      const hs = await page.$$eval('[data-testid="UserCell"] a[role="link"][href^="/"]', (as) => as.map((a) => a.getAttribute("href").slice(1)).filter((h) => h && !h.includes("/")));
      const before = seen.size;
      hs.forEach((h) => seen.add(h.toLowerCase()));
      still = seen.size === before ? still + 1 : 0;
      await page.mouse.wheel(0, 2400);
      await page.waitForTimeout(1500);
    }
    seen.delete(me.toLowerCase());
    r.verifiedFollowers = { count: seen.size, stoppedBy: still >= 4 ? "末尾まで来た" : "75 秒で打ち切り" };
  } catch (e) { r.verifiedError = String(e && e.message).slice(0, 200); }
  // ③ 収益化とアナリティクス
  for (const [k, url] of [["monetization", "https://x.com/settings/monetization"], ["analytics", "https://x.com/i/account_analytics"]]) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForTimeout(6000);
      r[k] = { url: page.url(), text: await text(page) };
      await page.screenshot({ path: outdir + "/x269-" + k + ".png", fullPage: false });
    } catch (e) { r[k] = { error: String(e && e.message).slice(0, 200) }; }
  }
  await page.close().catch(() => {});
  console.log(JSON.stringify(r));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
PROBEJS

{
echo "# 青バッジ取得後の出発点（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も押していない）"
echo
echo "## ①②③ プロフィール・認証済みフォロワー・収益化・アナリティクス"
echo
rm -f "$OUTDIR"/x269-*.png
cd "$W" && node "$PROBE" "$ME" "$OUTDIR" > "$RAW" 2>&1
echo '```json'
node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());console.log(JSON.stringify(j,null,1))}catch(e){console.log(require("fs").readFileSync(process.argv[1],"utf8").slice(0,2000))}' "$RAW" | secrets | hide
echo '```'
echo
echo "画面: $(ls "$OUTDIR"/x269-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
echo
echo "## ④ 公式ヘルプの本文"
for u in "https://help.x.com/en/using-x/original-content-rewards" "https://help.x.com/ja/using-x/original-content-rewards" "https://help.x.com/en/using-x/creator-revenue-sharing"; do
  echo
  echo "### $u"
  echo
  echo '```text'
  body="$(curl -sL --max-time 25 -A 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36' "$u")"
  printf 'HTTP 本文の長さ: %s bytes\n' "${#body}"
  printf '%s' "$body" | node -e 'let s=require("fs").readFileSync(0,"utf8");s=s.replace(/<script[\s\S]*?<\/script>/gi,"").replace(/<style[\s\S]*?<\/style>/gi,"").replace(/<\/(p|li|h[1-6]|div|tr)>/gi,"\n").replace(/<[^>]+>/g," ").replace(/&nbsp;/g," ").replace(/&amp;/g,"&").replace(/&#39;/g,"'"'"'").replace(/&quot;/g,"\"").replace(/[ \t]+/g," ").replace(/\n\s*\n+/g,"\n");const i=s.search(/eligib|requirement|対象|条件/i);console.log(s.slice(Math.max(0,i-400),Math.max(0,i-400)+6000))'
  echo '```'
done
echo
echo "## ⑤ 相手が認証済みかどうかで、フォロバ率はどれだけ違うか"
echo
echo '```text'
node -e '
const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const rows = Object.values(j).filter((v) => v && typeof v === "object");
const now = Date.now(), MATURE = 3 * 86400000;
const isBack = (r) => r.follows_back === true || String(r.followback_status || "").toLowerCase() === "yes";
const g = {};
for (const r of rows) {
  const v = r.verified === true ? "認証済み" : r.verified === false ? "未認証" : "(記録なし)";
  const k = v + " / " + (r.source || "(source なし)");
  const c = g[k] || (g[k] = { n: 0, mature: 0, back: 0 });
  c.n++;
  const t = Date.parse(r.followed_at || "");
  if (t && now - t >= MATURE) { c.mature++; if (isBack(r)) c.back++; }
}
console.log("全 " + rows.length + " 件（フォローから 3 日以上 経ったものだけで率を出す）\n");
console.log("認証 / 経路".padEnd(44) + "件数  判定可  返った  率");
for (const [k, c] of Object.entries(g).sort((a, b) => b[1].n - a[1].n))
  console.log(k.padEnd(44) + String(c.n).padStart(4) + String(c.mature).padStart(8) + String(c.back).padStart(8) + "  " + (c.mature ? (100 * c.back / c.mature).toFixed(1) + "%" : "-"));
const keys = new Set(); rows.slice(-5).forEach((r) => Object.keys(r).forEach((k) => keys.add(k)));
console.log("\n記録が持つキー（直近 5 件）: " + [...keys].join(", "));
' "$W/data/reply-followers.json" 2>&1 | hide
echo '```'
echo
echo "## ⑥ 能動フォローの設定（いまの上限）"
echo
echo '```text'
for L in competitor-follower-follow hashtag-follow badge-followback follow-balance mutual-prune; do
  P="$HOME/Library/LaunchAgents/ai.openclaw.$L.plist"
  [ -f "$P" ] || { echo "$L: plist なし"; continue; }
  envs="$(plutil -extract EnvironmentVariables json -o - "$P" 2>/dev/null | node -e 'try{const j=JSON.parse(require("fs").readFileSync(0,"utf8"));console.log(Object.entries(j).filter(([k])=>!/TOKEN|KEY|SECRET|PASS/i.test(k)).map(([k,v])=>k+"="+v).join(" "))}catch(e){console.log("(なし)")}')"
  echo "$L: $envs"
done
grep -nE "DAILY_CAP[[:space:]]*=" "$W/scripts/competitor-follower-follow.js" "$W/scripts/hashtag-follow.js" 2>/dev/null | head -4
echo '```'
rm -f "$PROBE" "$RAW"
echo
echo "**何も押していない（スクロールだけ）。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "青バッジ取得後の出発点を読んだ / $(basename "$OUT")"
