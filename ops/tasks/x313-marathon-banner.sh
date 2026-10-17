#!/bin/bash
# **お買い物マラソンのキャンペーン画像を、背景画像（CSS）と <picture> まで含めて探して取る。費用 $0。**
# x312 では og:image が楽天のロゴで、ページ上部のバナーが取れなかった。画面は撮らない。押さない。
set -uo pipefail
W="$HOME/.openclaw/workspace"
RD="${OPS_REPORT_DIR:-/tmp}"; D="$RD/x313-marathon"; mkdir -p "$D"
OUT="$RD/marathon-banner.md"
P="$W/.x313.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  await p.setViewportSize({ width: 1400, height: 1000 });
  await p.goto("https://event.rakuten.co.jp/campaign/point-up/marathon/", { waitUntil: "domcontentloaded", timeout: 30000 });
  await p.waitForTimeout(4000);
  const r = await p.evaluate(() => {
    const out = [];
    for (const el of document.querySelectorAll("*")) {
      const box = el.getBoundingClientRect();
      if (box.top > 1600 || box.width < 400 || box.height < 120) continue;
      const bg = getComputedStyle(el).backgroundImage;
      if (bg && bg.startsWith("url(")) out.push({ kind: "bg", src: bg.slice(5, -2), w: Math.round(box.width), h: Math.round(box.height), top: Math.round(box.top) });
      if (el.tagName === "IMG" && (el.currentSrc || el.src)) out.push({ kind: "img", src: el.currentSrc || el.src, w: Math.round(box.width), h: Math.round(box.height), top: Math.round(box.top), alt: (el.alt || "").slice(0, 60) });
      if (el.tagName === "SOURCE" && el.srcset) out.push({ kind: "source", src: el.srcset.split(",")[0].trim().split(" ")[0], top: Math.round(box.top) });
    }
    return out.filter((x) => /^https?:/.test(x.src) && !/tshop\.r10s\.jp/.test(x.src)).slice(0, 12);
  });
  await p.close();
  console.log(JSON.stringify(r));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify([{ err: String(e.message).slice(0, 200) }])); process.exit(0); });
JS
{
echo "# お買い物マラソンのバナー（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・画面は撮っていない）"
J="$(cd "$W" && node "$P" 2>/dev/null | tail -1)"
echo '```json'; echo "$J" | node -e 'console.log(JSON.stringify(JSON.parse(require("fs").readFileSync(0,"utf8")),null,1))' 2>&1 | head -90; echo '```'
echo "$J" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8")).forEach((x,i)=>x.src&&console.log("m"+i+"\t"+x.src))' > "$D/urls.tsv" 2>/dev/null
while IFS=$'\t' read -r name url || [ -n "$name" ]; do
  [ -n "$url" ] || continue
  ext="$(printf '%s' "$url" | sed -E 's/[?#].*//; s/.*\.(jpg|jpeg|png|webp|gif|svg).*/\1/i')"; case "$ext" in jpg|jpeg|png|webp|gif|svg|JPG|PNG) ;; *) ext=jpg;; esac
  curl -s -L --max-time 20 -A "Mozilla/5.0" -o "$D/$name.$ext" "$url"
  echo "- $name.$ext（$(wc -c < "$D/$name.$ext" 2>/dev/null | tr -d ' ') bytes）← $url"
done < "$D/urls.tsv"
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$P"
echo "お買い物マラソンのバナーを探した / $(basename "$OUT")"
