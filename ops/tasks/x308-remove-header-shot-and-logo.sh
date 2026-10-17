#!/bin/bash
# **x307 で撮った楽天トップのヘッダー画像に、利用者の氏名と保有ポイントが写っていた。消す。あわせて「Rakuten」ロゴだけを大きく撮る。費用 $0。**
# ① reports/x307-logo/rakuten-top-header.png を消す（公開リポジトリに載るため。履歴からは消えないことを報告に書く）
# ② ログイン情報の写らない要素だけを、拡大して撮る（ロゴの要素そのもの。ページ全体やヘッダー全体は撮らない）
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
RD="${OPS_REPORT_DIR:-/tmp}"
OUT="$RD/remove-header-shot.md"
rm -f "$RD/x307-logo/rakuten-top-header.png" "$RD/x307-logo/rakuten-logo-el.png"
mkdir -p "$RD/x308-logo"
P="$W/.x308.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const DIR = process.argv[2];
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const r = {};
  try {
    await p.setViewportSize({ width: 1400, height: 900 });
    await p.goto("https://www.rakuten.co.jp/", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(3000);
    // ロゴの候補（ヘッダーの左上・リンク先がトップ・中身が svg か img）。**周りは撮らない**
    r.cands = await p.evaluate(() => [...document.querySelectorAll('a')].filter((a) => /^https:\/\/www\.rakuten\.co\.jp\/?$/.test(a.href) && a.querySelector("svg, img")).slice(0, 4).map((a) => {
      const box = a.getBoundingClientRect(); const im = a.querySelector("img");
      return { w: Math.round(box.width), h: Math.round(box.height), x: Math.round(box.left), y: Math.round(box.top), img: im ? im.src : null, svg: !!a.querySelector("svg"), label: a.getAttribute("aria-label") || (im && im.alt) || "" };
    }));
    const c = (r.cands || []).find((x) => x.y < 200 && x.w > 40 && x.w < 400);
    if (c) {
      if (c.img) r.imgSrc = c.img;
      await p.evaluate(() => { document.body.style.zoom = "4"; });
      await p.waitForTimeout(1200);
      const el = await p.evaluateHandle(() => [...document.querySelectorAll('a')].find((a) => /^https:\/\/www\.rakuten\.co\.jp\/?$/.test(a.href) && a.querySelector("svg, img") && a.getBoundingClientRect().top < 800));
      const box = await el.asElement().boundingBox();
      if (box && box.width < 1400) { await el.asElement().screenshot({ path: DIR + "/rakuten-wordmark.png" }); r.shot = { w: Math.round(box.width), h: Math.round(box.height) }; }
    }
  } catch (e) { r.err = String(e.message).slice(0, 120); }
  await p.close();
  console.log(JSON.stringify(r));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 個人情報の写った画像を消し、ロゴだけを撮り直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "- x307-logo の 2 枚を消した: $(ls "$RD/x307-logo" 2>/dev/null | wc -l | tr -d ' ') 枚残り"
echo "- **注意: ops/heartbeat の履歴には残っている**（この経路では履歴は書き換えない）"
echo
echo '```json'
(cd "$W" && node "$P" "$RD/x308-logo" 2>/dev/null | tail -1)
echo '```'
ls -la "$RD/x308-logo" 2>/dev/null | tail -n +2
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$P"
echo "個人情報の写った画像を消し、ロゴを撮り直した / $(basename "$OUT")"
