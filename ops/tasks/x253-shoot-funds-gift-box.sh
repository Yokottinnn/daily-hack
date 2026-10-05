#!/bin/bash
# **FUNDS の招待ページの「2,000円プレゼント」の箱を、追従する帯が重ならないように撮る。読むだけ。費用 $0。**
#
# x252 では画面の高さ 1000px で撮ったため、画面下に固定される帯（「紹介を受けた方限定2000円プレゼント」）が
# 2,000円の箱の上に重なった。**画面の高さを 2400px にして**撮り直す（帯は画面の下端＝箱より下に来る）。
#
# **登録しない。投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/shoot-funds-gift-box.md"
PROBE="$W/.x253-probe.js"
INVITE="https://invy.jp/il/5JY-2gnbaKt8OkYcEi0AdA=="

cat > "$PROBE" <<'PROBEJS'
// x253: 招待ページを縦長の画面で撮る。登録しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [invite, outdir] = process.argv.slice(2);
(async () => {
  const out = {};
  let b, ctx;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    // 既存のコンテキストでは deviceScaleFactor を変えられないので、新しいコンテキストを作る（cookie は不要なページ）
    ctx = await b.newContext({ viewport: { width: 430, height: 2400 }, deviceScaleFactor: 2.5 });
    const page = await ctx.newPage();
    for (const [k, url, file] of [["invite", invite, "funds-hi-invite2.jpg"]]) {
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
echo "# FUNDS の招待ページ（縦長の画面）（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo '```'
rm -f "$OUTDIR"/funds-hi-invite2.jpg
cd "$W" && node "$PROBE" "$INVITE" "$OUTDIR" 2>&1 | tail -1 | sed -E 's#(code=|k=|name=|rid=)[^&"]+#\1<伏せ>#g'
for f in "$OUTDIR"/funds-hi-invite2.jpg; do [ -s "$f" ] && printf '  %s %s bytes\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
echo '```'
echo
echo "**登録していない。投稿していない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "FUNDS の招待ページを撮り直した / $(basename "$OUT")"
