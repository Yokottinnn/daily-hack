#!/bin/bash
# **AdSense が拒否される原因を調べる（t694・affiliate）。読むだけ・押さない・$0。**
# t693 は、利用者が会社の Google アカウントを足したあとも u/0〜u/4 のすべてで拒否された。
# ① Chrome に入っている Google アカウントの一覧（メールは伏せる・ドメインだけ出す） ② u/0〜u/4 で AdSense を開いたときの URL と本文の先頭を出す
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t694-adsense-account-diag.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t694-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const PUB = "pub-3805028233672648";
const mask = (s) => String(s || "").replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2");
const NG = /氏名|平素より|ご利用いただき/;
(async () => { const out = []; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const ctxs = b.contexts(); out.push(`- CDP のコンテキスト数: ${ctxs.length}・タブ数: ${ctxs.map((c) => c.pages().length).join(",")}`);
  const p = await ctxs[0].newPage();
  await p.goto("https://accounts.google.com/ListAccounts?gpsia=1&source=ChromiumBrowser&json=standard", { waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
  const raw = await p.evaluate(() => document.body.innerText).catch(() => "");
  const mails = [...raw.matchAll(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+/g)].map((m) => m[0]);
  out.push(`- Google のアカウント一覧（並び順＝u/ の番号）: ${mails.length ? [...new Set(mails)].map((m, i) => `u/${i}=${mask(m)}`).join("・") : "読めない（" + raw.slice(0, 60).replace(/\s+/g, " ") + "）"}`, "");
  for (const u of [0, 1, 2, 3, 4]) {
    await p.goto(`https://adsense.google.com/adsense/u/${u}/${PUB}/home`, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
    await p.waitForTimeout(12000);
    const d = await p.evaluate(() => ({ url: location.href.replace(/[?#].*$/, ""), lines: ((document.querySelector("[role=main], main") || document.body).innerText || "").split("\n").map((x) => x.trim()).filter(Boolean).slice(0, 8) })).catch((e) => ({ url: "", lines: [String(e.message).slice(0, 80)] }));
    out.push(`## u/${u}`, `- URL: ${d.url}`, ...d.lines.filter((x) => !NG.test(x)).map((x) => `  - ${mask(x).slice(0, 110)}`), "");
  }
  await p.close().catch(() => {});
} catch (e) { out.push("- エラー: " + String(e && e.message).slice(0, 200)); }
console.log(out.join("\n")); process.exit(0); })();
PJS
{
echo "# AdSense が拒否される原因を調べる（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -120
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t694 / $(basename "$OUT")"
