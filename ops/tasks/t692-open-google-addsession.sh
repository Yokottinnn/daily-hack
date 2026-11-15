#!/bin/bash
# **Mac の Chrome for Testing（CDP 18810）に、Google の「アカウントを追加」画面を開いて前に出す（t692・affiliate）。開くだけ・入力しない・$0。**
# 2026-11-15 利用者がダイアログで「Mac でログインする」を選んだ。会社の Google アカウントを足してもらい、AdSense の画面を読めるようにする（t690・t691 は拒否された）。
# 利用者は Chrome for Testing の起動のしかたが分からない。Chrome は ensure-chrome が常に動かしているので、2 つ目を起動させずに、動いている窓にタブを開いて前に出す。
# タブは閉じない（利用者がログインに使う）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/t692-open-google-addsession.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t692-open.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
(async () => { const out = []; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.goto("https://accounts.google.com/AddSession?continue=" + encodeURIComponent("https://adsense.google.com/adsense/u/0/pub-3805028233672648/home"), { waitUntil: "domcontentloaded", timeout: 45000 }).catch((e) => out.push("- 開けない: " + String(e.message).slice(0, 100)));
  await p.bringToFront().catch(() => {});
  out.push(`- 開いた: ${p.url().replace(/\?.*$/, "")}（題名 ${(await p.title().catch(() => "")).slice(0, 40)}）`);
} catch (e) { out.push("- エラー: " + String(e && e.message).slice(0, 200)); }
console.log(out.join("\n")); process.exit(0); })();
PJS
{
echo "# Chrome for Testing に Google の「アカウントを追加」を開く（$(date '+%Y-%m-%d %H:%M:%S') JST・開くだけ）"
cd "$W" && "$NODE_BIN" "$PROBE" 2>&1 | tail -20
# 窓を前に出す（アプリ名は Google Chrome for Testing）
osascript -e 'tell application "Google Chrome for Testing" to activate' >/dev/null 2>&1 && echo "- 窓を前に出した" || echo "- 窓を前に出せなかった（Dock の Chrome for Testing のアイコンを押す）"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t692 / $(basename "$OUT")"
