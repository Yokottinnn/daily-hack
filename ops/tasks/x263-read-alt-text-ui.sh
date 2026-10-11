#!/bin/bash
# **X の投稿画面で、画像に説明（ALT）を付ける欄の実物を読む。投稿しない。費用 $0。**
#
# ## なぜ（2026-10-11）
#
#   紅葉の告知（承認済み）の 2 枚目は記事の CC BY / CC BY-SA の写真で組んだ。利用者の指示で、
#   **撮影者名とライセンスは X の画像の説明（ALT）に書く**（CLAUDE.md 最上位ルール 8）。
#   ところが投稿経路（run-publish.sh → post-via-playwright.js）には **ALT を付ける処理が無い。**
#   推測で書き足すと「ALT 無しで出る＝ライセンス違反」になりうるので、**先に実物を読む**（最上位ルール 20）。
#
#   ① post-via-playwright.js の全文（画像を付けている箇所・投稿ボタンを押す箇所）
#   ② 投稿画面を開き、**画像を 1 枚 添付するだけ**。添付の周りのボタン（aria-label / data-testid）を全部出す
#   ③ 「説明」「ALT」「編集」らしいボタンを押し、開いた欄（textarea / input）と保存ボタンを全部出す。画面を撮る
#   ④ **閉じて、下書きは破棄する。投稿ボタン（tweetButton）は一度も触らない**
#
# **投稿しない。LLM を呼ばない（$0／回・$0／日・$0／月）。** 2 分で終わる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/alt-text-ui.md"
PROBE="$W/.x263-probe.js"
RAW="$W/.x263-out.json"
IMG="$W/.x263-test.jpg"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

git -C "$REPO" show "origin/main:public/images/momiji-2026-kanto/x/2-takao.jpg" > "$IMG" 2>/dev/null

cat > "$PROBE" <<'PROBEJS'
// x263: 投稿画面で画像を 1 枚 添付し、ALT の欄を読む。投稿ボタンは触らない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [img, outdir] = process.argv.slice(2);
const dump = (page, scope) => page.$$eval(scope + " button, " + scope + " [role=button], " + scope + " a, " + scope + " textarea, " + scope + " input", (xs) =>
  xs.map((x) => ({ tag: x.tagName.toLowerCase(), testid: x.getAttribute("data-testid"), aria: x.getAttribute("aria-label"), name: x.getAttribute("name"),
    placeholder: x.getAttribute("placeholder"), type: x.getAttribute("type"), text: (x.innerText || "").trim().slice(0, 40), maxlength: x.getAttribute("maxlength") }))
    .filter((x) => x.testid || x.aria || x.text || x.name || x.placeholder).slice(0, 80));
(async () => {
  const r = { steps: [] };
  let page;
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 1280, height: 1100 });
    await page.goto("https://x.com/compose/post", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('[data-testid="tweetTextarea_0"]', { timeout: 20000 });
    await page.waitForTimeout(2000);
    const fi = await page.$('input[data-testid="fileInput"]') || await page.$('input[type="file"]');
    r.fileInput = !!fi;
    if (!fi) throw new Error("fileInput が無い");
    await fi.setInputFiles(img);
    await page.waitForSelector('[data-testid="attachments"]', { timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(4000);
    await page.screenshot({ path: outdir + "/x263-1-attached.png" });
    r.attachments = await dump(page, '[data-testid="attachments"]');
    r.dialogAfterAttach = await dump(page, '[role="dialog"]');
    // 「説明」「ALT」「編集」らしいものを押す（投稿ボタンは除外）
    const cand = await page.$$('[data-testid="attachments"] button, [data-testid="attachments"] [role=button], [data-testid="attachments"] a');
    let clicked = null;
    for (const c of cand) {
      const t = ((await c.getAttribute("aria-label")) || "") + " " + ((await c.innerText().catch(() => "")) || "") + " " + ((await c.getAttribute("data-testid")) || "");
      if (/tweetButton/i.test(t)) continue;
      if (/説明|ALT|alt|description|編集|Edit|altText/i.test(t) && !/削除|Remove/i.test(t)) { await c.click(); clicked = t.trim(); break; }
    }
    r.clicked = clicked;
    await page.waitForTimeout(3000);
    await page.screenshot({ path: outdir + "/x263-2-alt.png" });
    r.dialogAfterClick = await dump(page, '[role="dialog"]');
    r.textareas = await page.$$eval("textarea, input[type=text]", (xs) => xs.map((x) => ({ testid: x.getAttribute("data-testid"), name: x.getAttribute("name"), aria: x.getAttribute("aria-label"), placeholder: x.getAttribute("placeholder"), maxlength: x.getAttribute("maxlength") })));
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  // 閉じて破棄する。投稿ボタンは触らない
  try {
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press("Escape"); await page.waitForTimeout(1200);
      const d = await page.$('[data-testid="confirmationSheetCancel"], [data-testid="confirmationSheetConfirm"]');
      if (d) { const discard = await page.$('[data-testid="confirmationSheetConfirm"]'); const txt = discard ? await discard.innerText() : "";
        r.steps.push("確認ダイアログ: " + txt);
        if (/破棄|Discard/.test(txt)) { await discard.click(); await page.waitForTimeout(1500); } else { const c2 = await page.$('[data-testid="confirmationSheetCancel"]'); if (c2 && /破棄|Discard/.test(await c2.innerText())) await c2.click(); } }
    }
    r.closedUrl = page.url();
    await page.close().catch(() => {});
  } catch (e) { r.closeError = String(e && e.message).slice(0, 160); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS

{
echo "# 投稿画面の ALT の欄（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・投稿していない）"
echo
echo "## ① post-via-playwright.js の全文"
echo
echo '```js'
printf '// %s 行\n' "$(wc -l < "$S/post-via-playwright.js" | tr -d ' ')"
cat "$S/post-via-playwright.js" | secrets | hide
echo '```'
echo
echo "## ②③ 画像を 1 枚 添付して、ALT の欄を開いた結果"
echo
rm -f "$OUTDIR"/x263-*.png
cd "$W" && node "$PROBE" "$IMG" "$OUTDIR" > "$RAW" 2>&1
echo '```json'
node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());console.log(JSON.stringify(j,null,1))}catch(e){console.log(require("fs").readFileSync(process.argv[1],"utf8").slice(0,1500))}' "$RAW" | secrets | hide
echo '```'
echo
echo "画面: $(ls "$OUTDIR"/x263-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
rm -f "$PROBE" "$RAW" "$IMG"
echo
echo "**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "投稿画面の ALT の欄を読んだ / $(basename "$OUT")"
