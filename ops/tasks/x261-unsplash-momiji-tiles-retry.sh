#!/bin/bash
# **紅葉の名所の写真を Unsplash で探して、候補を持ち帰る（x260 の出し直し）。読むだけ・保存するだけ。費用 $0。**
#
# ## x260 が 0 枚だった理由（2026-10-11 21:20）
#
#   Unsplash が `/s/photos/…` を日本語版 `/ja/s/写真/…` へ転送し、goto と $$eval が途中で切れた。
#   → **最初から `/ja/s/写真/<語>` を開き、URL が落ち着くまで待つ。** 写真ページのリンクも `/ja/photos/` を拾う
#
# ## 指示（2026-10-11・レビューページのコメント）
#
#   > 1枚目と2枚目の画像の間に、東京の紅葉10選の中から高尾山以外の9枚を選んでタイル型で並べて正方形の画像にして
#   > その際に、各場所がどこかというのをちゃんとそれぞれのタイルに記載してわかるようにして
#
# **X の告知画像には出所の行を出さない**（最上位ルール 8）。だから使える写真は「表記が要らないもの」だけ。
# Wikimedia Commons の CC0 / パブリックドメインでは、次の 4 か所の**紅葉期の写真が見つからなかった**（2026-10-11 にクラウドで検索）。
#
#   明治神宮外苑（いちょう並木）／新宿御苑／清澄庭園／旧芝離宮恩賜庭園
#
# Unsplash の無料写真（Unsplash License）は**帰属表記が要らない**。クラウドからは「Authorization required」で
# 検索できないので、Mac のブラウザで検索して候補を持ち帰る（最上位ルール 20 ①）。
#
#   ① 名所ごとに Unsplash を検索（**license=free だけ**。Unsplash+ は除く）、上位 4 枚
#   ② それぞれの写真ページを開いて、題名・場所・撮影者・ライセンス表記を読む
#   ③ 1200px の画像を $OPS_REPORT_DIR/x261-<名所>-<n>.jpg に保存
#
# **ダウンロードボタンは押さない。ログインしない。いいね・フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
# 1 タスク 5 分以内（最上位ルール 15）。検索 6 本 × 4 枚。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/unsplash-momiji-tiles-2.md"
PROBE="$W/.x261-probe.js"
RAW="$W/.x261-out.json"

cat > "$PROBE" <<'PROBEJS'
// x261: Unsplash を検索して候補を保存する。ダウンロードボタンは押さない
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const outdir = process.argv[2];
const Q = [
  ["gaien", "jingu gaien ginkgo"],
  ["gaien2", "ginkgo avenue tokyo"],
  ["gyoen", "shinjuku gyoen autumn"],
  ["kiyosumi", "kiyosumi garden"],
  ["shiba", "kyu shiba rikyu garden"],
  ["rikugien", "rikugien autumn"],
];
const T0 = Date.now(); const left = () => 240000 - (Date.now() - T0);
(async () => {
  const out = { spots: {} };
  let b, ctx;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    ctx = await b.newContext({ viewport: { width: 1280, height: 2000 } });
    const page = await ctx.newPage();
    for (const [key, q] of Q) {
      if (left() < 20000) { out.spots[key] = { q, error: "時間切れで打ち切り" }; continue; }
      const r = { q, items: [] };
      try {
        const su = "https://unsplash.com/ja/s/" + encodeURIComponent("写真") + "/" + encodeURIComponent(q.replace(/ /g, "-")) + "?license=free";
        try { await page.goto(su, { waitUntil: "domcontentloaded", timeout: 30000 }); } catch (e) { if (!/interrupted/.test(String(e))) throw e; }
        await page.waitForLoadState("domcontentloaded").catch(() => {});
        await page.waitForTimeout(5000);
        r.url = page.url();
        const cands = await page.$$eval('a[href*="/photos/"]', (as) => {
          const seen = new Set(); const res = [];
          for (const a of as) {
            const img = a.querySelector("img"); if (!img) continue;
            const href = a.getAttribute("href"); if (seen.has(href)) continue; seen.add(href);
            const plus = !!a.closest("figure")?.innerText?.includes("Unsplash+");
            res.push({ href, alt: img.alt || "", src: img.currentSrc || img.src, plus });
          }
          return res.slice(0, 12);
        });
        for (const c of cands.filter((c) => !c.plus).slice(0, 4)) {
          if (left() < 15000) break;
          const it = { href: c.href.startsWith("http") ? c.href : "https://unsplash.com" + c.href, alt: c.alt };
          try {
            try { await page.goto(it.href, { waitUntil: "domcontentloaded", timeout: 25000 }); } catch (e) { if (!/interrupted/.test(String(e))) throw e; }
            await page.waitForLoadState("domcontentloaded").catch(() => {});
            await page.waitForTimeout(3000);
            it.title = await page.title();
            const body = await page.evaluate(() => document.body.innerText);
            it.license = (body.match(/(Free to use under the Unsplash License|Unsplash\+ License|Unsplash License|Unsplash ?ライセンス[^\n]{0,30})/) || [])[1] || "?";
            it.plus = /Unsplash\+/.test(body.slice(0, 3000)) && !/(Free to use under the Unsplash License|Unsplash ?ライセンス)/.test(body);
            it.location = await page.evaluate(() => { const a = [...document.querySelectorAll('a[href*="/s/photos/"]')].map((x) => x.innerText.trim()).filter(Boolean); return a.slice(0, 6).join(" / "); });
            it.published = ((body.match(/Published (on )?([A-Z][a-z]+ \d{1,2}, \d{4})/) || [])[2]) || ((body.match(/(\d{4}年\d{1,2}月\d{1,2}日)に公開/) || [])[1]) || "";
            const big = await page.evaluate(() => { const i = [...document.images].filter((x) => /images\.unsplash\.com\/photo-/.test(x.currentSrc || x.src)).sort((a, b) => b.naturalWidth - a.naturalWidth)[0]; return i ? (i.currentSrc || i.src) : null; });
            const u = (big || c.src || "").replace(/([?&])w=\d+/, "$1w=1200").replace(/([?&])q=\d+/, "$1q=80");
            if (u && !it.plus) {
              const res = await ctx.request.get(u, { timeout: 25000 });
              if (res.ok()) { const f = "x261-" + key + "-" + (r.items.length + 1) + ".jpg"; fs.writeFileSync(outdir + "/" + f, await res.body()); it.file = f; it.bytes = (await res.body()).length; }
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
echo "# 紅葉の名所の写真（Unsplash・無料ライセンスだけ）（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/x261-*.jpg
cd "$W" && node "$PROBE" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
for (const [k, r] of Object.entries(j.spots)) {
  console.log("## " + k + "（検索: " + r.q + "）\n\n開いた URL: " + (r.url || "?") + "\n" + (r.error ? "\n**" + r.error + "**\n" : ""));
  console.log("| 画像 | ライセンス | 題名 | タグ・場所 | 公開日 | ページ |\n| --- | --- | --- | --- | --- | --- |");
  for (const it of r.items || []) console.log("| " + (it.file || "（保存なし" + (it.error ? "・" + it.error : "") + "）") + " | " + (it.plus ? "**Unsplash+（使わない）**" : it.license) + " | " + String(it.title || it.alt || "").replace(/\|/g, "／").slice(0, 70) + " | " + String(it.location || "").replace(/\|/g, "／").slice(0, 80) + " | " + (it.published || "") + " | " + it.href + " |");
  console.log("");
}' "$RAW" 2>&1
rm -f "$PROBE" "$RAW"
echo
echo "保存した画像: $(ls "$OUTDIR"/x261-*.jpg 2>/dev/null | wc -l | tr -d ' ') 枚"
echo
echo "**ダウンロードボタンは押していない。ログインしていない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "Unsplash で紅葉の名所の写真を探した / $(basename "$OUT")"
