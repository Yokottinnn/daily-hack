#!/bin/bash
# **X の Grok「動画を作成」で、キャラが手を振る動画を 1 本 作る。費用 $0（X のプラン内）。**
#
# ## 指示（2026-10-03）
#
#   > 手を振ってるやつは、振ってる時に服と手の間に絵の切れ目が出来てしまっているので、ちゃんとAiを使って動画を生成してくれない？
#   → 経路は「X の Grok で作る（$0）」を選んでもらった（X と Grok のアカウント連携への同意を含む）
#
# **3 回目。x208 で分かったこと:** 「動画を作成」を押すと**ファイル選択の窓が開く**作りで、x208 はそれを受けていなかった。
# 画像専用の入力欄は「画像を編集」のもので（入力欄が「どのように画像を編集しますか？」に変わった）、
# 送ると Grok は文章で「動画は作れない」と返した。→ **押す前に filechooser を待ち受け、開いた窓に画像を渡す。**
#
# （以下は 2 回目のときの説明）
# **x207 の失敗を直した 2 回目。** x207 は「動画を作成」が押せておらず（画面が変わらなかった）、
# 画像はチャット用の添付欄に入り、ふつうのチャットとして送られた（Grok は「動画は作れない」と文章で返した）。
#   → ボタンは role と名前で押し、**押したあとの画面で動画モードに入ったかを確かめる**
#   → 添付は**画像専用の入力欄**（accept が image/jpeg,image/webp,image/png のもの）を優先する
# 各段階で画面を撮り、ボタンと入力欄を書き出す。
# 途中で止まっても、次のタスクでどこを押せばよいかが分かるようにする（最上位ルール 20）。
#
#   1. x.com/i/grok を開く → 「同意して続行」があれば押す（利用者が選んだ経路の前提）
#   2. 「動画を作成」を押す
#   3. 画像（origin/main の ops/data/x-cards/follower-300-grok/in-wave.png）を添付し、指示文を入れて送る
#   4. 動画ができるまで最大 約 3 分 待ち、mp4 を $OPS_REPORT_DIR に保存する
#
# **投稿しない。** Grok の中で作るだけ。API は呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
REPO="${OPS_MAIN_REPO:-$HOME/projects/anta-baka-x/blog}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x210-grok-$STAMP.js"
RAW="$W/.x210-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/grok-video-wave.md"
IMG="$W/.x210-in-wave-$STAMP.png"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }

descendants() {
  local root="$1" p kids
  kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"
  for p in $kids; do echo "$p"; descendants "$p"; done
}
run_limited() {
  local limit="$1" outf="$2"; shift 2
  "$@" > "$outf" 2>&1 &
  local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1; w=$((w + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    local victims p
    victims="$(descendants "$pid") $pid"
    for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done
    sleep 3
    for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"; return $?
}

cat > "$RUNNER" <<'JSEOF'
// x210: X の Grok「動画を作成」で手を振る動画を作る。各段階で画面を撮り、ボタンを書き出す。
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2], IMG = process.argv[3];
const PROMPT = "Animate this anime girl into a short video: she cheerfully waves her raised hand side to side two times with natural wrist and arm motion, " +
  "her body sways slightly, her twin tails bounce gently, she keeps smiling and blinks once. " +
  "Keep exactly the same art style, character design, colors, framing and plain pink background. Static camera. No new objects, no text.";
const t0 = Date.now();
const log = [];
const step = async (p, name) => {
  const f = "x210-" + String(log.length + 1).padStart(2, "0") + "-" + name + ".png";
  try { await p.screenshot({ path: OUTDIR + "/" + f }); } catch (e) {}
  const ui = await p.evaluate(() => {
    const vis = (e) => { const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; };
    return {
      buttons: [...document.querySelectorAll('button,[role="button"],a[role="link"]')].filter(vis)
        .map((b) => (b.getAttribute("aria-label") || b.innerText || "").trim().replace(/\s+/g, " ").slice(0, 40)).filter(Boolean).slice(0, 60),
      files: [...document.querySelectorAll('input[type="file"]')].map((i) => i.getAttribute("accept") || "*"),
      textareas: [...document.querySelectorAll('textarea,[contenteditable="true"]')].filter(vis).map((t) => (t.getAttribute("placeholder") || t.getAttribute("aria-label") || t.tagName)).slice(0, 5),
      videos: [...document.querySelectorAll("video")].map((v) => (v.currentSrc || v.src || (v.querySelector("source") || {}).src || "").slice(0, 120)),
    };
  }).catch((e) => ({ error: String(e && e.message).slice(0, 120) }));
  log.push({ name, shot: f, url: p.url(), sec: Math.round((Date.now() - t0) / 1000), ui });
};
const clickText = async (p, re) => {
  const loc = p.locator('button,[role="button"],a,[role="menuitem"],div[tabindex]').filter({ hasText: re }).first();
  if (await loc.count()) { await loc.click({ timeout: 8000 }); return true; }
  return false;
};
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  if (!ctx) { console.log(JSON.stringify({ fatal: "context が無い" })); process.exit(0); }
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 1200, height: 1100 });
  const res = { steps: log };
  try {
    await p.goto("https://x.com/i/grok", { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(7000);
    await step(p, "open");
    res.consent = await clickText(p, /同意して続行|Agree and continue/).catch(() => false);
    if (res.consent) { await p.waitForTimeout(6000); await step(p, "after-consent"); }
    const vbtn = p.getByRole("button", { name: /動画を作成|Create video/ }).first();
    res.videoMode = (await vbtn.count()) > 0;
    if (res.videoMode) { await vbtn.scrollIntoViewIfNeeded().catch(() => {}); await vbtn.click({ timeout: 8000 }).catch(() => {}); }
    await p.waitForTimeout(2500);
    // 押したあとのボタンの状態と、入力欄のまわりの HTML（属性だけ・短く）
    res.chip = await vbtn.evaluate((e) => ({ pressed: e.getAttribute("aria-pressed"), cls: (e.className || "").toString().slice(0, 120), html: e.outerHTML.slice(0, 300) })).catch(() => null);
    res.composer = await p.evaluate(() => { const t = document.querySelector("textarea"); let n = t; for (let i = 0; i < 4 && n && n.parentElement; i++) n = n.parentElement;
      return n ? n.outerHTML.replace(/<svg[\s\S]*?<\/svg>/g, "<svg/>").replace(/\s(class|style)="[^"]*"/g, "").slice(0, 1500) : null; }).catch(() => null);
    await step(p, "video-mode");
    // チャット用の添付（accept に pdf を含むほう）
    let file = p.locator('input[type="file"]').filter({ has: p.locator("xpath=self::*[contains(@accept,'pdf')]") }).first();
    if (!(await file.count())) file = p.locator('input[type="file"]').first();
    res.fileInput = "チャット用（クリップ）";
    await file.setInputFiles(IMG); res.uploaded = true;
    await p.waitForTimeout(6000);
    res.chipAfterUpload = await vbtn.evaluate((e) => e.getAttribute("aria-pressed")).catch(() => null);
    await step(p, "uploaded");
    res.afterModeHint = await p.evaluate(() => [...document.querySelectorAll("textarea")].map((t) => t.getAttribute("placeholder")).join(" / ")).catch(() => null);
    const box = p.locator('textarea, [contenteditable="true"]').first();
    if (await box.count()) {
      await box.click(); await box.fill(PROMPT).catch(async () => { await p.keyboard.type(PROMPT); });
      await p.waitForTimeout(800);
      await step(p, "prompt");
      const sent = await p.locator('button[aria-label*="送信"], button[aria-label*="Send"], button[aria-label*="Grok"], button[type="submit"]').first();
      if (await sent.count() && await sent.isEnabled().catch(() => false)) { await sent.click(); res.sent = "button"; }
      else { await p.keyboard.press("Enter"); res.sent = "enter"; }
    } else res.sent = false;
    // 動画ができるまで待つ（全体で 250 秒まで）
    let src = null;
    while (Date.now() - t0 < 245000) {
      await p.waitForTimeout(10000);
      src = await p.evaluate(() => {
        const v = [...document.querySelectorAll("video")].map((v) => v.currentSrc || v.src || (v.querySelector("source") || {}).src).filter(Boolean);
        return v.length ? v[v.length - 1] : null;
      }).catch(() => null);
      if (src) break;
    }
    await step(p, src ? "video-ready" : "timeout");
    res.src = src ? src.slice(0, 160) : null;
    if (src) {
      let buf = null;
      if (/^blob:|^data:/.test(src)) {
        const b64 = await p.evaluate(async (u) => { const r = await fetch(u); const a = new Uint8Array(await r.arrayBuffer());
          let s = ""; for (let i = 0; i < a.length; i += 0x8000) s += String.fromCharCode.apply(null, a.subarray(i, i + 0x8000)); return btoa(s); }, src).catch(() => null);
        if (b64) buf = Buffer.from(b64, "base64");
      } else {
        const r = await ctx.request.get(src).catch(() => null);
        if (r && r.ok()) buf = await r.body();
      }
      if (buf && buf.length) { fs.writeFileSync(OUTDIR + "/x210-wave.mp4", buf); res.saved = buf.length; }
    }
  } catch (e) { res.error = String(e && e.message).slice(0, 200); try { await step(p, "error"); } catch (_) {} }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(res));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# X の Grok で手を振る動画を作る（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。** Grok の中で作るだけ。API は呼ばない（\$0／回・\$0／日・\$0／月）。"
echo
echo '```'
if git -C "$REPO" show "origin/main:ops/data/x-cards/follower-300-grok/in-wave.png" > "$IMG" 2>/dev/null && [ -s "$IMG" ]; then
  printf '  入力画像 %s bytes\n' "$(wc -c < "$IMG" | tr -d ' ')"
else
  echo "  **入力画像が取れない**（origin/main に無い）"
fi
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -eq 0 ] && [ -s "$IMG" ]; then
  rm -f "$OUTDIR"/x210-*
  T0="$(date +%s)"
  run_limited 280 "$RAW" node "$RUNNER" "$OUTDIR" "$IMG"; RC=$?
  printf '  rc=%s / かかった秒数 %s\n' "$RC" "$(( $(date +%s) - T0 ))"
  for f in "$OUTDIR"/x210-*; do [ -s "$f" ] && printf '  %s（%s bytes）\n' "$(basename "$f")" "$(wc -c < "$f" | tr -d ' ')"; done
fi
echo '```'
rm -f "$RUNNER" "$IMG"
if [ -s "$RAW" ]; then
  node -e '
    let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); }
    catch (e) { console.log("**JSON として読めない:**\n```\n" + require("fs").readFileSync(process.argv[1], "utf8").slice(0, 600) + "\n```"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    console.log("\n## 結果\n");
    console.log("- 同意を押した: " + j.consent + " ／ 動画ボタン: " + j.videoMode + " ／ 押したあとの入力欄: " + j.afterModeHint + " ／ 添付欄: " + j.fileInput + " ／ 画像を添付: " + j.uploaded + " ／ 送信: " + j.sent);
    console.log("- 押したあとのボタン: " + JSON.stringify(j.chip) + " ／ 添付後の aria-pressed: " + j.chipAfterUpload);
    console.log("\n入力欄のまわり:\n```html\n" + (j.composer || "(取れない)") + "\n```\n");
    console.log("- 動画の src: " + (j.src || "**出てこなかった**") + " ／ 保存: " + (j.saved ? j.saved + " bytes（x210-wave.mp4）" : "**できていない**"));
    if (j.error) console.log("- **エラー: " + j.error + "**");
    console.log("\n## 段階ごとの画面と UI\n");
    for (const s of j.steps || []) {
      console.log("### " + s.name + "（" + s.sec + " 秒・`" + s.shot + "`）\n");
      console.log("```\nURL: " + s.url + "\nボタン: " + ((s.ui && s.ui.buttons) || []).join(" | ") + "\nファイル入力: " + JSON.stringify((s.ui && s.ui.files) || []) +
        "\n入力欄: " + JSON.stringify((s.ui && s.ui.textareas) || []) + "\n動画: " + JSON.stringify((s.ui && s.ui.videos) || []) + (s.ui && s.ui.error ? "\nエラー: " + s.ui.error : "") + "\n```\n");
    }
  ' "$RAW" 2>&1 | hide
else
  echo; echo "**出力が空。CDP か Chrome を確かめる**"
fi
rm -f "$RAW"
echo
echo "**投稿していない。API を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -aq 'x210-wave.mp4）' "$OUT" 2>/dev/null; then echo "Grok で手を振る動画ができた / $(basename "$OUT")"
else echo "**動画はまだ取れていない。画面と UI を確認すること** / $(basename "$OUT")"; fi
