#!/bin/bash
# **同じ型番の商品を Amazon と楽天市場で検索し、値段とポイントの表示を読む。楽天市場の日本版ロゴを公式から取る。何も押さない。費用 $0。**
# 利用者（2026-10-17・レビューページ）: 「楽天とAmazonでまったく同じもの…を買ったときにどれくらい差が出るのか比較した画像を」
#   「楽天市場ね 漢字が違うので直して」（いまのロゴは台湾版の「樂天市場」だった）
# 商品は型番で同じ物だと分かるものに絞る。**どの出品を拾ったかは題名ごと出す**（違う物なら使わない）。値段は 2026-10-17 夜の時点。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/same-item-prices.md"
LOGO_DIR="${OPS_REPORT_DIR:-/tmp}/x306-logo"
mkdir -p "$LOGO_DIR"
P="$W/.x306.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const fs = require("fs");
const ITEMS = ["EH-NA0J", "SV46 SU", "A1384", "WH-1000XM5", "MIIM-01"];
const LOGO_DIR = process.argv[2];
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const res = [];
  for (const q of ITEMS) {
    const r = { q };
    try {
      await p.goto("https://www.amazon.co.jp/s?k=" + encodeURIComponent(q), { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3000);
      r.amazon = await p.evaluate(() => [...document.querySelectorAll('div[data-component-type="s-search-result"]')].slice(0, 4).map((d) => ({
        title: ((d.querySelector("h2") || {}).innerText || "").slice(0, 90),
        price: ((d.querySelector(".a-price .a-offscreen") || {}).textContent || ""),
        point: (d.innerText.match(/[\d,]+\s*pt|[\d,]+ポイント[^\n]{0,12}/) || [""])[0],
        sponsored: /スポンサー/.test(d.innerText) })));
    } catch (e) { r.amazonErr = String(e.message).slice(0, 80); }
    try {
      await p.goto("https://search.rakuten.co.jp/search/mall/" + encodeURIComponent(q) + "/", { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3000);
      r.rakuten = await p.evaluate(() => [...document.querySelectorAll('.searchresultitem, [data-testid="item-card"], div[class*="searchresultitem"]')].slice(0, 5).map((d) => ({
        title: ((d.querySelector("h2, .title, a[title]") || {}).innerText || "").slice(0, 90),
        price: (d.innerText.match(/[\d,]+円/) || [""])[0],
        point: (d.innerText.match(/[\d,]+ポイント[^\n]{0,14}|[\d]+倍/) || [""])[0],
        ship: /送料無料/.test(d.innerText) ? "送料無料" : "" })));
    } catch (e) { r.rakutenErr = String(e.message).slice(0, 80); }
    res.push(r);
  }
  // 楽天市場の日本版ロゴ（公式トップのヘッダー）
  const logo = {};
  try {
    await p.goto("https://www.rakuten.co.jp/", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(2500);
    logo.cands = await p.evaluate(() => [...document.querySelectorAll('img, svg, link[rel*="icon"], meta[property="og:image"]')]
      .map((x) => ({ tag: x.tagName, src: x.getAttribute("src") || x.getAttribute("href") || x.getAttribute("content") || "", alt: x.getAttribute("alt") || x.getAttribute("aria-label") || "", cls: String(x.getAttribute("class") || "").slice(0, 40) }))
      .filter((x) => /logo|楽天市場|rakuten/i.test(x.src + x.alt + x.cls)).slice(0, 12));
    const el = await p.$('header [class*="logo"] img, header a[href="https://www.rakuten.co.jp/"] img, img[alt*="楽天市場"]');
    if (el) { await el.screenshot({ path: LOGO_DIR + "/rakuten-header-logo.png" }); logo.shot = "rakuten-header-logo.png"; }
  } catch (e) { logo.err = String(e.message).slice(0, 80); }
  await p.close();
  console.log(JSON.stringify({ res, logo }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 同じ型番の値段（Amazon / 楽天市場）と楽天市場のロゴ（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
echo '```json'
(cd "$W" && node "$P" "$LOGO_DIR" 2>/dev/null | tail -1) | node -e 'const s=require("fs").readFileSync(0,"utf8");try{console.log(JSON.stringify(JSON.parse(s),null,1))}catch(e){console.log(s.slice(0,800))}'
echo '```'
ls -la "$LOGO_DIR" 2>/dev/null | tail -n +2
echo
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。** 値段は取得した時刻の表示で、変わる。"
} > "$OUT" 2>&1
rm -f "$P"
echo "同じ型番の値段と楽天市場のロゴを読んだ / $(basename "$OUT")"
