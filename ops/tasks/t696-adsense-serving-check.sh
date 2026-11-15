#!/bin/bash
# **AdSense の広告が本当に出ないのか、原因を確かめる（t696・affiliate）。読むだけ・押さない・$0。**
# 2026-11-15 利用者がダイアログで「Mac で確かめる」を選んだ。クラウドから本番を開くと自動広告の枠は unfilled だったが、
# 原因（身元確認の未完了か、データセンターの回線・自動操作のブラウザだからか）は確証が無い。
# ① Mac の Chrome（自宅の回線・会社のプロファイル）で本番の記事を開き、広告が入るか ② AdSense のレポートの広告リクエスト・表示回数が 0 か 1 以上か
# ③ ポリシー センターの通知 ④ お支払い › 身元確認の状態
# 公開リポジトリに載るので、数字は 0 か「1 以上」だけ、金額は # に伏せる。氏名の出るアカウント欄は読まない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t696-adsense-serving-check.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t696-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const PUB = "pub-3805028233672648";
const mask = (s) => String(s || "")
  .replace(/([A-Za-z0-9._%+-]{1,2})[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+)/g, "$1***@$2")
  .replace(/([¥$￥]\s?)[0-9][0-9,.]*/g, "$1#").replace(/[0-9][0-9,.]*\s?(円|ドル|USD|JPY)/g, "#$1");
const NG = /氏名|平素より|ご利用いただき/;
const zeroOrMore = (t) => { const m = String(t).replace(/[,，\s]/g, "").match(/^[¥￥$]?([0-9]+(?:\.[0-9]+)?)[%％]?$/); return m ? (Number(m[1]) === 0 ? "0" : "1 以上") : null; };
(async () => { const out = []; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  // ① 本番の記事
  for (const slug of ["point-service-complete-guide-2026", "lalaport-guide-2026"]) {
    await p.goto(`https://daily-hack.fieldbeside.com/posts/${slug}/`, { waitUntil: "load", timeout: 45000 }).catch(() => {});
    for (let i = 0; i < 10; i++) { await p.mouse.wheel(0, 1200); await p.waitForTimeout(1500); }
    await p.waitForTimeout(6000);
    const d = await p.evaluate(() => ({
      ins: [...document.querySelectorAll("ins.adsbygoogle")].map((x) => `${x.getAttribute("data-ad-status") || "状態なし"}${x.closest(".google-auto-placed") ? "（本文に自動で置かれた）" : ""}${x.getAttribute("data-anchor-status") ? "（アンカー）" : ""}${x.getAttribute("data-ad-hi") ? "（全画面用の控え）" : ""}・高さ ${x.offsetHeight}`),
      auto: document.querySelectorAll(".google-auto-placed").length,
      cfg: JSON.stringify(window.google_ad_modifications || {}).slice(0, 200),
    })).catch((e) => ({ ins: [], auto: -1, cfg: String(e.message).slice(0, 80) }));
    out.push(`## 本番の記事 ${slug}（Mac の回線・会社のプロファイル）`, `- 本文に自動で置かれた広告: ${d.auto}`, `- 広告の枠: ${d.ins.length ? d.ins.join(" ／ ") : "なし"}`, `- AdSense の設定: ${d.cfg}`, "");
  }
  // ②③④ AdSense の画面
  for (const [name, url] of [
    ["レポート（既定）", `https://adsense.google.com/adsense/u/0/${PUB}/reporting`],
    ["ポリシー センター", `https://adsense.google.com/adsense/u/0/${PUB}/policy-center`],
    ["お支払い", `https://adsense.google.com/adsense/u/0/${PUB}/payments`],
  ]) {
    await p.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 }).catch(() => {});
    await p.waitForTimeout(14000);
    const lines = await p.evaluate(() => ((document.querySelector("[role=main], main") || document.body).innerText || "").split("\n").map((x) => x.trim()).filter(Boolean).slice(0, 220)).catch(() => []);
    out.push(`## ${name}`, `- URL: ${p.url().replace(/[?#].*$/, "")}`);
    for (let i = 0; i < lines.length; i++) {
      const x = lines[i]; if (NG.test(x) || x.length > 140) continue;
      const z = zeroOrMore(x);
      if (z !== null) { out.push(`  - ［数字］${z}`); continue; }
      out.push(`  - ${mask(x)}`);
    }
    out.push("");
  }
  await p.close().catch(() => {});
} catch (e) { out.push("- エラー: " + String(e && e.message).slice(0, 200)); }
console.log(out.join("\n")); process.exit(0); })();
PJS
{
echo "# AdSense の広告が出ない原因を確かめる（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ）"
echo ""
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -500
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t696 / $(basename "$OUT")"
