#!/bin/bash
# **Amazon と楽天の比較・プライム感謝祭の投稿で、反応の多いものを X の「話題」から集める。何も押さない。費用 $0。**
# 利用者（2026-10-17）: 「曖昧な書き方とか主語や補語がない文章が多すぎる／読者の視点を完全に無視している／
#   エンゲージメントの高い投稿を学習してちゃんと日本語として伝わるようにしてほしい」
# 3 つの検索語の「話題」タブから、本文・いいね・リポスト・ブックマーク・表示を読む。他人のハンドルは伏せる。
# LLM を呼ばない（$0／回・$0／日・$0／月）。
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/engaging-compare-posts.md"
P="$W/.x305.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
const QS = ["Amazon 楽天 どっち ポイント", "プライム感謝祭 楽天", "楽天 Amazon 比較 お得"];
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const all = new Map();
  for (const q of QS) {
    try {
      await p.goto("https://x.com/search?q=" + encodeURIComponent(q + " lang:ja") + "&src=typed_query", { waitUntil: "domcontentloaded", timeout: 30000 });
      await p.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 });
      for (let k = 0; k < 6; k++) {
        const rows = await p.evaluate(() => [...document.querySelectorAll('article[data-testid="tweet"]')].map((a) => {
          const t = a.querySelector('[data-testid="tweetText"]');
          const g = a.querySelector('[role="group"]');
          const link = [...a.querySelectorAll('a[href*="/status/"]')].map((x) => x.getAttribute("href")).find((h) => /\/status\/\d+$/.test(h));
          const imgs = a.querySelectorAll('[data-testid="tweetPhoto"]').length;
          const time = (a.querySelector("time") || {}).getAttribute ? a.querySelector("time").getAttribute("datetime") : null;
          return { link, text: t ? t.innerText : "", stats: g ? g.getAttribute("aria-label") : "", imgs, time };
        }));
        for (const r of rows) if (r.link && !all.has(r.link)) all.set(r.link, { ...r, q });
        await p.evaluate(() => window.scrollBy(0, 2200)); await p.waitForTimeout(1500);
      }
    } catch (e) { console.error("query fail " + q + ": " + e.message); }
  }
  await p.close();
  const num = (s, re) => { const m = (s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : 0; };
  const out = [...all.values()].map((r) => ({ ...r, like: num(r.stats, /([\d,]+)\s*件のいいね/), rp: num(r.stats, /([\d,]+)\s*件のリポスト/), bm: num(r.stats, /([\d,]+)\s*件のブックマーク/), view: num(r.stats, /([\d,]+)\s*件の表示/) }));
  out.sort((a, b) => (b.like + b.rp * 2 + b.bm) - (a.like + a.rp * 2 + a.bm));
  console.log(JSON.stringify(out.slice(0, 18)));
  process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# Amazon と楽天の比較で反応の多い投稿（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・押していない）"
echo
(cd "$W" && node "$P" 2>/dev/null | tail -1) | node -e '
let s=require("fs").readFileSync(0,"utf8");try{const j=JSON.parse(s);if(j.error){console.log("読めなかった: "+j.error);process.exit(0)}
j.forEach((r,i)=>{console.log("## "+(i+1)+"．いいね "+r.like+" / RP "+r.rp+" / ブクマ "+r.bm+" / 表示 "+r.view+" / 画像 "+r.imgs+" 枚 / "+(r.time||"").slice(0,10)+"（検索語: "+r.q+"）");
console.log("```");console.log(r.text.replace(/@[A-Za-z0-9_]{2,15}/g,"@<伏せ>"));console.log("```");console.log("")})}catch(e){console.log(s.slice(0,500))}'
echo "**押していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$P"
echo "比較の投稿で反応の多いものを集めた / $(basename "$OUT")"
