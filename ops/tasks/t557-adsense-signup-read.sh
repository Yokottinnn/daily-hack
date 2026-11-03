#!/bin/bash
# **AdSense の申し込み画面で、何を聞かれるか（入力欄・選択肢・規約の文言）を読むだけ（t557）。入力しない・押さない・$0。**
# t556 で、Mac の Chrome は会社の Google アカウント（n-***@fieldbeside.com）でログイン済み・AdSense のアカウントは無いと分かった。
# 利用者は「Mac で私が進める」を選び、規約に同意する前で止めて画面を見せる約束になっている。
# 出力は公開リポジトリに載るので、画面は撮らず、メールアドレスは伏せる。
# 費用（最上位ルール 2-B）: LLM 不使用。1 回 $0・1 日 $0・1 か月 $0
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t557-adsense-signup-read.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t557-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const mask = (s) => String(s || "").replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://adsense.google.com/adsense/signup", { waitUntil: "domcontentloaded", timeout: 45000 }).catch((e) => { r.err = String(e.message).slice(0, 120); });
  await p.waitForTimeout(12000);
  r.page = await p.evaluate(() => {
    const vis = (e) => !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);
    const label = (e) => (e.getAttribute("aria-label") || (e.labels && e.labels[0] && e.labels[0].innerText) || e.placeholder || e.name || "").trim().slice(0, 80);
    return {
      url: location.href, title: document.title,
      text: document.body.innerText.replace(/\s+/g, " ").slice(0, 1500),
      inputs: [...document.querySelectorAll("input, select, textarea, [role=combobox], [role=checkbox], [role=radio]")].filter(vis).map((e) => ({ tag: e.tagName, type: e.type || e.getAttribute("role"), label: label(e), checked: e.checked ?? e.getAttribute("aria-checked") })).slice(0, 30),
      buttons: [...document.querySelectorAll("button, [role=button], a")].filter(vis).map((e) => (e.innerText || e.getAttribute("aria-label") || "").trim().replace(/\s+/g, " ").slice(0, 50)).filter(Boolean).slice(0, 30),
      links: [...document.querySelectorAll("a")].filter(vis).map((a) => `${(a.innerText || "").trim().slice(0, 40)} → ${a.href}`).filter((x) => /規約|terms|policy|ポリシー/i.test(x)).slice(0, 10),
    };
  }).catch((e) => ({ err: String(e.message).slice(0, 120) }));
  r.page.text = mask(r.page.text);
  await p.close().catch(() => {});
} catch (e) { r.error = String(e && e.message).slice(0, 200); }
console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# AdSense の申し込み画面を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・入力しない・押さない・\$0）"
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -120
echo '```'
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t557 / $(basename "$OUT")"
