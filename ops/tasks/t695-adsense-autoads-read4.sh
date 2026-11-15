#!/bin/bash
# **AdSense の画面で、自動広告がオンかを読むだけ・4 回目（t695・affiliate）。押さない・入力しない・$0。**
# 2026-11-15 に AdSense が承認された。利用者から「自動広告がオンかどうかは自分で確認して」と言われた。
# 2026-11-15 20:35 利用者が gmail のプロファイルの窓を閉じ、CDP が会社のプロファイルにつながった（t694 で AdSense のホームが読めた）。
# 出力は公開リポジトリに載るので、画面は撮らない。読むのは本文（role=main）だけで、上のアカウント欄（氏名が出る）は読まない。
# メールアドレスは伏せ、金額（¥・$ の後の数字）は # に伏せる。
# 費用（最上位ルール 2-B）: LLM 不使用。1 回 $0
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t695-adsense-autoads-read.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t695-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const PUB = "pub-3805028233672648";
const mask = (s) => String(s || "")
  .replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2")
  .replace(/([¥$￥]\s?)[0-9][0-9,.]*/g, "$1#")
  .replace(/[0-9][0-9,.]*\s?(円|ドル|USD|JPY)/g, "#$1");
const NG = /氏名|Google アカウント|平素より|ご利用いただき|アカウントを選択/;
(async () => { const out = []; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  let U = -1;
  for (const u of [0, 1, 2, 3, 4]) {
    await p.goto(`https://adsense.google.com/adsense/u/${u}/${PUB}/home`, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
    await p.waitForTimeout(9000);
    const denied = await p.evaluate(() => /アクセスが拒否されました|アクセス権がない/.test(document.body.innerText) || /\/login/.test(location.href)).catch(() => true);
    out.push(`- u/${u}: ${denied ? "拒否・ログイン画面" : "**読める**"}`);
    if (!denied) { U = u; break; }
  }
  out.push("");
  if (U < 0) { console.log(out.join("\n")); process.exit(0); }
  for (const [name, url] of [
    ["ホーム", `https://adsense.google.com/adsense/u/${U}/${PUB}/home`],
    ["広告 › サイトごと", `https://adsense.google.com/adsense/u/${U}/${PUB}/myads/sites`],
    ["サイト", `https://adsense.google.com/adsense/u/${U}/${PUB}/sites/my-sites`],
    ["自動広告の設定（daily-hack）", `https://adsense.google.com/adsense/u/${U}/${PUB}/myads/sites/preview?url=daily-hack.fieldbeside.com`],
    ["お支払い・本人確認", `https://adsense.google.com/adsense/u/${U}/${PUB}/payments`],
  ]) {
    await p.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
    await p.waitForTimeout(12000);
    const d = await p.evaluate(() => {
      const root = document.querySelector("[role=main], main") || document.body;
      const lines = root.innerText.split("\n").map((x) => x.trim()).filter(Boolean);
      const toggles = [...root.querySelectorAll("[role=switch], [role=checkbox], material-toggle, mat-slide-toggle, input[type=checkbox]")]
        .map((e) => `${(e.getAttribute("aria-label") || e.closest("[aria-label]")?.getAttribute("aria-label") || e.parentElement?.innerText || "").trim().replace(/\s+/g, " ").slice(0, 60)} = ${e.getAttribute("aria-checked") ?? e.getAttribute("aria-pressed") ?? e.checked}`);
      return { url: location.href.replace(/\?.*$/, ""), title: document.title, lines: lines.slice(0, 200), toggles: toggles.slice(0, 20) };
    }).catch((e) => ({ err: String(e.message).slice(0, 120) }));
    out.push(`## ${name}`, `- URL: ${d.url || ""}（題名 ${d.title || ""}）`);
    if (d.err) out.push(`- 読めない: ${d.err}`);
    if (d.toggles && d.toggles.length) out.push("- 切り替え:", ...d.toggles.map((x) => `  - ${mask(x)}`));
    out.push("- 本文:", ...(d.lines || []).filter((x) => !NG.test(x) && x.length < 120).map((x) => `  - ${mask(x)}`), "");
  }
  await p.close().catch(() => {});
} catch (e) { out.push(`- エラー: ${String(e && e.message).slice(0, 200)}`); }
console.log(out.join("\n")); process.exit(0); })();
PJS
{
echo "# AdSense の自動広告がオンかを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・押さない・入力しない・\$0）"
echo ""
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -400
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t695 / $(basename "$OUT")"
