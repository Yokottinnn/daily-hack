#!/bin/bash
# **プライム感謝祭とお買い物マラソンの公式キャンペーン画像を取る。費用 $0。**
# 利用者（2026-10-17・レビューページ）: 「このタブのところに薄くプライム感謝祭のキャンペーン画像を透過させて写して／楽天のお買い物マラソンも同じように」
# 各公式ページの og:image と、大きい画像（幅 600 以上）の URL を読み、画像そのものをダウンロードする。
# **画面は撮らない**（x307 でログイン中の氏名が写った）。押さない。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
RD="${OPS_REPORT_DIR:-/tmp}"; D="$RD/x312-banners"; mkdir -p "$D"
OUT="$RD/campaign-banners.md"
P="$W/.x312.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const PAGES = [
  ["amazon-about", "https://www.aboutamazon.jp/news/amazon-prime/prime-appreciation-sale-2026"],
  ["amazon-event", "https://www.amazon.co.jp/events/pointupcampaign/"],
  ["amazon-sale", "https://www.amazon.co.jp/primebigdealdays"],
  ["rakuten-marathon", "https://event.rakuten.co.jp/campaign/point-up/marathon/"],
];
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const out = [];
  for (const [k, u] of PAGES) {
    try {
      await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForTimeout(3500);
      const r = await p.evaluate(() => {
        const og = (document.querySelector('meta[property="og:image"]') || {}).content || null;
        const imgs = [...document.querySelectorAll("img")].map((i) => ({ src: i.currentSrc || i.src, w: i.naturalWidth, h: i.naturalHeight, alt: (i.alt || "").slice(0, 60) }))
          .filter((i) => i.src && /^https?:/.test(i.src) && i.w >= 600 && i.h >= 150).sort((a, b) => b.w * b.h - a.w * a.h).slice(0, 4);
        return { title: document.title.slice(0, 80), og, imgs };
      });
      out.push({ k, u, ...r });
    } catch (e) { out.push({ k, u, err: String(e.message).slice(0, 100) }); }
  }
  await p.close();
  console.log(JSON.stringify(out));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify([{ err: String(e.message).slice(0, 200) }])); process.exit(0); });
JS
{
echo "# キャンペーン画像（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・画面は撮っていない）"
echo '```json'
J="$(cd "$W" && node "$P" 2>/dev/null | tail -1)"
echo "$J" | node -e 'console.log(JSON.stringify(JSON.parse(require("fs").readFileSync(0,"utf8")),null,1))' 2>&1 | head -80
echo '```'
echo "$J" | node -e '
const j=JSON.parse(require("fs").readFileSync(0,"utf8"));
for(const r of j){ if(!r.k) continue; const us=[r.og,...(r.imgs||[]).map(i=>i.src)].filter(Boolean).slice(0,3); us.forEach((u,i)=>console.log(r.k+"-"+i+"\t"+u)); }' > "$D/urls.tsv" 2>/dev/null
while IFS=$'\t' read -r name url || [ -n "$name" ]; do
  [ -n "$url" ] || continue
  ext="$(printf '%s' "$url" | sed -E 's/[?#].*//; s/.*\.(jpg|jpeg|png|webp|gif).*/\1/i')"; case "$ext" in jpg|jpeg|png|webp|gif|JPG|PNG) ;; *) ext=jpg;; esac
  curl -s -L --max-time 20 -A "Mozilla/5.0" -o "$D/$name.$ext" "$url"
  echo "- $name.$ext（$(wc -c < "$D/$name.$ext" 2>/dev/null | tr -d ' ') bytes）← $url"
done < "$D/urls.tsv"
echo
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$P"
echo "キャンペーン画像を取った / $(basename "$OUT")"
