#!/bin/bash
# **紅葉の名所の写真を Flickr で探す（CC0 とパブリックドメインだけ）。読むだけ・保存するだけ。費用 $0。**
#
# ## なぜ Flickr か（2026-10-11）
#
#   紅葉 10 選のタイル画像（レビューページのコメントの指示）に、出所の行を出さずに使える写真が要る（最上位ルール 8）。
#   Wikimedia Commons の CC0 / PD では、明治神宮外苑・新宿御苑・清澄庭園・旧芝離宮の**紅葉期の写真が無かった。**
#   Unsplash は x260・x261 とも 0 枚。**ロボット除けの確認画面（.within.website）で止まっていた。**
#   Flickr はライセンスで絞って検索できる（license=9 が CC0、10 がパブリックドメインマーク）。
#
#   ① 名所ごとに Flickr を検索（license=9,10 だけ）、上位 5 枚
#   ② 写真ページを開いて、題名・撮影日・ライセンス表記を読む（**ページの表記で CC0 / Public Domain と出ているものだけ保存**）
#   ③ og:image（大きい画像）を $OPS_REPORT_DIR/x262-<名所>-<n>.jpg に保存
#
# **ログインしない。いいね・フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。** 4 分で打ち切る（最上位ルール 15）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/flickr-momiji-tiles.md"
PROBE="$W/.x262-probe.js"
RAW="$W/.x262-out.json"

cat > "$PROBE" <<'PROBEJS'
// x262: Flickr を CC0 / PD で検索して候補を保存する
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const outdir = process.argv[2];
const Q = [
  ["gaien", "jingu gaien ginkgo"], ["gaien2", "神宮外苑 いちょう並木"],
  ["gyoen", "shinjuku gyoen autumn"], ["kiyosumi", "kiyosumi garden autumn"],
  ["shiba", "shiba rikyu garden"], ["rikugien", "rikugien autumn"],
];
const T0 = Date.now(); const left = () => 240000 - (Date.now() - T0);
const nav = async (page, u) => { try { await page.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 }); } catch (e) { if (!/interrupted|ERR_ABORTED/.test(String(e))) throw e; } await page.waitForLoadState("domcontentloaded").catch(() => {}); };
(async () => {
  const out = { spots: {} };
  let b, ctx;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    ctx = await b.newContext({ viewport: { width: 1280, height: 2000 } });
    const page = await ctx.newPage();
    for (const [key, q] of Q) {
      if (left() < 25000) { out.spots[key] = { q, error: "時間切れで打ち切り" }; continue; }
      const r = { q, items: [] };
      try {
        await nav(page, "https://www.flickr.com/search/?text=" + encodeURIComponent(q) + "&license=9%2C10");
        await page.waitForTimeout(5000);
        r.url = page.url();
        const links = await page.$$eval('a[href*="/photos/"]', (as) => {
          const seen = new Set(), res = [];
          for (const a of as) { const h = a.getAttribute("href") || ""; const m = h.match(/^\/photos\/[^/]+\/\d+\/?$/); if (!m || seen.has(h)) continue; seen.add(h); res.push(h); }
          return res.slice(0, 5);
        });
        r.found = links.length;
        for (const h of links) {
          if (left() < 15000) break;
          const it = { href: "https://www.flickr.com" + h };
          try {
            await nav(page, it.href); await page.waitForTimeout(3000);
            it.title = await page.title();
            const body = await page.evaluate(() => document.body.innerText);
            it.license = (body.match(/(Public Domain Mark[^\n]{0,20}|Public Domain Dedication \(CC0\)|CC0[^\n]{0,30}|Public Domain[^\n]{0,20})/) || [])[1] || "?";
            it.taken = (body.match(/Taken on ([A-Z][a-z]+ \d{1,2}, \d{4})/) || [])[1] || "";
            const og = await page.evaluate(() => (document.querySelector('meta[property="og:image"]') || {}).content || "");
            if (og && /CC0|Public Domain/i.test(it.license)) {
              const res = await ctx.request.get(og, { timeout: 25000 });
              if (res.ok()) { const buf = await res.body(); const f = "x262-" + key + "-" + (r.items.length + 1) + ".jpg"; fs.writeFileSync(outdir + "/" + f, buf); it.file = f; it.bytes = buf.length; }
            }
          } catch (e) { it.error = String(e && e.message).slice(0, 120); }
          r.items.push(it);
        }
      } catch (e) { r.error = String(e && e.message).slice(0, 160); }
      out.spots[key] = r;
    }
  } catch (e) { out.fatal = String(e && e.message).slice(0, 200); }
  try { if (ctx) await ctx.close(); } catch (e) {}
  console.log(JSON.stringify(out));
  process.exit(0);
})();
PROBEJS

{
echo "# 紅葉の名所の写真（Flickr・CC0 とパブリックドメインだけ）（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/x262-*.jpg
cd "$W" && node "$PROBE" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
for (const [k, r] of Object.entries(j.spots)) {
  console.log("## " + k + "（検索: " + r.q + "）\n\n開いた URL: " + (r.url || "?") + " ／ 写真リンク " + (r.found ?? "?") + " 件\n" + (r.error ? "\n**" + r.error + "**\n" : ""));
  console.log("| 画像 | ライセンス | 題名 | 撮影日 | ページ |\n| --- | --- | --- | --- | --- |");
  for (const it of r.items || []) console.log("| " + (it.file || "（保存なし" + (it.error ? "・" + it.error : "") + "）") + " | " + it.license + " | " + String(it.title || "").replace(/\|/g, "／").slice(0, 70) + " | " + it.taken + " | " + it.href + " |");
  console.log("");
}' "$RAW" 2>&1
rm -f "$PROBE" "$RAW"
echo
echo "保存した画像: $(ls "$OUTDIR"/x262-*.jpg 2>/dev/null | wc -l | tr -d ' ') 枚"
echo
echo "**ログインしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "Flickr で紅葉の名所の写真を探した / $(basename "$OUT")"
