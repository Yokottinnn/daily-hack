#!/bin/bash
# **FUNDS の招待ページと公式トップを高解像度で撮る（告知画像の素材）。読むだけ。費用 $0。**
#
# x251 の画面は横 430px（deviceScaleFactor 1）で、1080 の画像にすると粗い。
# 同じ幅のレイアウトのまま **deviceScaleFactor 2.5（横 1075px）** で撮り直す。
#
#   ① 招待ページ（利用者本人のリンク）の上から 2,000px（特典の箱・運用例のグラフまで）→ funds-hi-invite.jpg
#   ② 公式トップの上から 2,000px（「堅実イチバン。」・最新のファンドのカードまで）→ funds-hi-top.jpg
#
# **登録しない。投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/shoot-funds-hires.md"
PROBE="$W/.x252-probe.js"
INVITE="https://invy.jp/il/5JY-2gnbaKt8OkYcEi0AdA=="

cat > "$PROBE" <<'PROBEJS'
// x252: 2 ページを高解像度で撮る。登録しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [invite, outdir] = process.argv.slice(2);
(async () => {
  const out = {};
  let b, ctx;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    // 既存のコンテキストでは deviceScaleFactor を変えられないので、新しいコンテキストを作る（cookie は不要なページ）
    ctx = await b.newContext({ viewport: { width: 430, height: 1000 }, deviceScaleFactor: 2.5 });
    const page = await ctx.newPage();
    for (const [k, url, file] of [["invite", invite, "funds-hi-invite.jpg"], ["top", "https://funds.jp/", "funds-hi-top.jpg"]]) {
      try {
        await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
        await page.waitForTimeout(7000);
        // 遅延読み込みの画像を出すため、下まで一度スクロールして戻る
        for (let y = 0; y <= 2200; y += 500) { await page.evaluate((y) => window.scrollTo(0, y), y); await page.waitForTimeout(400); }
        await page.evaluate(() => window.scrollTo(0, 0)); await page.waitForTimeout(1200);
        await page.screenshot({ path: outdir + "/" + file, type: "jpeg", quality: 88, fullPage: true, clip: { x: 0, y: 0, width: 430, height: 2000 } });
        out[k] = { url: page.url(), file };
      } catch (e) { out[k] = { error: String(e && e.message).slice(0, 200) }; }
    }
  } catch (e) { out.fatal = String(e && e.message).slice(0, 200); }
  try { if (ctx) await ctx.close(); } catch (e) {}
  console.log(JSON.stringify(out));
  process.exit(0);
})();
PROBEJS

{
echo "# FUNDS の高解像度の画面（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo '```'
rm -f "$OUTDIR"/funds-hi-*.jpg
cd "$W" && node "$PROBE" "$INVITE" "$OUTDIR" 2>&1 | tail -1 | sed -E 's#(code=|k=|name=|rid=)[^&"]+#\1<伏せ>#g'
for f in "$OUTDIR"/funds-hi-*.jpg; do [ -s "$f" ] && printf '  %s %s bytes\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
echo
echo "**登録していない。投稿していない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "FUNDS の画面を高解像度で撮った / $(basename "$OUT")"
