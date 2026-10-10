#!/bin/bash
# **東急カードの紹介リンクと紹介キャンペーンのページを読む・撮る。読むだけ。費用 $0。**
#
# ## 指示（2026-10-10）
#
#   > 東急カードの紹介キャンペーンを活用してカードを紹介してほしい
#   > 紹介リンク https://www.topcard.co.jp/entry/tokyu-card/index.html?source=FRIEND_WEB&sid=MgUZJw
#   > キャンペーンサイト https://www.topcard.co.jp/info/campaign/2609introduction/index.html
#   > クリエイティブなど上手く活用して
#
# **特典・条件・期限は、このページに書いてあるものだけを使う**（最上位ルール 20）。
#
#   ① キャンペーンページ: 本文の全文・画像（img の src・alt）の一覧・画面（DSF 2.5）
#   ② 紹介リンク: 行き着いた URL・本文・画面
#   ③ キャンペーンページの主な画像（大きい順に 6 枚）を保存（告知画像の素材）
#
# **申し込まない。投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/tokyu-card-pages.md"
PROBE="$W/.x256-probe.js"
RAW="$W/.x256-out.json"
CAMP="https://www.topcard.co.jp/info/campaign/2609introduction/index.html"
REF="https://www.topcard.co.jp/entry/tokyu-card/index.html?source=FRIEND_WEB&sid=MgUZJw"

cat > "$PROBE" <<'PROBEJS'
// x256: 2 ページを開いて本文・画像一覧を読み、画面を撮る。申し込まない
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [camp, ref, outdir] = process.argv.slice(2);
(async () => {
  const out = {};
  let b, ctx;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    ctx = await b.newContext({ viewport: { width: 430, height: 2400 }, deviceScaleFactor: 2.5 });
    const page = await ctx.newPage();
    for (const [k, url, shot] of [["camp", camp, "tokyu-camp.jpg"], ["ref", ref, "tokyu-ref.jpg"]]) {
      const r = { from: url };
      try {
        await page.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 });
        await page.waitForTimeout(6000);
        for (let y = 0; y <= 9000; y += 700) { await page.evaluate((y) => window.scrollTo(0, y), y); await page.waitForTimeout(250); }
        await page.evaluate(() => window.scrollTo(0, 0)); await page.waitForTimeout(1200);
        r.url = page.url(); r.title = await page.title();
        r.text = (await page.evaluate(() => document.body ? document.body.innerText : "")).replace(/\n{3,}/g, "\n\n").slice(0, 7000);
        r.imgs = await page.$$eval("img", (xs) => xs.map((i) => ({ src: i.currentSrc || i.src, alt: i.alt || "", w: i.naturalWidth, h: i.naturalHeight }))
          .filter((i) => i.w >= 200));
        r.height = await page.evaluate(() => document.documentElement.scrollHeight);
        await page.screenshot({ path: outdir + "/" + shot, type: "jpeg", quality: 85, fullPage: true, clip: { x: 0, y: 0, width: 430, height: Math.min(r.height, 6000) } });
        r.shot = shot;
      } catch (e) { r.error = String(e && e.message).slice(0, 200); }
      out[k] = r;
    }
    // ③ キャンペーンページの大きい画像を保存
    const big = (out.camp.imgs || []).slice().sort((a, b) => b.w * b.h - a.w * a.h).slice(0, 6);
    out.saved = [];
    let n = 0;
    for (const im of big) {
      try {
        const res = await ctx.request.get(im.src, { timeout: 30000 });
        if (!res.ok()) continue;
        const buf = await res.body(); n++;
        const ext = (im.src.match(/\.(png|jpe?g|webp|gif)(\?|$)/i) || [, "img"])[1].toLowerCase();
        const f = "tokyu-img-" + n + "." + ext;
        fs.writeFileSync(outdir + "/" + f, buf);
        out.saved.push({ file: f, bytes: buf.length, w: im.w, h: im.h, alt: im.alt, src: im.src });
      } catch (e) {}
    }
  } catch (e) { out.fatal = String(e && e.message).slice(0, 200); }
  try { if (ctx) await ctx.close(); } catch (e) {}
  console.log(JSON.stringify(out));
  process.exit(0);
})();
PROBEJS

{
echo "# 東急カードの紹介ページとキャンペーン（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/tokyu-*.jpg "$OUTDIR"/tokyu-img-*
cd "$W" && node "$PROBE" "$CAMP" "$REF" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
for (const [k, name] of [["camp", "① キャンペーンページ"], ["ref", "② 紹介リンク"]]) {
  const r = j[k] || {};
  console.log("## " + name + "\n");
  console.log("- 行き着いた URL: " + String(r.url || "?").replace(/(sid=)[^&]+/, "$1<伏せ>") + "\n- タイトル: " + (r.title || "?") + "\n- ページの高さ: " + (r.height || "?") + (r.shot ? "\n- 画面: `" + r.shot + "`" : "") + (r.error ? "\n- **エラー: " + r.error + "**" : "") + "\n");
  console.log("画像（幅 200 以上）:\n");
  for (const i of (r.imgs || []).slice(0, 30)) console.log("- " + i.w + "x" + i.h + "  alt「" + i.alt + "」  " + i.src);
  console.log("\n```text\n" + (r.text || "（本文が読めない）") + "\n```\n");
}
console.log("## ③ 保存した画像\n");
for (const s of j.saved || []) console.log("- `" + s.file + "` " + s.w + "x" + s.h + " " + s.bytes + " bytes  alt「" + s.alt + "」");
' "$RAW" 2>&1
rm -f "$PROBE" "$RAW"
echo
echo "**申し込んでいない。投稿していない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "東急カードのページを読んだ / $(basename "$OUT")"
