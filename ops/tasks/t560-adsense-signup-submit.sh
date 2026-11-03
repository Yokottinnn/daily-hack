#!/bin/bash
# **AdSense に申し込む（t560）。サイト fieldbeside.com・情報配信「希望しない」・規約に同意して「AdSense 利用を開始する」を押す。$0。**
# 2026-11-03 利用者がダイアログで「同意して進めて」「（情報配信は）希望しない」を選んだ（会社として AdSense の利用規約に同意してよい）。
# t559 で読んだフォーム: ウェブサイト（テキスト）・サイトを持っていません（チェック・押さない）・情報配信（はい／いいえ）・国（日本・固定）・
#   「利用規約を確認し、内容に同意します」（チェック）・「AdSense 利用を開始する」（ボタン）。reCAPTCHA つき。
# **押した次の画面は読むだけで止める**（お支払い情報で「組織」を選ぶ前に、利用者に見せる約束）。
# 出力は公開リポジトリに載るので、画面は撮らず、メールアドレスは伏せる。
# 費用（最上位ルール 2-B）: LLM 不使用。1 回 $0・1 日 $0・1 か月 $0
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t560-adsense-signup-submit.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t560-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const mask = (s) => String(s || "").replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2");
const read = (p) => p.evaluate(() => {
  const vis = (e) => !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);
  return { url: location.href, title: document.title, text: document.body.innerText.replace(/\s+/g, " ").slice(0, 1800),
    buttons: [...document.querySelectorAll("button, [role=button]")].filter(vis).map((e) => (e.innerText || e.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ").slice(0, 50)).filter(Boolean).slice(0, 25),
    inputs: [...document.querySelectorAll("input, select, [role=radio], [role=combobox]")].filter(vis).map((e) => ({ type: e.type || e.getAttribute("role"), label: (e.getAttribute("aria-label") || e.name || e.placeholder || "").slice(0, 60), checked: e.checked })).slice(0, 30) };
}).catch((e) => ({ err: String(e.message).slice(0, 120) }));
(async () => { const r = { steps: [] }; const step = (s) => r.steps.push(s); try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://adsense.google.com/adsense/signup", { waitUntil: "domcontentloaded", timeout: 45000 }).catch((e) => step("goto err " + String(e.message).slice(0, 80)));
  await p.waitForTimeout(8000);
  const chooser = p.locator('[data-identifier$="@fieldbeside.com"], div[role=link]:has-text("@fieldbeside.com")').first();
  if (await chooser.count().catch(() => 0)) { await chooser.click().catch(() => {}); step("会社のアカウントを選んだ"); await p.waitForTimeout(10000); }
  if (!/signup\/create/.test(p.url())) { r.stopped = "申し込みフォームに着かなかった"; r.page = await read(p); throw new Error("not on form"); }
  // 1) ウェブサイト
  const site = p.locator('input[type=text]').first();
  await site.fill("fieldbeside.com"); step("ウェブサイト: fieldbeside.com");
  // 2) 情報配信: いいえ
  const no = p.locator('input[type=radio]').nth(1);
  const noLabel = await no.evaluate((e) => (e.getAttribute("aria-label") || (e.labels && e.labels[0] && e.labels[0].innerText) || e.closest("label, mat-radio-button, div")?.innerText || "").trim()).catch(() => "");
  if (!/いいえ/.test(noLabel)) { r.stopped = "2 つ目のラジオが「いいえ」でない: " + noLabel.slice(0, 60); r.page = await read(p); throw new Error("radio mismatch"); }
  await no.check({ force: true }).catch(async () => { await no.click({ force: true }); }); step("情報配信: いいえ");
  // 3) 利用規約のチェック（「利用規約を確認し」の文の近くにあるもの。「サイトを持っていません」は押さない）
  const boxes = p.locator('input[type=checkbox]'); const nb = await boxes.count(); let termsIdx = -1;
  for (let i = 0; i < nb; i++) {
    const t = await boxes.nth(i).evaluate((e) => { let n = e; for (let k = 0; k < 6 && n; k++) { if (/利用規約を確認し/.test(n.innerText || "")) return "terms"; if (/サイトを持っていません/.test(n.innerText || "")) return "nosite"; n = n.parentElement; } return ""; }).catch(() => "");
    if (t === "terms") { termsIdx = i; break; }
  }
  if (termsIdx < 0) { r.stopped = "規約のチェックが見つからない"; r.page = await read(p); throw new Error("no terms box"); }
  await boxes.nth(termsIdx).check({ force: true }).catch(async () => { await boxes.nth(termsIdx).click({ force: true }); }); step(`利用規約に同意（チェック ${termsIdx + 1} 番目）`);
  r.before = await p.evaluate(() => [...document.querySelectorAll("input")].map((e) => `${e.type}:${e.type === "text" ? e.value : e.checked}`)).catch(() => []);
  // 4) 申し込む
  const go = p.getByRole("button", { name: /AdSense 利用を開始する/ }).first();
  await go.click({ timeout: 15000 }).catch((e) => step("開始ボタン err " + String(e.message).slice(0, 80))); step("「AdSense 利用を開始する」を押した");
  await p.waitForTimeout(20000);
  // 5) 次の画面は読むだけ
  r.page = await read(p);
  await p.close().catch(() => {});
} catch (e) { if (!r.stopped) r.error = String(e && e.message).slice(0, 200); }
if (r.page) { r.page.text = mask(r.page.text); }
console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# AdSense に申し込む（$(date '+%Y-%m-%d %H:%M:%S') JST・利用者の同意あり・次の画面は読むだけ・\$0）"
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -150
echo '```'
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t560 / $(basename "$OUT")"
