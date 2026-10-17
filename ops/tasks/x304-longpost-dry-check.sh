#!/bin/bash
# **長文（青バッジ）が入力欄に入り、投稿ボタンが有効になるかだけを見る。押さない。費用 $0。**
# 利用者の選択「長文が投稿できるか先に確かめる」（2026-10-17）。感謝祭の [1/2]（重み 1,609）が対象。
# いつもの投稿と同じ入れ方（insertText → 空振りなら type）で入れ、
#   ① 入った文が意図と一致するか ② 投稿ボタンが有効か ③ 上限超えの表示が出ていないか を見る。
# **投稿ボタンには触れない。** 終わったら Escape →「破棄」で下書きも残さない。画面を撮って reports に置く。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
R="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/longpost-dry-check.md"
SHOT="${OPS_REPORT_DIR:-/tmp}/x304-longpost.png"
TXT="$W/.x304-text.txt"
git -C "$R" fetch -q origin main 2>/dev/null
git -C "$R" show origin/main:scripts/image-review/posts.json | node -e 'const j=JSON.parse(require("fs").readFileSync(0,"utf8"));process.stdout.write(j.prime[0])' > "$TXT"
P="$W/.x304.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const fs = require("fs");
const TEXT = fs.readFileSync(process.argv[2], "utf8");
const SHOT = process.argv[3];
const norm = (s) => String(s || "").replace(/\s+/g, "");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const res = { len: TEXT.length };
  try {
    await p.goto("https://x.com/compose/post", { waitUntil: "domcontentloaded", timeout: 30000 });
    const ta = await p.waitForSelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]', { timeout: 20000 });
    await ta.click();
    const readBox = () => p.evaluate(() => { const el = document.querySelector('div[data-testid^="tweetTextarea_"][contenteditable="true"]'); return el ? el.textContent : ""; });
    const t0 = Date.now();
    await p.keyboard.insertText(TEXT);
    await p.waitForTimeout(2500);
    let got = await readBox(); res.method = "insertText";
    if (norm(got) !== norm(TEXT)) {
      res.insertTextGot = norm(got).length;
      await p.keyboard.down("Meta"); await p.keyboard.press("a"); await p.keyboard.up("Meta"); await p.keyboard.press("Backspace");
      await p.waitForTimeout(500);
      await ta.type(TEXT, { delay: 8 });
      await p.waitForTimeout(2500);
      got = await readBox(); res.method = "type";
    }
    res.ms = Date.now() - t0;
    res.match = norm(got) === norm(TEXT);
    res.gotLen = norm(got).length; res.wantLen = norm(TEXT).length;
    res.buttons = [];
    for (const sel of ['[data-testid="tweetButton"]', '[data-testid="tweetButtonInline"]']) {
      const btn = await p.$(sel);
      if (btn) res.buttons.push(sel + " 有効=" + !(await btn.isDisabled().catch(() => true)));
    }
    res.page = await p.evaluate(() => {
      const t = document.body.innerText;
      return { over: /文字数.*超え|上限を超え|too long|exceeds/i.test(t), counter: (document.querySelector('[role="progressbar"]') || {}).getAttribute ? document.querySelector('[role="progressbar"]').getAttribute("aria-valuenow") : null,
               premiumHint: /さらに表示|Show more|長いポスト|longer posts/i.test(t) };
    });
    await p.screenshot({ path: SHOT });
  } catch (e) { res.error = String(e.message).slice(0, 200); }
  // **押さない。下書きも残さない**
  try {
    await p.keyboard.press("Escape"); await p.waitForTimeout(1200);
    const d = await p.$('[data-testid="confirmationSheetCancel"]');
    if (d) { await d.click(); res.discard = "破棄を押した"; } else res.discard = "破棄の確認は出なかった";
    await p.waitForTimeout(800);
  } catch (e) { res.discard = "閉じる途中でエラー: " + String(e.message).slice(0, 80); }
  await p.close().catch(() => {});
  console.log(JSON.stringify(res));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 長文が入力欄に入り、投稿ボタンが有効になるか（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
echo "対象: 感謝祭の [1/2]（$(wc -m < "$TXT" | tr -d ' ') 文字）"
echo '```json'
(cd "$W" && node "$P" "$TXT" "$SHOT" 2>&1 | tail -1)
echo '```'
echo
[ -f "$SHOT" ] && echo "画面: reports/$(basename "$SHOT")（$(wc -c < "$SHOT" | tr -d ' ') bytes）" || echo "画面は撮れなかった"
echo
echo "**投稿ボタンは押していない。下書きは破棄。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$P" "$TXT"
echo "長文が入力欄に入るかを確かめた（押していない） / $(basename "$OUT")"
