#!/bin/bash
# **投稿の仕組みが 10/28 ごろから X に出せていない原因を調べる（x367）。押さない・$0。**
# 利用者が「投稿の仕組みの原因を調べる」を選んだ（2026-10-29）。
# ① post-via-playwright.js の「押す」ところの書き方を読む ② 投稿画面に試しの文字と画像 1 枚を入れたところで止め、ボタンの状態と画面を撮る（**押さない・閉じるだけ**）
set -uo pipefail
W="$HOME/.openclaw/workspace"
D="${OPS_REPORT_DIR:-/tmp}/x367"; mkdir -p "$D"
OUT="${OPS_REPORT_DIR:-/tmp}/x367-compose-dry-run.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMG="$W/data/x-cinema-toyosu/1-cover.jpg"
PROBE="$W/.x367-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const [D, IMG] = process.argv.slice(2);
(async () => { const r = {}; let p; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); p = await b.contexts()[0].newPage();
  await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
  await p.goto("https://x.com/compose/post", { waitUntil: "domcontentloaded", timeout: 40000 }); await p.waitForTimeout(6000);
  const ta = await p.$('[data-testid="tweetTextarea_0"]'); r.textarea = !!ta;
  if (ta) { await ta.click(); await p.keyboard.type("てすと（送らない）", { delay: 40 }); }
  await p.waitForTimeout(1500);
  const fi = await p.$('input[type="file"][data-testid="fileInput"]') || await p.$('input[type="file"]'); r.fileInput = !!fi;
  if (fi && IMG) { await fi.setInputFiles(IMG).catch((e) => { r.fileErr = String(e.message).slice(0, 120); }); await p.waitForTimeout(6000); }
  r.attached = await p.$$eval('[data-testid="attachments"] img, [data-testid="attachments"] [role="img"]', (x) => x.length).catch(() => -1);
  r.buttons = await p.$$eval('[data-testid="tweetButton"],[data-testid="tweetButtonInline"],button', (bs) => bs.filter((b) => /ポスト|Post|tweetButton/.test((b.innerText || "") + (b.getAttribute("data-testid") || ""))).map((b) => ({ testid: b.getAttribute("data-testid"), text: b.innerText.trim().slice(0, 20), disabled: b.disabled || b.getAttribute("aria-disabled") === "true" })));
  r.alerts = await p.$$eval('[role="alert"],[data-testid="toast"]', (a) => a.map((x) => x.innerText.slice(0, 200)));
  await p.screenshot({ path: `${D}/1-composed.png` }).catch(() => {});
} catch (e) { r.error = String(e && e.message).slice(0, 200); }
  try { await p.close({ runBeforeUnload: false }); } catch {}
  console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# 投稿画面の空試し（$(date '+%Y-%m-%d %H:%M:%S') JST・押さない・\$0）"
echo; echo "## post-via-playwright.js の押すところ"; echo '```'
grep -nE 'tweetButton|click\(|waitForResponse|CreateTweet|fallback-scrape|keyboard\.press' "$W/scripts/post-via-playwright.js" 2>/dev/null | head -30 | cut -c1-200
echo '```'
echo; echo "## 空試し（文字と画像 1 枚を入れて、押さずに閉じる）"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$D" "$IMG" 2>&1 | tail -40
echo '```'
echo "画像: reports/x367/1-composed.png"
echo "**押していない・閉じただけ（\$0）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x367 / $(basename "$OUT")"
