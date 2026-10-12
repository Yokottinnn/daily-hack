#!/bin/bash
# **他のアカウントの「青バッジ（認証）を付けた」報告投稿を集めて読む。何も押さない。費用 $0。**
#
# ## なぜ（2026-10-12）
#
#   利用者が Premium を購入し、報告投稿を**急ぎで**出したい。
#   「既存のいろんなアカウントの投稿内容を分析しつつ、画像や動画の作成も合わせて」と指示された。
#   X の検索（話題・最新）で報告投稿を集め、**本文・表示回数・いいね・画像か動画か**を並べる。
#
# **スクロールだけ。LLM を呼ばない（$0／回・$0／日・$0／月）。** 3 分で終わる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/badge-announce-posts.md"
PROBE="$W/.x271-probe.js"
RAW="$W/.x271-out.json"
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
const [outdir] = process.argv.slice(2);
const QUERIES = [
  "青バッジ ついた lang:ja min_faves:20",
  "認証バッジ 付きました lang:ja min_faves:20",
  "X Premium 加入 青バッジ lang:ja min_faves:10",
  "青バッジ 付けました lang:ja",
  "青バッジ フォロワー 収益化 lang:ja min_faves:10",
];
const num = (s) => { if (!s) return 0; const m = String(s).replace(/,/g, "").match(/([\d.]+)\s*(万|K|M)?/); if (!m) return 0; let n = parseFloat(m[1]); if (m[2] === "万") n *= 1e4; if (m[2] === "K") n *= 1e3; if (m[2] === "M") n *= 1e6; return Math.round(n); };
(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const page = await b.contexts()[0].newPage();
  await page.setViewportSize({ width: 1280, height: 1600 });
  const all = new Map();
  const t0 = Date.now();
  for (const q of QUERIES) {
    for (const f of ["top", "live"]) {
      if (Date.now() - t0 > 150000) break;
      try {
        await page.goto("https://x.com/search?q=" + encodeURIComponent(q) + "&src=typed_query&f=" + f, { waitUntil: "domcontentloaded", timeout: 30000 });
        await page.waitForTimeout(4000);
        for (let i = 0; i < 4; i++) {
          const rows = await page.$$eval("article", (as) => as.map((a) => {
            const link = [...a.querySelectorAll('a[href*="/status/"]')].map((x) => x.getAttribute("href")).find((h) => /\/status\/\d+$/.test(h)) || "";
            const g = (t) => { const e = a.querySelector('[data-testid="' + t + '"]'); return e ? (e.getAttribute("aria-label") || e.innerText) : ""; };
            const views = [...a.querySelectorAll('a[href$="/analytics"]')].map((x) => x.getAttribute("aria-label") || x.innerText)[0] || "";
            return {
              link, text: (a.querySelector('[data-testid="tweetText"]') || {}).innerText || "",
              time: (a.querySelector("time") || {}).getAttribute ? a.querySelector("time").getAttribute("datetime") : "",
              likes: g("like") || g("unlike"), reposts: g("retweet"), replies: g("reply"), views,
              photos: a.querySelectorAll('[data-testid="tweetPhoto"] img').length,
              video: !!a.querySelector('[data-testid="videoPlayer"], video'),
              gif: !!a.querySelector('[data-testid="gifPlayer"]') || /GIF/.test(a.innerText.slice(-200)),
              verified: !!a.querySelector('[data-testid="icon-verified"]'),
            };
          }));
          for (const r of rows) if (r.link && !all.has(r.link)) all.set(r.link, { ...r, q, f });
          await page.mouse.wheel(0, 2600); await page.waitForTimeout(1500);
        }
      } catch (e) {}
    }
  }
  await page.close().catch(() => {});
  const list = [...all.values()].map((r) => ({ ...r, likesN: num(r.likes), viewsN: num(r.views) })).sort((a, b) => b.likesN - a.likesN);
  console.log(JSON.stringify({ n: list.length, list: list.slice(0, 40) }));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
PROBEJS

{
echo "# 他アカウントの青バッジ報告投稿（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も押していない）"
echo
cd "$W" && node "$PROBE" "$OUTDIR" > "$RAW" 2>&1
node -e '
let j; try { j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8").trim().split("\n").pop()); } catch (e) { console.log(require("fs").readFileSync(process.argv[1], "utf8").slice(0, 2000)); process.exit(0); }
if (j.fatal) { console.log("致命的: " + j.fatal); process.exit(0); }
console.log("集めた投稿 " + j.n + " 件（いいね順に上位 40）\n");
j.list.forEach((r, i) => {
  const media = [r.photos ? "画像" + r.photos : "", r.video ? "動画" : "", r.gif ? "GIF" : ""].filter(Boolean).join("+") || "文字のみ";
  console.log("### " + (i + 1) + ". いいね " + r.likesN + " ／ 表示 " + (r.viewsN || "?") + " ／ " + media + " ／ " + (r.time || "").slice(0, 10) + (r.verified ? " ／ 投稿者は認証済み" : "") + "\n");
  console.log("```text\n" + r.text.slice(0, 500) + "\n```\n");
});
' "$RAW" | secrets | hide
rm -f "$PROBE" "$RAW"
echo "**何も押していない（スクロールだけ）。他人の ID は伏せた。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "青バッジ報告投稿を集めた / $(basename "$OUT")"
