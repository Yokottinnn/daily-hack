#!/bin/bash
# **投稿スクリプトの ALT の 2 枚目以降を直す（x425）。投稿しない。費用 $0。**
#
# 利用者がダイアログで「投稿スクリプトを直す」を選んだ（2026-11-05）。
# x424 で分かった原因: 2 枚目へ送るのに aria-label「次へ」を押していたが、ALT の編集画面ではこのボタンはいつも押せない。
# 正しくは「次の画像」。x424 で押すと 2 枚目に移り、2 枚とも ALT が入った。
#
#   ① 直す対象は「ALT_TEXTS_FILE を読む投稿スクリプト」（scripts/ の中から中身で探す。1 本でなければ止める）
#   ② 「次へ」を押す 1 行だけを「次の画像（押せるもの）」に置き換える。ちょうど 1 か所でなければ止める。退避を残す
#   ③ 構文を確かめてから入れ替える（拡張子 .js を保った隠しファイルで確かめる・最上位ルール 14）
#   ④ 確かめ: 直したファイルから「2 枚目へ送るボタンの指定」をそのまま読み出し、投稿画面で画像 2 枚に ALT を入れる。
#      2 枚とも入るかを見る。**投稿ボタンは触らない。下書きは破棄する**
# **このタスクは投稿しない**（投稿経路の中身を直すだけ）。LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x425-fix-alt-next-image.md"
PROBE="$W/.x425-probe.js"; RAW="$W/.x425-out.json"
IMG="$D/x-wangan-news-5/1-cover.jpg,$D/x-wangan-news-5/2-list.jpg"; ALTF="$D/.x414-wangan5-alts.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# ALT の 2 枚目以降を直す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・投稿していない）"
echo; echo "## ①〜③ 直す"; echo '```'
CANDS="$(grep -l 'process.env.ALT_TEXTS_FILE' "$S"/*.js 2>/dev/null)"
NC="$(printf '%s\n' "$CANDS" | grep -c . | head -1)"
echo "対象の候補: $NC 本 → $(printf '%s ' $CANDS | sed "s#$S/##g")"
if [ "$NC" != "1" ]; then echo "1 本ではない。止める"; echo '```'; exit 1; fi
T="$CANDS"; TMPJS="$S/.x425-check.js"
if grep -q 'aria-label="次の画像"' "$T"; then echo "もう直っている"; else
  cp "$T" "$T.bak-x425"
  "$NODE_BIN" -e '
const fs=require("fs");const [f,o]=process.argv.slice(1);let s=fs.readFileSync(f,"utf8");
const OLD=`[role="dialog"]:has([data-testid="endEditingButton"]) button[aria-label="次へ"]`;
const NEW=`[role="dialog"]:has([data-testid="endEditingButton"]) [aria-label="次の画像"]:not([aria-disabled="true"])`;
const n=s.split(OLD).length-1; if(n!==1){console.log("置き換える場所が "+n+" か所。止める");process.exit(3);}
s=s.split(OLD).join(NEW);
s=s.replace("// そのときは押して編集画面を開き「次へ」で i 枚目まで送る。", ()=>"// そのときは押して編集画面を開き「次の画像」で i 枚目まで送る（2026-11-05 x425: 「次へ」は編集画面ではいつも押せず、2 枚目以降で必ず落ちていた・x424）。");
fs.writeFileSync(o,s); console.log("置き換えた（1 か所）");' "$T" "$TMPJS"
  RC=$?
  if [ $RC -eq 0 ] && "$NODE_BIN" --check "$TMPJS" 2>&1; then mv "$TMPJS" "$T"; echo "構文 OK・入れ替えた（退避 $(basename "$T").bak-x425）"
  else rm -f "$TMPJS"; echo "直していない（rc=$RC）。元のまま。止める"; echo '```'; exit 1; fi
fi
grep -n '次の画像\|次へ' "$T" | cut -c1-200
echo '```'

cat > "$PROBE" <<'PROBEJS'
// x425: 直した投稿スクリプトから「2 枚目へ送るボタンの指定」を読み出し、同じ手順で ALT を入れる。投稿ボタンは触らない
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [target, img, altf, outdir] = process.argv.slice(2);
const src = fs.readFileSync(target, "utf8");
const m = src.match(/const nx = page\.locator\('([^']+)'\)\.last\(\);/);
const r = { log: [], selector: m ? m[1] : null };
const L = (s) => r.log.push(s);
(async () => {
  if (!m) { r.error = "直したファイルからボタンの指定が読めない"; console.log(JSON.stringify(r)); process.exit(0); }
  const alts = JSON.parse(fs.readFileSync(altf, "utf8"));
  let page;
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
    let set = 0;
    for (let i = 0; i < alts.length; i++) {
      if (!alts[i]) continue;
      const thumbs = await page.$$eval('[data-testid="attachments"] img', (xs) => xs.map((x) => x.getAttribute("src") || ""));
      const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
      const n = await wrappers.count();
      await wrappers.nth(n > i ? i : 0).click(); await page.waitForTimeout(2500);
      const curIndex = async () => {
        const srcs = await page.$$eval('[role="dialog"] img', (xs) => xs.filter((x) => x.offsetWidth > 120 && x.offsetHeight > 120).map((x) => x.getAttribute("src") || ""));
        for (const sv of srcs) { const k = thumbs.indexOf(sv); if (k >= 0) return k; }
        return -1;
      };
      let at = await curIndex();
      for (let g = 0; at !== i && g < 4; g++) {
        const nx = page.locator(m[1]).last();
        if (!(await nx.count())) { L((i + 1) + "枚目: 送るボタンが無い"); break; }
        await nx.click({ timeout: 8000 }); await page.waitForTimeout(1500); at = await curIndex();
      }
      L((i + 1) + "枚目: 編集画面の位置 at=" + at + (at === i ? "（合っている）" : "（**違う** → 本番は落ちる）"));
      if (at !== i) break;
      const box = page.locator('[role="dialog"] textarea').first();
      await box.fill(alts[i]); await page.waitForTimeout(500);
      const got = await box.inputValue();
      const ok = got.replace(/\s/g, "") === alts[i].replace(/\s/g, "");
      L((i + 1) + "枚目: " + got.length + " 字 入れた" + (ok ? "（一致）" : "（**不一致**）"));
      await page.locator('[role="dialog"] [data-testid="endEditingButton"]').first().click(); await page.waitForTimeout(1500);
      if (ok) set++;
    }
    r.alt_badges = await page.$$eval('[data-testid="attachments"] *', (xs) => xs.filter((x) => (x.innerText || "").trim() === "ALT" && x.children.length === 0).length);
    r.wrapper_text = await page.$$eval('[data-testid="altTextWrapper"]', (xs) => xs.map((x) => (x.innerText || "").trim()));
    r.result = set + " / " + alts.filter(Boolean).length + " 枚に ALT が入った";
    await page.screenshot({ path: outdir + "/x425-final.png" });
  } catch (e) { r.error = String(e && e.message).split("\n").slice(0, 2).join(" / ").slice(0, 300); }
  try {
    for (let k = 0; k < 4; k++) {
      await page.keyboard.press("Escape"); await page.waitForTimeout(1200);
      const btns = await page.$$('[data-testid="confirmationSheetCancel"], [data-testid="confirmationSheetConfirm"]');
      for (const bt of btns) { const t = (await bt.innerText()).trim(); if (/破棄|Discard/.test(t)) { L("閉じる: 「" + t + "」を押した"); await bt.click(); await page.waitForTimeout(1500); break; } }
    }
    await page.close().catch(() => {});
  } catch (e) { r.closeError = String(e && e.message).slice(0, 160); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS
echo; echo "## ④ 確かめる（画像 2 枚・ALT 2 本・投稿しない）"; echo '```json'
rm -f "$OUTDIR"/x425-*.png
cd "$W" && "$NODE_BIN" "$PROBE" "$T" "$IMG" "$ALTF" "$OUTDIR" > "$RAW" 2>&1
"$NODE_BIN" -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop());console.log(JSON.stringify(j,null,1))}catch(e){console.log(require("fs").readFileSync(process.argv[1],"utf8").slice(0,2000))}' "$RAW" | hide
echo '```'
echo; echo "画面: $(ls "$OUTDIR"/x425-*.png 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' ')"
rm -f "$PROBE" "$RAW"
echo; echo "**投稿ボタンは触っていない。下書きは破棄した。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
