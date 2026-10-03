#!/bin/bash
# **アンフォローの「フォロー中のボタンが無い」の原因を測る。読むだけ。外さない。費用 $0。**
#
# ## 指示（2026-10-03）
#
#   > アンフォローのオペレーションってちゃんと動いてる？ → 「外せない原因を測る」
#
# x217 で分かったこと: follow-balance は 11:45・18:45 とも走り、候補 7 件を選べているが、
# 相手のページで **「フォロー中のボタンが無い」（empty:true / follow_btns:(無し)）** となり 0 件。
#
#   ① follow-balance.js の「ボタンを探す」部分と「ページを開いて待つ」部分を書き出す
#   ② 今日 失敗した相手を follow-balance.log から最大 3 件 拾い、ページを開いて
#      1 秒・4 秒・8 秒 待ったときの DOM を読む（ボタンの data-testid / aria-label / 文言・main の有無・ログイン状態）
#
# **ボタンは押さない。外さない。フォローしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
# 他人のハンドルはレポートに出さない（1 件目・2 件目… と番号で書く）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
L="$W/logs"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x218-read-$STAMP.js"
LIST="$W/.x218-list-$STAMP.txt"
RAW="$W/.x218-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/measure-unfollow-button.md"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#\"/[A-Za-z0-9_]{2,15}\"#\"/<伏せ>\"#g; s#x\.com/[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

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

# 今日 失敗した相手（"path":"/xxx" から拾う・重複を除いて最大 3 件）
TODAY_UTC="$(date -u '+%Y-%m-%d')"
grep "フォロー中のボタンが無い" "$L/follow-balance.log" 2>/dev/null | grep "$TODAY_UTC" \
  | sed -E 's/.*"path":"\/([A-Za-z0-9_]+)".*/\1/' | awk '!s[$0]++' | head -3 > "$LIST"
printf '\n' >> "$LIST"

cat > "$RUNNER" <<'JSEOF'
// x218: 失敗した相手のページを開いて DOM を読むだけ。押さない。$0。
const { chromium } = require("playwright-core");
const fs = require("fs");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const handles = fs.readFileSync(process.argv[2], "utf8").split("\n").map((s) => s.trim()).filter(Boolean);
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const p = await b.contexts()[0].newPage();
  await p.setViewportSize({ width: 1200, height: 1000 });
  const out = [];
  let n = 0;
  for (const h of handles) {
    n++;
    const r = { n, waits: [] };
    try {
      await p.goto("https://x.com/" + h, { waitUntil: "domcontentloaded", timeout: 45000 });
      for (const ms of [1000, 3000, 4000]) {
        await p.waitForTimeout(ms);
        r.waits.push(await p.evaluate(() => {
          const btns = [...document.querySelectorAll('[data-testid$="-unfollow"],[data-testid$="-follow"],[data-testid="placementTracking"] button,[role="button"]')]
            .filter((e) => { const t = (e.getAttribute("aria-label") || e.innerText || ""); return /フォロー|Follow/i.test(t); })
            .slice(0, 6).map((e) => ({ testid: e.getAttribute("data-testid"), aria: (e.getAttribute("aria-label") || "").replace(/@\w+/g, "@x").slice(0, 60), text: (e.innerText || "").trim().slice(0, 20) }));
          return {
            hasMain: !!document.querySelector("main"), hasPrimaryColumn: !!document.querySelector('[data-testid="primaryColumn"]'),
            hasUserName: !!document.querySelector('[data-testid="UserName"]'),
            emptyState: !!document.querySelector('[data-testid="emptyState"]'),
            loginWall: /ログイン|Log in|サインイン/.test((document.body.innerText || "").slice(0, 400)),
            bodyLen: (document.body.innerText || "").length,
            btns,
          };
        }));
      }
      if (n === 1) { await p.screenshot({ path: process.argv[3] + "/x218-1.png" }); r.shot = "x218-1.png"; }
    } catch (e) { r.error = String(e && e.message).slice(0, 160); }
    out.push(r);
  }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify({ rows: out }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# アンフォローのボタンが無い原因（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **押さない。外さない。フォローしない。LLM を呼ばない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① follow-balance.js のボタン探しとページの待ち"
echo
echo '```'
F="$S/follow-balance.js"
if [ -f "$F" ]; then
  grep -n -E 'フォロー中のボタンが無い|follow_btns|empty|unfollow|data-testid|waitForTimeout|waitForSelector|goto\(' "$F" | head -40 | cut -c1-200 | clean
  echo
  ln="$(grep -n 'フォロー中のボタンが無い' "$F" | head -1 | cut -d: -f1)"
  if [ -n "$ln" ]; then
    s=$(( ln > 60 ? ln - 60 : 1 ))
    echo "  --- ${s}〜${ln} 行目"
    sed -n "${s},${ln}p" "$F" | cut -c1-200 | clean
  fi
else
  echo "  **follow-balance.js が無い**"
fi
echo '```'
echo
echo "## ② 今日 失敗した相手のページ（1・4・8 秒待って読む）"
echo
echo '```'
printf '  対象 %s 件\n' "$(grep -c . "$LIST" | head -1)"
if node --check "$RUNNER" 2>/dev/null; then
  rm -f "$OUTDIR"/x218-*.png
  run_limited 150 "$RAW" node "$RUNNER" "$LIST" "$OUTDIR"; printf '  rc=%s\n' "$?"
fi
echo '```'
if [ -s "$RAW" ]; then
  node -e '
    let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
    if (j.fatal) { console.log("**止まった: " + j.fatal + "**"); process.exit(0); }
    for (const r of j.rows || []) {
      console.log("\n### " + r.n + " 件目" + (r.error ? "  **エラー: " + r.error + "**" : "") + (r.shot ? "（画面 `" + r.shot + "`）" : "") + "\n\n```");
      (r.waits || []).forEach((w, i) => console.log(["1 秒", "4 秒", "8 秒"][i] + ": main=" + w.hasMain + " primaryColumn=" + w.hasPrimaryColumn + " UserName=" + w.hasUserName + " emptyState=" + w.emptyState + " loginWall=" + w.loginWall + " 本文長=" + w.bodyLen + "\n     ボタン: " + JSON.stringify(w.btns)));
      console.log("```");
    }
  ' "$RAW" 2>&1 | clean
fi
rm -f "$RUNNER" "$RAW" "$LIST"
echo
echo "**押していない。外していない。フォローしていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
if grep -aq '## ②' "$OUT" 2>/dev/null; then echo "アンフォローのボタンの原因を測った / $(basename "$OUT")"; else echo "**測れていない** / $(basename "$OUT")"; fi
