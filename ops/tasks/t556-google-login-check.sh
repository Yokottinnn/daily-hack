#!/bin/bash
# **Mac の Chrome が、どの Google アカウントでログインしているかを読むだけ（t556）。押さない・申し込まない・$0。**
# 2026-11-03 利用者が「AdSense の申し込みも Mac で進めて」を選んだ。申し込み画面を埋める前に、
# 会社の Google アカウントでログインしているか・AdSense のアカウントが既にあるかを確かめる。
# 出力は公開リポジトリに載るので、メールアドレスは先頭 2 文字とドメインだけ残して伏せる。画面は撮らない。
# 費用（最上位ルール 2-B）: LLM 不使用。1 回 $0・1 日 $0・1 か月 $0
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t556-google-login.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t556-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const mask = (s) => String(s || "").replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2");
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const look = async (name, url) => {
    await p.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 }).catch((e) => { r[name] = { err: String(e.message).slice(0, 120) }; });
    await p.waitForTimeout(8000);
    const info = await p.evaluate(() => {
      const t = document.body ? document.body.innerText.replace(/\s+/g, " ") : "";
      const emails = [...new Set((t.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g) || []))].slice(0, 5);
      const aria = [...document.querySelectorAll("[aria-label]")].map((e) => e.getAttribute("aria-label")).filter((a) => /@|Google アカウント|Google Account/.test(a)).slice(0, 5);
      return { url: location.href, title: document.title, emails, aria, text: t.slice(0, 400) };
    }).catch((e) => ({ err: String(e.message).slice(0, 120) }));
    r[name] = { url: info.url, title: info.title, emails: (info.emails || []).map(mask), aria: (info.aria || []).map(mask), text: mask(info.text), err: info.err };
  };
  await look("myaccount", "https://myaccount.google.com/");
  await look("adsense", "https://adsense.google.com/adsense/");
  await p.close().catch(() => {});
} catch (e) { r.error = String(e && e.message).slice(0, 200); }
console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# Mac の Chrome の Google ログインを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -80
echo '```'
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t556 / $(basename "$OUT")"
