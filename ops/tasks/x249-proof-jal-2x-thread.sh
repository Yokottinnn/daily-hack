#!/bin/bash
# **JAL マイル2倍のスレッドが出ていることの証跡を取る。読むだけ。費用 $0。**
#
# 利用者の指示（2026-10-04 20 時台）:
#   > さっきの投稿がちゃんと終わってるのかくにんしてちゃんと証跡を見せてから次行って　仕事を雑にするな
#
#   ① [1/2] の permalink を開き、本文の全文・画像の枚数・画像の URL を取り、画面を撮る
#   ② [2/2] の permalink を開き、本文の全文・「返信先」・記事リンクを取り、画面を撮る
#   ③ [1/2] のスレッド画面（[2/2] がぶら下がっていること）を撮る
#   ④ キューのエントリの状態（posted・auto_publish・両方の ID）を出す
#
# **投稿しない。キューを書き換えない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/proof-jal-2x-thread.md"
PROBE="$W/.x249-probe.js"
RAW="$W/.x249-out.json"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261004-jal-2x"
T1="2106699830819258421"
T2="2106703392739610923"
ME="heng_ji31590"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g; s#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g"; }

cat > "$PROBE" <<'PROBEJS'
// x249: 2 本の permalink を開いて中身を読み、画面を撮る。投稿しない
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [t1, t2, me, outdir] = process.argv.slice(2);
const read = async (page, id) => {
  await page.goto("https://x.com/" + me + "/status/" + id, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(6000);
  return await page.$$eval('article[data-testid="tweet"]', (arts, id) => arts.slice(0, 6).map((a) => {
    const t = a.querySelector("time"); const p = t && t.closest("a");
    const tx = a.querySelector('[data-testid="tweetText"]');
    const imgs = [...a.querySelectorAll('[data-testid="tweetPhoto"] img')].map((i) => i.getAttribute("src"));
    const links = [...a.querySelectorAll('[data-testid="tweetText"] a')].map((l) => l.innerText);
    return { href: p ? p.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null,
             text: tx ? tx.innerText : null, photos: imgs.length, imgs, links,
             replyingTo: /返信先|Replying to/.test(a.innerText.slice(0, 200)) };
  }), id);
};
(async () => {
  const r = {};
  let b;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await b.contexts()[0].newPage();
    await page.setViewportSize({ width: 900, height: 1500 });
    r.p1 = await read(page, t1);
    await page.screenshot({ path: outdir + "/x249-thread.png" });
    const a1 = await page.$('article[data-testid="tweet"]');
    if (a1) await a1.screenshot({ path: outdir + "/x249-post1.png" });
    r.p2 = await read(page, t2);
    const arts = await page.$$('article[data-testid="tweet"]');
    for (const a of arts) {
      const h = await a.$eval("time", (t) => t.closest("a") ? t.closest("a").getAttribute("href") : "").catch(() => "");
      if (!h || h.includes("/status/" + t2)) { await a.screenshot({ path: outdir + "/x249-post2.png" }); break; }
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e && e.message).slice(0, 200); }
  console.log(JSON.stringify(r));
  process.exit(0);
})();
PROBEJS

{
echo "# JAL マイル2倍のスレッドの証跡（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
rm -f "$OUTDIR"/x249-*.png
cd "$W" && node "$PROBE" "$T1" "$T2" "$ME" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log("**読めない**"); process.exit(0); }
if (j.error) console.log("**エラー: " + j.error + "**\n");
const jst = (s) => s ? new Date(new Date(s).getTime() + 9 * 3600e3).toISOString().slice(0, 19).replace("T", " ") + " JST" : "?";
const show = (title, rows, id) => {
  console.log("## " + title + "\n");
  for (const r of rows || []) {
    const self = !r.href || r.href.includes("/status/" + id);
    console.log("- " + (self ? "**この投稿**" : "その他") + "  https://x.com" + (r.href || "?") + "  " + jst(r.at) + "  画像 " + r.photos + " 枚" + (r.replyingTo ? "・返信" : ""));
    if (self) {
      console.log("\n```\n" + (r.text || "（本文が読めない）") + "\n```\n");
      if (r.imgs.length) console.log("画像: " + r.imgs.map((u) => (u || "").split("?")[0]).join(" , ") + "\n");
      if (r.links.length) console.log("本文中のリンク: " + r.links.join(" , ") + "\n");
    }
  }
  console.log("");
};
show("① [1/2] " + process.argv[2], j.p1, process.argv[2]);
show("② [2/2] " + process.argv[3], j.p2, process.argv[3]);
' "$RAW" "$T1" "$T2" 2>&1 | hide
echo "## ③ 画面"
echo
ls -1 "$OUTDIR"/x249-*.png 2>/dev/null | xargs -n1 basename | sed 's/^/- /'
echo
echo "## ④ キュー"
echo
echo '```'
node -e '
const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const e = (q.queue || []).find((x) => x && x.id === process.argv[2]);
console.log(e ? JSON.stringify({ id: e.id, status: e.status, auto_publish: e.auto_publish, x_tweet_id: e.x_tweet_id,
  chain: (e.thread_chain || []).map((c) => ({ role: c.role, x_tweet_id: c.x_tweet_id || null })) }, null, 1) : "（無い）");
' "$QJSON" "$ID" 2>&1
echo '```'
echo
echo "**投稿していない。キューを書き換えていない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$RAW"
echo "JAL スレッドの証跡を取った / $(basename "$OUT")"
