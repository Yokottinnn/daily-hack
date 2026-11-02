#!/bin/bash
# **お手本のプラチナマップ（https://platinumaps.jp/）のトップとデモマップを開いて撮る（t554）。開いて撮るだけ・押さない・$0。**
# 2026-11-02 利用者「プラチナマップのデモマップみたいなマップにしたい」。クラウドからは 403 で開けない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
D="${OPS_REPORT_DIR:-/tmp}/t554"; mkdir -p "$D"
OUT="${OPS_REPORT_DIR:-/tmp}/t554-platinumaps-look.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.t554-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const D = process.argv[2];
(async () => { const r = { pages: [] }; try {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 }); const p = await b.contexts()[0].newPage();
  const shot = async (name, url, w, h) => { await p.setViewportSize({ width: w, height: h }).catch(() => {});
    await p.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 }).catch((e) => r.pages.push({ name, url, err: String(e.message).slice(0, 120) })); await p.waitForTimeout(9000);
    await p.screenshot({ path: `${D}/${name}.png` }).catch(() => {});
    const info = await p.evaluate(() => ({ url: location.href, title: document.title, text: document.body.innerText.replace(/\s+/g, " ").slice(0, 600),
      links: [...new Set([...document.querySelectorAll("a")].map((a) => `${(a.innerText || "").trim().slice(0, 30)} → ${a.href}`).filter((x) => /デモ|demo|事例|map|マップ|導入/i.test(x)))].slice(0, 25) }));
    r.pages.push({ name, ...info }); return info; };
  const top = await shot("1-top-pc", "https://platinumaps.jp/", 1280, 900);
  const demos = [...new Set(top.links.map((x) => x.split(" → ")[1]).filter((u) => u && !/platinumaps\.jp\/?($|#)/.test(u) && /demo|maps\/|\/d\/|map/i.test(u)))].slice(0, 3);
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
echo "t554 / $(basename "$OUT")"
