#!/bin/bash
# **収益化（オリジナルコンテンツ報酬）の条件と、90 日の数字を実物で読む。申し込まない。費用 $0。**
#
# ## なぜ（2026-10-12）
#
#   x269 で分かったこと: クリエイタースタジオの「オリジナルコンテンツ報酬」は **対象外**、
#   アナリティクスの認証済みフォロワーは **122 / 345**、7 日のインプレッションは **26.7K**。
#   だが**条件の実物**（何がいくつ足りないか）は読めていない。公式ヘルプは curl だと
#   Cloudflare の確認画面（Just a moment...）で止まった。**Chrome なら通る**ので Chrome で読む。
#
#   ① クリエイタースタジオで「オリジナルコンテンツ報酬」を開き、条件と進み具合の本文を読む
#   ② 公式ヘルプ（Original Content Rewards）を Chrome で開いて本文を読む
#   ③ アナリティクスを **3M（90 日）** に切り替えて数字を読む
#
# **押すのは「開く」「タブを切り替える」だけ。** 申し込み・登録・同意・支払いの文字があるボタンは押さない。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。** 2 分で終わる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/ocr-requirements.md"
PROBE="$W/.x270-probe.js"
RAW="$W/.x270-out.json"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

cat > "$PROBE" <<'PROBEJS'
// x270: 開く・タブを切り替えるだけ。申し込み系の文字があるものは押さない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [outdir] = process.argv.slice(2);
const NEVER = /申し込|申込|登録|同意|支払|購入|参加する|Apply|Join|Subscribe|Agree|Accept|Pay/i;
const body = (page) => page.evaluate(() => (document.querySelector("main") || document.body).innerText.slice(0, 6000));
async function clickText(page, re) {
  const els = await page.$$('a, [role="link"], [role="tab"], [role="button"], button');
  for (const e of els) {
    const t = ((await e.innerText().catch(() => "")) || "").trim();
    if (!t || t.length > 40 || NEVER.test(t)) continue;
    if (re.test(t)) { await e.click(); return t; }
  }
  return null;
}
(async () => {
  const r = {};
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const page = await b.contexts()[0].newPage();
  await page.setViewportSize({ width: 1280, height: 1600 });
  // ① クリエイタースタジオ → オリジナルコンテンツ報酬
  try {
    await page.goto("https://x.com/i/jf/creators/studio", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(5000);
    r.studioClicked = await clickText(page, /オリジナルコンテンツ報酬|Original Content Rewards/);
    await page.waitForTimeout(6000);
    r.ocr = { url: page.url(), text: await body(page) };
    await page.screenshot({ path: outdir + "/x270-1-ocr.png", fullPage: true });
  } catch (e) { r.ocrError = String(e && e.message).slice(0, 200); }
  // ② 公式ヘルプ
  for (const [k, u] of [["helpEn", "https://help.x.com/en/using-x/original-content-rewards"], ["helpJa", "https://help.x.com/ja/using-x/original-content-rewards"]]) {
    try {
      await page.goto(u, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForTimeout(9000);
      r[k] = { url: page.url(), text: (await page.evaluate(() => document.body.innerText)).slice(0, 7000) };
    } catch (e) { r[k] = { error: String(e && e.message).slice(0, 200) }; }
  }
  // ③ アナリティクス 90 日
  try {
    await page.goto("https://x.com/i/account_analytics", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(5000);
    r.rangeClicked = await clickText(page, /^3M$/);
    await page.waitForTimeout(6000);
    r.analytics90 = (await body(page)).replace(/\n(.)(?=\n)/g, "$1");
    await page.screenshot({ path: outdir + "/x270-2-analytics-3m.png", fullPage: true });
  } catch (e) { r.analyticsError = String(e && e.message).slice(0, 200); }
  await page.close().catch(() => {});
  console.log(JSON.stringify(r));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
PROBEJS

{
echo "# 収益化の条件と 90 日の数字（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・申し込んでいない）"
echo
rm -f "$OUTDIR"/x270-*.png
cd "$W" && node "$PROBE" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log(require("fs").readFileSync(process.argv[1], "utf8").slice(0, 2000)); process.exit(0); }
const sec = (t, v) => { console.log("## " + t + "\n\n```text"); console.log(typeof v === "string" ? v : JSON.stringify(v, null, 1)); console.log("```\n"); };
sec("① オリジナルコンテンツ報酬（押した: " + j.studioClicked + "）", j.ocr || j.ocrError);
sec("② 公式ヘルプ（英語）", j.helpEn);
sec("② 公式ヘルプ（日本語）", j.helpJa);
sec("③ アナリティクス 3M（押した: " + j.rangeClicked + "）", j.analytics90 || j.analyticsError);
if (j.fatal) sec("致命的", j.fatal);
' "$RAW" | secrets | hide
echo "画面: $(ls "$OUTDIR"/x270-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
rm -f "$PROBE" "$RAW"
echo
echo "**申し込み・登録・同意の文字があるものは押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "収益化の条件と 90 日の数字を読んだ / $(basename "$OUT")"
