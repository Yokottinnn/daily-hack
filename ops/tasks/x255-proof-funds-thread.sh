#!/bin/bash
# **FUNDS 紹介のスレッドが出ていることの証跡を取る。読むだけ。費用 $0。**
#
# x254 のあと（同じ周回で走る）。**返り値の ID は信用しない**（契約書 §3）。
#   ① 自分のプロフィールから「Funds（ファンズ）」を含む直近の投稿（[1/2]）を探す
#   ② その permalink を開き、本文・画像の枚数・ぶら下がっている自分の返信（[2/2]）の permalink を取る
#   ③ 画面を撮る（reports/x255-thread.png / x255-post1.png）
#   ④ キューのエントリの状態を出す
#
# **投稿しない。再送しない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/proof-funds-thread.md"
PROBE="$W/.x255-probe.js"
RAW="$W/.x255-out.json"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261010-funds"
ME="heng_ji31590"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g; s#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g"; }

cat > "$PROBE" <<'PROBEJS'
// x255: プロフィールから FUNDS の投稿を探し、permalink を開いて読む。投稿しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [me, outdir] = process.argv.slice(2);
const read = (page) => page.$$eval('article[data-testid="tweet"]', (arts) => arts.slice(0, 6).map((a) => {
  const t = a.querySelector("time"); const p = t && t.closest("a");
  const tx = a.querySelector('[data-testid="tweetText"]');
  return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null,
           text: tx ? tx.innerText : null, photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length };
}));
(async () => {
  const r = {};
  let b;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 900, height: 1700 });
    await page.goto("https://x.com/" + me, { waitUntil: "domcontentloaded", timeout: 40000 });
    await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {});
    await page.waitForTimeout(6000);
    r.profile = (await read(page)).map((x) => ({ href: x.href, at: x.at, photos: x.photos, head: (x.text || "").slice(0, 40) }));
    const hit = (await read(page)).find((x) => x.text && /Funds（ファンズ）/.test(x.text) && /2,000円/.test(x.text));
    if (hit && hit.href) {
      r.t1 = (hit.href.match(/status\/(\d+)/) || [])[1];
      await page.goto("https://x.com" + hit.href, { waitUntil: "domcontentloaded", timeout: 40000 });
      await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => {});
      await page.waitForTimeout(7000);
      r.thread = await read(page);
      await page.screenshot({ path: outdir + "/x255-thread.png" });
      const a1 = await page.$('article[data-testid="tweet"]');
      if (a1) await a1.screenshot({ path: outdir + "/x255-post1.png" });
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS

{
echo "# FUNDS 紹介のスレッドの証跡（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/x255-*.png
cd "$W" && node "$PROBE" "$ME" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.error) console.log("**エラー: " + j.error + "**\n");
const me = process.argv[2];
const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 19).replace("T", " ") + " JST" : "?";
console.log("## ① プロフィールの直近\n");
for (const x of j.profile || []) console.log("- " + jst(x.at) + "  " + (x.href || "?") + "  画像 " + x.photos + "  「" + x.head.replace(/\n/g, " ") + "」");
if (!j.t1) { console.log("\n**判定: プロフィールに FUNDS の投稿が見つからない**"); process.exit(0); }
console.log("\n## ② スレッド\n");
let self = null; const replies = [];
for (const x of j.thread || []) {
  if (!x.href || x.href.includes("/status/" + j.t1)) self = x;
  else if (x.href.startsWith("/" + me + "/status/")) replies.push(x);
}
if (self) console.log("### [1/2] https://x.com/" + me + "/status/" + j.t1 + "  " + jst(self.at) + "  画像 " + self.photos + " 枚\n\n```\n" + (self.text || "") + "\n```\n");
for (const x of replies) console.log("### [2/2] https://x.com" + x.href + "  " + jst(x.at) + "  画像 " + x.photos + " 枚\n\n```\n" + (x.text || "") + "\n```\n");
console.log("**判定: [1/2] " + (self ? "在る（画像 " + self.photos + " 枚）" : "無い") + " ／ [2/2] " + (replies.length ? "在る → https://x.com" + replies[0].href : "**見えない**") + "**");
' "$RAW" "$ME" 2>&1 | hide
rm -f "$PROBE" "$RAW"
echo
echo "## ③ 画面"
echo
ls -1 "$OUTDIR"/x255-*.png 2>/dev/null | xargs -n1 basename | sed 's/^/- /'
echo
echo "## ④ キュー"
echo
echo '```'
node -e '
const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const e = (q.queue || []).find((x) => x && x.id === process.argv[2]);
console.log(e ? JSON.stringify({ id: e.id, status: e.status, auto_publish: e.auto_publish, x_tweet_id: e.x_tweet_id || null,
  chain: (e.thread_chain || []).map((c) => ({ role: c.role, x_tweet_id: c.x_tweet_id || null })) }, null, 1) : "（無い）");
' "$QJSON" "$ID" 2>&1
echo '```'
echo
echo "**投稿していない。キューを書き換えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "FUNDS スレッドの証跡を取った / $(basename "$OUT")"
