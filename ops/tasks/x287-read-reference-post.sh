#!/bin/bash
# **利用者が「学んで型を記録して」と渡した投稿を読む。何も押さない。費用 $0。**
#
# 対象: https://x.com/kumataro_design/status/2109455453554106815（2026-10-13 に利用者が共有）
# 読むもの: 本文（全文）・同じ投稿者のスレッドの続き・画像の枚数と縦横・動画の有無・表示/いいね/RT/ブックマーク・投稿時刻
# **他人の画像は保存しない**（公開リポジトリに載るため）。画像は枚数・縦横・ALT だけ記録する。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/reference-post.md"
P="$W/.x287-probe.js"
cat > "$P" <<'JS'
const { chromium } = require("playwright-core");
(async () => {
  const b = await chromium.connectOverCDP(process.env.CDP_URL || "http://127.0.0.1:18810", { timeout: 60000 });
  const p = await b.contexts()[0].newPage(); await p.setViewportSize({ width: 1000, height: 2400 });
  await p.goto("https://x.com/kumataro_design/status/2109455453554106815", { waitUntil: "domcontentloaded", timeout: 40000 });
  await p.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }); await p.waitForTimeout(5000);
  for (let i = 0; i < 4; i++) { await p.mouse.wheel(0, 1800); await p.waitForTimeout(1500); }
  const r = await p.evaluate(() => [...document.querySelectorAll('article[data-testid="tweet"]')].slice(0, 12).map((a) => {
    const t = a.querySelector("time"); const link = t && t.closest("a");
    const g = (id) => { const e = a.querySelector('[data-testid="' + id + '"]'); return e ? (e.getAttribute("aria-label") || e.innerText) : null; };
    const user = (a.querySelector('[data-testid="User-Name"]') || {}).innerText || "";
    return { href: link ? link.getAttribute("href") : null, at: t ? t.getAttribute("datetime") : null, author: user.split("\n").slice(0, 2).join(" "),
      text: (a.querySelector('[data-testid="tweetText"]') || {}).innerText || "",
      photos: [...a.querySelectorAll('[data-testid="tweetPhoto"] img')].map((i) => ({ w: i.naturalWidth, h: i.naturalHeight, alt: i.getAttribute("alt") })),
      video: !!a.querySelector("video"), card: !!a.querySelector('[data-testid="card.wrapper"]'),
      quote: !!a.querySelector('[data-testid="quoteTweet"]') || /引用/.test(a.innerText.slice(0, 50)),
      reply: g("reply"), retweet: g("retweet"), like: g("like") || g("unlike"), bookmark: g("bookmark") || g("removeBookmark"),
      views: ([...a.querySelectorAll('a[href$="/analytics"]')].map((x) => x.getAttribute("aria-label") || x.innerText)[0]) || null };
  }));
  await p.close(); console.log(JSON.stringify(r)); process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ error: String(e.message).slice(0, 200) })); process.exit(0); });
JS
{
echo "# 参考投稿の中身（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も押していない・画像は保存していない）"
echo
cd "$W" && node "$P" 2>&1 | tail -1 | node -e '
let s=require("fs").readFileSync(0,"utf8"); let j; try{ j=JSON.parse(s);}catch(e){ console.log(s); process.exit(0);}
if(j.error){ console.log("エラー: "+j.error); process.exit(0);}
j.forEach((x,i)=>{ console.log("## "+(i+1)+". "+(x.author||"")+" "+(x.at||"")+" "+(x.href||""));
  console.log("\n- 画像 "+x.photos.length+" 枚 "+x.photos.map(p=>p.w+"x"+p.h).join(", ")+" ／ 動画 "+x.video+" ／ カード "+x.card+" ／ 引用 "+x.quote);
  console.log("- 返信 "+x.reply+" ／ RT "+x.retweet+" ／ いいね "+x.like+" ／ ブックマーク "+x.bookmark+" ／ 表示 "+x.views);
  x.photos.forEach((p,k)=>{ if(p.alt && p.alt!=="画像") console.log("- ALT "+(k+1)+": "+p.alt.slice(0,300)); });
  console.log("\n```text\n"+x.text+"\n```\n"); });'
rm -f "$P"
echo "**何も押していない。画像は保存していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "参考投稿を読んだ / $(basename "$OUT")"
