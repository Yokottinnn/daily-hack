#!/bin/bash
# x399（2026-11-01・読むだけ・$0）: 利用者「教えた投稿をしているアカウントが実際にどういう追加投稿をスレッドでしているのかをちゃんとしらべて模倣してほしい」
# 対象 @Jdj5VLZbsB21682（11/1 16:56「伸ばしたいへ。伸ばすテクニックです」）。投稿一覧・返信を含む一覧・元の投稿のスレッドを読み、
# 自分の投稿を引用したもの・スレッドに足したもの・リプ欄に貼ったリンクを拾う。画像は見た目を撮る。
# **投稿しない。いいねもリポストもしない。LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; OUTDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$OUTDIR/x399-booster-account.md"; RAW="$W/.x399-raw.json"; RUNNER="$W/scripts/.x399-read.js"
cat > "$RUNNER" <<'JSEOF'
const { chromium } = require("playwright-core");
const fs = require("fs"), path = require("path");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const H = "Jdj5VLZbsB21682", OUTDIR = process.argv[2];
const pick = (s, re) => { const m = String(s || "").match(re); return m ? Number(m[1].replace(/,/g, "")) : null; };
async function grab(p, url, scrolls, tag) {
  await p.goto(url, { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(6000);
  const seen = new Map(); let shot = 0;
  for (let k = 0; k <= scrolls; k++) {
    const arts = await p.$$("article");
    for (const a of arts) {
      const r = await a.evaluate((el) => {
        const ids = [...el.querySelectorAll('a[href*="/status/"]')].map((x) => (x.getAttribute("href") || "").match(/^\/([^/]+)\/status\/(\d+)$/)).filter(Boolean);
        const main = ids[0]; const tx = el.querySelectorAll('[data-testid="tweetText"]');
        const g = el.querySelector('[role="group"][aria-label]');
        const sc = el.querySelector('[data-testid="socialContext"]');
        const qt = el.querySelector('div[role="link"]');
        return { author: main ? main[1] : null, id: main ? main[2] : null, at: el.querySelector("time") ? el.querySelector("time").getAttribute("datetime") : null,
          social: sc ? sc.innerText : "", text: tx[0] ? tx[0].innerText : "", quoteText: tx[1] ? tx[1].innerText.slice(0, 300) : "",
          quoteLink: qt ? ([...qt.querySelectorAll('a[href*="/status/"]')].map((x) => x.getAttribute("href"))[0] || "") : "",
          replyingTo: [...el.querySelectorAll("div")].map((d) => d.innerText).find((t) => /^返信先:|^Replying to/.test(t || "")) || "",
          label: g ? g.getAttribute("aria-label") : "", images: el.querySelectorAll('img[src*="pbs.twimg.com/media"]').length,
          links: [...(tx[0] ? tx[0].querySelectorAll("a[href]") : [])].map((x) => x.href).slice(0, 6) };
      });
      if (!r.id || seen.has(r.id)) continue;
      r.views = pick(r.label, /([\d,]+)\s*件の表示/); r.likes = pick(r.label, /([\d,]+)\s*件のいいね/); r.bookmarks = pick(r.label, /([\d,]+)\s*件のブックマーク/);
      if (r.author && r.author.toLowerCase() === H.toLowerCase() && (r.images || r.quoteText) && shot < 8) {
        const f = path.join(OUTDIR, "x399-" + tag + "-" + (++shot) + ".png"); try { await a.screenshot({ path: f }); r.png = path.basename(f); } catch (e) {}
      }
      seen.set(r.id, r);
    }
    await p.evaluate(() => window.scrollBy(0, 1400)); await p.waitForTimeout(2200);
  }
  return [...seen.values()];
}
(async () => {
  const out = {};
  let b; try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); } catch (e) { console.log(JSON.stringify({ fatal: String(e.message).slice(0, 150) })); process.exit(0); }
  const p = await b.contexts()[0].newPage(); await p.setViewportSize({ width: 700, height: 1800 });
  try { out.thread = await grab(p, "https://x.com/" + H + "/status/2116801543068614881", 3, "thread"); } catch (e) { out.thread_err = String(e.message).slice(0, 150); }
  try { out.posts = await grab(p, "https://x.com/" + H, 6, "posts"); } catch (e) { out.posts_err = String(e.message).slice(0, 150); }
  try { out.replies = await grab(p, "https://x.com/" + H + "/with_replies", 6, "replies"); } catch (e) { out.replies_err = String(e.message).slice(0, 150); }
  await p.close().catch(() => {});
  console.log(JSON.stringify(out)); process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 200) })); process.exit(0); });
JSEOF
{
echo "# お手本のアカウントは、伸ばすために実際に何を重ねているか（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
cd "$W" && node "$RUNNER" "$OUTDIR" > "$RAW" 2>&1
node -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
if(j.fatal){console.log("止まった: "+j.fatal);process.exit(0);}
const jst=(s)=>s?new Date(new Date(s).getTime()+9*3600e3).toISOString().slice(5,16).replace("T"," "):"?";
for(const k of ["thread","posts","replies"]){ const xs=j[k]||[]; console.log("\n## "+k+"（"+xs.length+" 件）"+(j[k+"_err"]?" エラー: "+j[k+"_err"]:""));
  for(const r of xs){ const own=(r.author||"").toLowerCase()==="jdj5vlzbsb21682";
    console.log("\n### "+(own?"本人":"他人")+" "+r.id+" "+jst(r.at)+" 表示 "+(r.views??"?")+" いいね "+(r.likes??"?")+" 画像 "+r.images+(r.png?" 写真 "+r.png:"")+(r.social?" ["+r.social+"]":""));
    if(!own){continue;}
    if(r.replyingTo) console.log("返信先: "+r.replyingTo.slice(0,80));
    console.log("```text\n"+(r.text||"(本文なし)")+"\n```");
    if(r.quoteText||r.quoteLink) console.log("**引用している投稿** "+r.quoteLink+"\n```text\n"+r.quoteText+"\n```");
    if(r.links.length) console.log("リンク: "+r.links.join(" "));
  }}' "$RAW" 2>&1 | perl -pe 's/@(?!Jdj5VLZbsB21682\b|heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/gi'
echo; echo "**投稿していない。LLM を呼んでいない（\$0）。**"
} > "$OUT" 2>&1
rm -f "$RUNNER" "$RAW"
head -c 300 "$OUT"; exit 0
