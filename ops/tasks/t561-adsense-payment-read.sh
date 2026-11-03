#!/bin/bash
# **AdSense の「お支払い: お客様についてお知らせください」の画面を読むだけ（t561）。「情報を入力」だけ押す・入力しない・送信しない・$0。**
# t560 で申し込みが通り、AdSense のホームに着いた（pub-3805028233672648）。必須の手順はお支払い情報とサイトのリンクの 2 つ。
# お支払い情報ではアカウントの種類（組織／個人・あとで変えられない）を選ぶので、選ぶ前に聞かれる項目を読んで利用者に見せる。
# 出力は公開リポジトリに載るので、画面は撮らず、メールアドレスは伏せる。
# 費用（最上位ルール 2-B）: LLM 不使用。1 回 $0・1 日 $0・1 か月 $0
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t561-adsense-payment-read.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t561-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const mask = (s) => String(s || "").replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2");
const read = (p) => p.evaluate(() => {
  const vis = (e) => !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);
  const label = (e) => (e.getAttribute("aria-label") || (e.labels && e.labels[0] && e.labels[0].innerText) || e.placeholder || e.name || "").trim().slice(0, 80);
  return { url: location.href, title: document.title, text: document.body.innerText.replace(/\s+/g, " ").slice(0, 2500),
    inputs: [...document.querySelectorAll("input, select, textarea, [role=radio], [role=combobox], [role=listbox]")].filter(vis).map((e) => ({ tag: e.tagName, type: e.type || e.getAttribute("role"), label: label(e) })).slice(0, 40),
    buttons: [...document.querySelectorAll("button, [role=button]")].filter(vis).map((e) => (e.innerText || e.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ").slice(0, 50)).filter(Boolean).slice(0, 30),
    frames: [...document.querySelectorAll("iframe")].map((f) => f.src.slice(0, 120)).slice(0, 5) };
}).catch((e) => ({ err: String(e.message).slice(0, 120) }));
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://adsense.google.com/adsense/u/0/pub-3805028233672648/onboarding", { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
  await p.waitForTimeout(10000);
  const btn = p.getByRole("button", { name: /情報を入力/ }).first();
  if (await btn.count().catch(() => 0)) { await btn.click().catch((e) => { r.clickErr = String(e.message).slice(0, 100); }); r.clicked = "情報を入力"; await p.waitForTimeout(12000); }
  r.page = await read(p);
  // お支払いの入力は Google お支払いセンターの iframe の中にあることが多い。中も読む（入力しない）
  r.frames = [];
  for (const f of p.frames()) { if (f === p.mainFrame()) continue; if (!/payments|pay\.google|billing/.test(f.url())) continue;
    const t = await f.evaluate(() => ({ url: location.href.slice(0, 120), text: document.body.innerText.replace(/\s+/g, " ").slice(0, 2500),
      inputs: [...document.querySelectorAll("input, select, [role=radio], [role=combobox], [role=listbox]")].map((e) => ({ type: e.type || e.getAttribute("role"), label: (e.getAttribute("aria-label") || e.name || "").slice(0, 60) })).slice(0, 40) })).catch((e) => ({ err: String(e.message).slice(0, 100) }));
    r.frames.push(t); }
  await p.close().catch(() => {});
} catch (e) { r.error = String(e && e.message).slice(0, 200); }
if (r.page) r.page.text = mask(r.page.text);
for (const f of r.frames || []) if (f.text) f.text = mask(f.text);
console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# AdSense のお支払い情報の画面を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・入力しない・送信しない・\$0）"
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -200
echo '```'
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t561 / $(basename "$OUT")"
