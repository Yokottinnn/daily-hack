#!/bin/bash
# **x306 の続き。楽天の値段が取れなかった（クーポン額を拾った）ので、結果カードの文字を丸ごと読む。楽天市場のロゴはヘッダーを撮る。押さない。費用 $0。**
# 商品は Amazon・楽天の両方に同じ型番があった 3 つに絞る。値段は 2026-10-17 夜の時点。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/same-item-prices-2.md"
LOGO_DIR="${OPS_REPORT_DIR:-/tmp}/x307-logo"
mkdir -p "$LOGO_DIR"
P="$W/.x307.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const ITEMS = [["ソニー WH-1000XM5", "WH-1000XM5"], ["Anker Power Bank 20000mAh 30W", "Anker Power Bank 20000mAh 30W"], ["パナソニック ナノケア EH-NA0K", "EH-NA0K"]];
const LOGO_DIR = process.argv[2];
const clean = (s) => String(s || "").replace(/\s+/g, " ").slice(0, 420);
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const res = [];
  for (const [name, q] of ITEMS) {
    const r = { name };
    try {
      await p.goto("https://www.amazon.co.jp/s?k=" + encodeURIComponent(q), { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3000);
      r.amazon = (await p.evaluate(() => [...document.querySelectorAll('div[data-component-type="s-search-result"]')].slice(0, 5).map((d) => d.innerText))).map(clean);
    } catch (e) { r.amazonErr = String(e.message).slice(0, 80); }
    try {
      await p.goto("https://search.rakuten.co.jp/search/mall/" + encodeURIComponent(q) + "/", { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3500);
      r.rakuten = (await p.evaluate(() => {
        const cards = [...document.querySelectorAll('.searchresultitem, div[class*="searchresultitem"], div[class*="dui-card"]')];
        return cards.slice(0, 6).map((d) => d.innerText);
      })).map(clean);
    } catch (e) { r.rakutenErr = String(e.message).slice(0, 80); }
    res.push(r);
  }
  const logo = {};
  try {
    await p.setViewportSize({ width: 1400, height: 900 });
    await p.goto("https://www.rakuten.co.jp/", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(3000);
    await p.screenshot({ path: LOGO_DIR + "/rakuten-top-header.png", clip: { x: 0, y: 0, width: 700, height: 160 } });
    logo.header = await p.evaluate(() => { const h = document.querySelector("header") || document.body; return h.innerHTML.slice(0, 1500); });
    const el = await p.$('a[href="https://www.rakuten.co.jp/"] svg, a[href="https://www.rakuten.co.jp/"] img, [class*="logo"] svg, [aria-label*="楽天市場"]');
    if (el) { await el.screenshot({ path: LOGO_DIR + "/rakuten-logo-el.png" }); logo.el = "rakuten-logo-el.png"; }
  } catch (e) { logo.err = String(e.message).slice(0, 80); }
  await p.close();
  console.log(JSON.stringify({ res, logo }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 同じ型番の値段・2 回目（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo '```json'
(cd "$W" && node "$P" "$LOGO_DIR" 2>/dev/null | tail -1) | node -e 'const s=require("fs").readFileSync(0,"utf8");try{console.log(JSON.stringify(JSON.parse(s),null,1))}catch(e){console.log(s.slice(0,800))}'
echo '```'
ls -la "$LOGO_DIR" 2>/dev/null | tail -n +2
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 値段は取得した時刻の表示で、変わる。"
} > "$OUT" 2>&1
rm -f "$P"
echo "同じ型番の値段を読み直した / $(basename "$OUT")"
