#!/bin/bash
# **プラチナマップのデモ欄（#demo）と、そこから開くデモマップを撮る（t555）。開いて撮るだけ・押さない・$0。**
# t554 はトップとニュースしか撮れなかった（デモのリンクを拾えていなかった）。
# 2026-11-02 利用者「プラチナマップのデモマップみたいなマップにしたい」。クラウドからは 403 で開けない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
D="${OPS_REPORT_DIR:-/tmp}/t555"; mkdir -p "$D"
OUT="${OPS_REPORT_DIR:-/tmp}/t555-platinumaps-look.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t555-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const D = process.argv[2];
(async () => { const r = { pages: [] }; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  const shot = async (name, url, w, h) => { await p.setViewportSize({ width: w, height: h }).catch(() => {});
    await p.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 }).catch((e) => r.pages.push({ name, url, err: String(e.message).slice(0, 120) })); await p.waitForTimeout(12000);
    await p.screenshot({ path: `${D}/${name}.png` }).catch(() => {});
    const info = await p.evaluate(() => ({ url: location.href, title: document.title, text: document.body.innerText.replace(/\s+/g, " ").slice(0, 600),
      links: [...new Set([...document.querySelectorAll("a")].map((a) => `${(a.innerText || "").trim().slice(0, 30)} → ${a.href}`).filter((x) => /デモ|demo|事例|map|マップ|導入/i.test(x)))].slice(0, 25) }));
    r.pages.push({ name, ...info }); return info; };
  await p.setViewportSize({ width: 1280, height: 900 }).catch(() => {});
  await p.goto("https://platinumaps.jp/#demo", { waitUntil: "domcontentloaded", timeout: 40000 }).catch(() => {}); await p.waitForTimeout(6000);
  const sec = await p.evaluate(() => { const el = document.querySelector("#demo") || [...document.querySelectorAll("section,div")].find((e) => /デモ/.test((e.querySelector("h2,h3") || {}).innerText || ""));
    if (el) el.scrollIntoView(); const root = el || document.body;
    return { found: !!el, text: root.innerText.replace(/\s+/g, " ").slice(0, 800), links: [...new Set([...root.querySelectorAll("a,iframe")].map((a) => a.href || a.src).filter(Boolean))].slice(0, 30) }; });
  await p.waitForTimeout(2500); await p.screenshot({ path: `${D}/1-demo-section.png` }).catch(() => {});
  r.section = sec;
  const demos = sec.links.filter((u) => !/platinumaps\.jp\/?(#.*)?$|news|getintouch|policies|twitter|facebook|github/.test(u)).slice(0, 2);
  r.demos = demos;
  let i = 2; for (const u of demos) { await shot(`${i}-demo-pc`, u, 1280, 900); await shot(`${i}-demo-sp`, u, 390, 844); i++; }
  await p.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r, null, 1)); process.exit(0); })();
PJS
{
echo "# プラチナマップを撮る（$(date '+%Y-%m-%d %H:%M:%S') JST・押さない・\$0）"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$D" 2>&1 | tail -120
echo '```'
ls -la "$D"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "t555 / $(basename "$OUT")"
