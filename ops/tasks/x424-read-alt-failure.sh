#!/bin/bash
# **ALT を付けると投稿が落ちる件を調べる（x424）。投稿しない。費用 $0。**
#
# 利用者「Altを付けるとうまくいかない件は、投稿し終わったあとに徹底的に調べて」（2026-11-04。湾岸ニュース5選は x423 で ALT 無しで出た）。
#
# 分かっていること:
#   - x421: 画像 2 枚を添付 → 「alt set for image 1」まで出て、そのあと thread-main-exec で落ちた。理由の文が残っていない
#   - 10/11 の紅葉（4 枚）でも 3 回落ちた（x264〜x266）。ALT が付いて出たことは一度も無い
#   - post-via-playwright.js は 2 枚目へ送るのに aria-label「次へ」を押す。x267 で読んだ画面では、画像を送るのは「次の画像」で、「次へ」は押せなかった
#   - 落ちた理由は post-via-playwright.js が stdout に出すが、呼ぶ側の thread モードは e.message（＝stderr）しか残していないかもしれない
#
# やること（読むだけ・投稿ボタンは一度も触らない）:
#   ① post-via-playwright.js の ALT の部分と、例外を受ける部分の今のコード
#   ② run-publish.sh の thread モードが、本体を呼んで失敗をどう受けているか
#   ③ 実物で試す: 投稿画面に湾岸ニュース5選の画像 2 枚を添付し、post-via-playwright.js と同じ手順で ALT を入れる。
#      各段で画面の作り（ボタン・画像・入力欄）を出し、どこで何が起きるかを記録する。
#      2 枚目は「次へ」で送れるかを試し、駄目なら「次の画像」でも試す。画面を撮る
#   ④ 閉じて下書きは破棄する
# **LLM を呼ばない（$0／回・$0／日・$0／月）。2〜3 分で終わる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x424-alt-failure.md"
PROBE="$W/.x424-probe.js"; RAW="$W/.x424-out.json"
IMG="$D/x-wangan-news-5/1-cover.jpg,$D/x-wangan-news-5/2-list.jpg"; ALTF="$D/.x414-wangan5-alts.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(xox[abp]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

cat > "$PROBE" <<'PROBEJS'
// x424: 投稿スクリプトの ALT の手順を写して、段ごとに画面を読む。投稿ボタンは触らない
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [img, altf, outdir] = process.argv.slice(2);
const alts = JSON.parse(fs.readFileSync(altf, "utf8"));
const r = { log: [], alt_lens: alts.map((a) => (a || "").length) };
const L = (s) => r.log.push(s);
(async () => {
  let page;
  const dlg = () => page.$$eval('[role="dialog"]', (ds) => ds.map((d, di) => ({
    di, nested: !!(d.parentElement && d.parentElement.closest("[role=dialog]")),
    buttons: [...d.querySelectorAll("button,[role=button],a[aria-label]")].map((x) => (x.getAttribute("aria-label") || (x.innerText || "").trim().slice(0, 20)) + (x.getAttribute("aria-disabled") === "true" || x.disabled ? "［押せない］" : "") + (x.getAttribute("data-testid") ? " #" + x.getAttribute("data-testid") : "")).filter(Boolean).slice(0, 40),
    imgs: [...d.querySelectorAll("img")].map((x) => { const b = x.getBoundingClientRect(); return (x.getAttribute("src") || "").slice(-12) + " " + x.offsetWidth + "x" + x.offsetHeight + " at " + Math.round(b.left) + "," + Math.round(b.top); }).slice(0, 10),
    inputs: [...d.querySelectorAll("textarea,input[type=text]")].map((x) => (x.getAttribute("data-testid") || "") + " maxlength=" + x.getAttribute("maxlength") + " len=" + (x.value || "").length),
  })));
  try {
    const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    page = await b.contexts()[0].newPage();
    page.on("dialog", (d) => { d.dismiss().catch(() => {}); });
    await page.setViewportSize({ width: 1280, height: 1100 });
    await page.goto("https://x.com/compose/post", { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('[data-testid="tweetTextarea_0"]', { timeout: 30000 });
    await page.waitForTimeout(2000);
    const fi = await page.$('input[data-testid="fileInput"]') || await page.$('input[type="file"]');
    await fi.setInputFiles(img.split(","));
    for (let k = 0; k < 30; k++) { const n = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.length); if (n >= 2) break; await page.waitForTimeout(1500); }
    await page.waitForTimeout(3000);
    const thumbs = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.map((x) => x.getAttribute("src") || ""));
    r.thumbs = thumbs.map((t) => t.slice(-12));
    for (let i = 0; i < alts.length; i++) {
      if (!alts[i]) continue;
      const tag = (i + 1) + "枚目";
      const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
      const n = await wrappers.count();
      r["wrappers_" + (i + 1)] = await page.$$eval('[data-testid="attachments"] [data-testid="altTextWrapper"]', (xs) => xs.map((x) => (x.innerText || "").trim()));
      L(tag + ": altTextWrapper " + n + " 個。押すのは " + (n > i ? i : 0) + " 番");
      if (n === 0) { L(tag + ": altTextWrapper が無い → 本番はここで落ちる"); break; }
      await wrappers.nth(n > i ? i : 0).click();
      await page.waitForTimeout(2500);
      await page.screenshot({ path: outdir + "/x424-" + (i + 1) + "a-editor.png" });
      r["dialogs_" + (i + 1) + "_open"] = await dlg();
      const curIndex = async () => {
        const srcs = await page.$$eval('[role="dialog"] img', (xs) => xs.filter((x) => x.offsetWidth > 120 && x.offsetHeight > 120).map((x) => x.getAttribute("src") || ""));
        for (const sv of srcs) { const k = thumbs.indexOf(sv); if (k >= 0) return k; }
        return -1;
      };
      let at = await curIndex();
      L(tag + ": 開いた直後の at=" + at);
      // 本番と同じ「次へ」
      for (let g = 0; at !== i && g < 4; g++) {
        const nx = page.locator('[role="dialog"]:has([data-testid="endEditingButton"]) button[aria-label="次へ"]').last();
        const c = await nx.count();
        const dis = c ? await nx.getAttribute("aria-disabled") : null;
        L(tag + ": 「次へ」 " + c + " 個 aria-disabled=" + dis);
        if (!c) break;
        await nx.click({ timeout: 5000 }).catch((e) => L(tag + ": 「次へ」が押せない: " + String(e.message).split("\n")[0].slice(0, 120)));
        await page.waitForTimeout(1500); at = await curIndex(); L(tag + ": 「次へ」のあと at=" + at);
      }
      if (at !== i) {
        L(tag + ": 本番はここで落ちる（編集画面で " + (i + 1) + " 枚目を特定できない）。「次の画像」で試す");
        for (let g = 0; at !== i && g < 4; g++) {
          const nx2 = page.locator('[role="dialog"] [aria-label="次の画像"]').last();
          const c2 = await nx2.count(); L(tag + ": 「次の画像」 " + c2 + " 個");
          if (!c2) break;
          await nx2.click({ timeout: 5000 }).catch((e) => L(tag + ": 「次の画像」が押せない: " + String(e.message).split("\n")[0].slice(0, 120)));
          await page.waitForTimeout(1500); at = await curIndex(); L(tag + ": 「次の画像」のあと at=" + at);
        }
        await page.screenshot({ path: outdir + "/x424-" + (i + 1) + "b-after-next.png" });
        r["dialogs_" + (i + 1) + "_after_next"] = await dlg();
      }
      let box = page.locator('[role="dialog"] textarea').first();
      L(tag + ": textarea " + (await box.count()) + " 個");
      if (!(await box.count())) { L(tag + ": 入力欄が無い → 本番はここで落ちる"); break; }
      await box.fill(alts[i]); await page.waitForTimeout(500);
      const got = await box.inputValue();
      L(tag + ": 入れた " + got.length + " 字 / 入れたい " + alts[i].length + " 字" + (got.replace(/\s/g, "") === alts[i].replace(/\s/g, "") ? "（一致）" : "（**不一致** → 本番はここで落ちる）"));
      const save = page.locator('[role="dialog"] [data-testid="endEditingButton"]').first();
      L(tag + ": 保存ボタン " + (await save.count()) + " 個");
      if (!(await save.count())) break;
      await save.click(); await page.waitForTimeout(1500);
      r["after_save_" + (i + 1)] = await dlg();
    }
    await page.screenshot({ path: outdir + "/x424-9-final.png" });
  } catch (e) { r.error = String(e && e.message).split("\n").slice(0, 3).join(" / ").slice(0, 300); }
  try {
    for (let k = 0; k < 4; k++) {
      await page.keyboard.press("Escape"); await page.waitForTimeout(1200);
      const btns = await page.$$('[data-testid="confirmationSheetCancel"], [data-testid="confirmationSheetConfirm"]');
      for (const bt of btns) { const t = (await bt.innerText()).trim(); if (/破棄|Discard/.test(t)) { r.log.push("閉じる: 「" + t + "」を押した"); await bt.click(); await page.waitForTimeout(1500); break; } }
    }
    r.closedUrl = page.url(); await page.close().catch(() => {});
  } catch (e) { r.closeError = String(e && e.message).slice(0, 160); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS

{
echo "# ALT を付けると投稿が落ちる件（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・投稿していない）"
echo; echo "## ① post-via-playwright.js の ALT の部分と、例外を受ける部分"; echo '```js'
grep -n -A50 'ALT_TEXTS_FILE' "$S/post-via-playwright.js" | head -56
echo "// --- catch の部分"
grep -n -A6 '} catch (e' "$S/post-via-playwright.js" | head -40
echo '```'
echo; echo "## ② run-publish.sh の thread モードは失敗をどう受けているか"; echo '```'
grep -n -B12 -A4 'thread-main-exec' "$S/run-publish.sh" | head -60 | secrets
echo '```'
echo; echo "## ③ 実物で試す（画像 2 枚・ALT 2 本・投稿しない）"; echo '```json'
rm -f "$OUTDIR"/x424-*.png
if [ ! -f "$ALTF" ] || [ ! -f "$D/x-wangan-news-5/1-cover.jpg" ]; then echo "画像か ALT のファイルが無い"; else
  cd "$W" && "$NODE_BIN" "$PROBE" "$IMG" "$ALTF" "$OUTDIR" > "$RAW" 2>&1
  "$NODE_BIN" -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());console.log(JSON.stringify(j,null,1))}catch(e){console.log(require("fs").readFileSync(process.argv[1],"utf8").slice(0,2000))}' "$RAW" | secrets | hide
fi
echo '```'
echo; echo "画面: $(ls "$OUTDIR"/x424-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
rm -f "$PROBE" "$RAW"
echo; echo "**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
