#!/bin/bash
# **FUNDS の招待リンクの特典と、公式・App Store の掲載情報を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-05）
#
#   > Fundsの紹介投稿を作成して欲しい／リンクは以下のものを活用して
#   > 値動きがなくて、比較的リスクを抑えた資産運用サービスだよ。まずは特典も使って試してみてね！
#   > https://invy.jp/il/5JY-2gnbaKt8OkYcEi0AdA==   ← 利用者本人の招待リンク
#
# **特典の中身・数字は、招待ページと公式に書いてあるものだけを使う**（最上位ルール 20・推測で書かない）。
#
#   ① 招待リンクを Chrome で開き、行き着いた URL・本文・画面を取る（reports/funds-invite.png）
#   ② FUNDS 公式のトップを開き、本文と画面を取る（reports/funds-top.png）
#   ③ App Store の掲載情報（iTunes Search API）: 名前・評価・件数・版・説明の冒頭・スクショ URL
#      スクショ 4 枚とアイコンを reports/funds-app-*.jpg に保存（告知画像の素材。App Store 掲載素材は出所の行が要らない）
#
# **登録しない。投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/funds-invite-and-official.md"
PROBE="$W/.x251-probe.js"
RAW="$W/.x251-out.json"
INVITE="https://invy.jp/il/5JY-2gnbaKt8OkYcEi0AdA=="
hide() { sed -E "s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g; s#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g"; }

cat > "$PROBE" <<'PROBEJS'
// x251: 招待ページと公式トップを開いて本文を読み、画面を撮る。登録しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [invite, outdir] = process.argv.slice(2);
const grab = async (page, url, shot) => {
  const r = { from: url };
  try {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForTimeout(6000);
    r.url = page.url();
    r.title = await page.title();
    r.text = (await page.evaluate(() => document.body ? document.body.innerText : "")).replace(/\n{3,}/g, "\n\n").slice(0, 3500);
    r.og = await page.evaluate(() => { const m = (p) => { const e = document.querySelector('meta[property="' + p + '"]'); return e ? e.getAttribute("content") : null; };
      return { title: m("og:title"), desc: m("og:description"), image: m("og:image") }; });
    await page.screenshot({ path: outdir + "/" + shot, fullPage: true }).catch(async () => { await page.screenshot({ path: outdir + "/" + shot }); });
    r.shot = shot;
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  return r;
};
(async () => {
  const out = {};
  let b;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 430, height: 1400 });
    out.invite = await grab(page, invite, "funds-invite.png");
    out.top = await grab(page, "https://funds.jp/", "funds-top.png");
    await page.close().catch(() => {});
  } catch (e) { out.fatal = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(out));
  process.exit(0);
})();
PROBEJS

{
echo "# FUNDS の招待ページ・公式・App Store（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/funds-invite.png "$OUTDIR"/funds-top.png "$OUTDIR"/funds-app-*.jpg
cd "$W" && node "$PROBE" "$INVITE" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
for (const [k, name] of [["invite", "① 招待リンク"], ["top", "② 公式トップ"]]) {
  const r = j[k] || {};
  console.log("## " + name + "\n");
  console.log("- 行き着いた URL: " + (r.url || "?") + "\n- タイトル: " + (r.title || "?") + "\n- og: " + JSON.stringify(r.og || {}) + (r.shot ? "\n- 画面: `" + r.shot + "`" : "") + (r.error ? "\n- **エラー: " + r.error + "**" : "") + "\n");
  console.log("```text\n" + (r.text || "（本文が読めない）") + "\n```\n");
}
' "$RAW" 2>&1 | hide
rm -f "$PROBE" "$RAW"

echo "## ③ App Store（iTunes Search API）"
echo
J="$OUTDIR/.funds-itunes.json"
curl -sS -m 25 "https://itunes.apple.com/search?term=FUNDS&country=jp&entity=software&limit=8" -o "$J" 2>&1 | head -3
node -e '
const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const rows = (j.results || []).map((a) => ({ id: a.trackId, name: a.trackName, seller: a.sellerName }));
console.log("候補: " + JSON.stringify(rows) + "\n");
const a = (j.results || []).find((x) => /ファンズ|FUNDS/i.test(x.trackName + x.sellerName) && /ファンズ|Funds/i.test(x.sellerName || ""));
if (!a) { console.log("**FUNDS のアプリが見つからない**"); process.exit(0); }
console.log("```\n" + JSON.stringify({ trackId: a.trackId, name: a.trackName, seller: a.sellerName, rating: a.averageUserRating, ratingCount: a.userRatingCount,
  version: a.version, released: a.currentVersionReleaseDate, price: a.formattedPrice, genre: a.primaryGenreName, url: a.trackViewUrl }, null, 1) + "\n```\n");
console.log("説明（冒頭 1200 字）:\n\n```text\n" + String(a.description || "").slice(0, 1200) + "\n```\n");
require("fs").writeFileSync(process.argv[1] + ".pick", [a.artworkUrl512 || a.artworkUrl100].concat((a.screenshotUrls || []).slice(0, 5)).join("\n") + "\n");
console.log("スクショ " + (a.screenshotUrls || []).length + " 枚（先頭 5 枚を保存）");
' "$J" 2>&1
i=0
if [ -f "$J.pick" ]; then
  while IFS= read -r u || [ -n "$u" ]; do
    [ -n "$u" ] || continue
    if [ "$i" -eq 0 ]; then f="funds-app-icon.jpg"; else f="funds-app-$i.jpg"; fi
    curl -sS -m 25 -L "$u" -o "$OUTDIR/$f" && printf -- '- 保存 %s（%s bytes）\n' "$f" "$(wc -c < "$OUTDIR/$f" | tr -d ' ')"
    i=$((i + 1))
  done < "$J.pick"
fi
rm -f "$J" "$J.pick"
echo
echo "**登録していない。投稿していない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "FUNDS の招待ページ・公式・App Store を読んだ / $(basename "$OUT")"
