#!/bin/bash
# **x243 のあと、JAL マイル2倍のスレッドが X に出たかを確かめる。読むだけ。費用 $0。**
#
# **一次情報は投稿 URL の実物だけ**（最上位ルール 11）。`reply_tweet_id` が返っても 404 のことがある（契約書 §3）。
#   ① 自分のプロフィールの直近 8 本から「マイル2倍キャンペーン」の [1/2] を探す
#   ② その permalink を開き、**[1/2] の画像の枚数**と、**直後の自分の返信（[2/2]）の permalink** を time の親 a から取る
#   ③ 画面を撮る
#
# **投稿しない。再送しない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"
RUNNER="$S/.x244-read-$STAMP.js"
RAW="$W/.x244-out-$STAMP.json"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/check-jal-2x-post.md"

hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
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

cat > "$RUNNER" <<'JSEOF'
// x244: 自分のプロフィールの直近の投稿を読む。投稿しない。$0。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const OUTDIR = process.argv[2];
const ME = "heng_ji31590";
(async () => {
  let b;
  try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 160) })); process.exit(0); }
  const ctx = b.contexts()[0];
  const p = await ctx.newPage();
  await p.setViewportSize({ width: 800, height: 1600 });
  const res = { rows: [] };
  try {
    await p.goto("https://x.com/" + ME, { waitUntil: "domcontentloaded", timeout: 45000 });
    await p.waitForTimeout(7000);
    res.rows = await p.evaluate((me) => [...document.querySelectorAll("article")].slice(0, 8).map((a) => {
      const tm = a.querySelector("time");
      const link = tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null;
      const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: link, at: tm ? tm.getAttribute("datetime") : null, text: tx ? tx.innerText.slice(0, 80) : null,
               pinned: /固定|Pinned/.test(a.innerText.slice(0, 40)),
               video: !!a.querySelector('video, [data-testid="videoPlayer"], [data-testid="videoComponent"]'),
               gifBadge: /GIF/.test(a.innerText), photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length };
    }), ME);
    const hit = res.rows.find((r) => r.text && /マイル2倍キャンペーン/.test(r.text));
    res.hit = hit || null;
    if (hit && hit.href) {
      const t1 = (hit.href.match(/status\/(\d+)/) || [])[1];
      await p.goto("https://x.com" + hit.href, { waitUntil: "domcontentloaded", timeout: 45000 });
      await p.waitForTimeout(7000);
      res.thread = await p.evaluate(([t1, me]) => [...document.querySelectorAll("article")].slice(0, 6).map((a) => {
        const tm = a.querySelector("time");
        const href = tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null;
        const tx = a.querySelector('[data-testid="tweetText"]');
        return { href, self: !!(href && href.includes("/status/" + t1)) || (!href && !!a.querySelector('[data-testid="tweetText"]')),
                 mine: !!(href && href.startsWith("/" + me + "/status/")),
                 photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length,
                 text: tx ? tx.innerText.slice(0, 60) : null };
      }), [t1, ME]);
      const a = await p.$("article");
      if (a) { await a.screenshot({ path: OUTDIR + "/x244-post.png" }); res.shot = "x244-post.png"; }
      await p.screenshot({ path: OUTDIR + "/x244-thread.png", fullPage: false }); res.shot2 = "x244-thread.png";
    }
  } catch (e) { res.error = String(e && e.message).slice(0, 200); }
  try { await p.close(); } catch (e) {}
  console.log(JSON.stringify(res));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF

{
echo "# JAL マイル2倍のスレッドは X に出たか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **投稿しない。再送しない。キューを書き換えない（\$0／回・\$0／日・\$0／月）。**"
echo
echo "## ① 自分のプロフィールの直近 8 本"
echo
echo '```'
CK="$(node --check "$RUNNER" 2>&1)"; CRC=$?
printf '  node --check rc=%s %s\n' "$CRC" "$(printf '%s' "$CK" | head -1 | cut -c1-120)"
if [ "$CRC" -eq 0 ]; then
  rm -f "$OUTDIR"/x244-*.png
  run_limited 150 "$RAW" node "$RUNNER" "$OUTDIR"; printf '  rc=%s\n' "$?"
fi
echo '```'
rm -f "$RUNNER"
if [ -s "$RAW" ]; then
  node -e '
    let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); } catch (e) { console.log("**JSON として読めない**"); process.exit(0); }
    if (j.fatal) { console.log("\n**止まった: " + j.fatal + "**"); process.exit(0); }
    const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 16).replace("T", " ") : "?";
    for (const r of j.rows || []) console.log("- " + jst(r.at) + "  " + (r.pinned ? "（固定）" : "") + (r.href || "?") + "  動画:" + r.video + " GIF表示:" + r.gifBadge + " 画像:" + r.photos + "  「" + String(r.text || "").replace(/\n/g, " ") + "」");
    console.log("\n**判定: " + (j.hit ? "出ている → https://x.com" + j.hit.href + "（画像: " + j.hit.photos + " 枚）" : "直近 8 本に「マイル2倍キャンペーン」は無い") + "**");
    for (const r of j.thread || []) console.log("  - " + (r.href || "（本体・href なし）") + (r.mine ? " 自分" : "") + " 画像:" + r.photos + " 「" + String(r.text || "").replace(/\n/g, " ") + "」");
    if (j.shot) console.log("\n画面: `" + j.shot + "` / `" + (j.shot2 || "-") + "`");
    if (j.error) console.log("\n**エラー: " + j.error + "**");
  ' "$RAW" 2>&1 | clean
fi
rm -f "$RAW"
echo
echo "**投稿していない。再送していない。キューを書き換えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }
if grep -q '出ている →' "$OUT" 2>/dev/null; then echo "JAL マイル2倍のスレッドは X に出ている / $(basename "$OUT")"
else echo "**X 上に見つからない。レポートを確認すること** / $(basename "$OUT")"; fi
