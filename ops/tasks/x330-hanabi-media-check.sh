#!/bin/bash
# **花火の告知（2113405143467352421）に画像 4 枚が付いているかを、投稿のページで数える（x330）。読むだけ。費用 $0。**
# x329 でプロフィールの一覧に「画像/動画 0」と出た。一覧の数え方の誤りか、本当に付いていないかを見分ける。
# **再送しない・消さない・画面は撮らない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/hanabi-media.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x330-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => { const r = {}; try {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); const page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/heng_ji31590/status/2113405143467352421", { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 20000 }).catch(() => {}); await page.waitForTimeout(6000);
  r.main = await page.$$eval('article[data-testid="tweet"]', (as) => { const a = as[0]; if (!a) return null; const tx = a.querySelector('[data-testid="tweetText"]');
    return { photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length, imgs: Array.from(a.querySelectorAll('img[src*="pbs.twimg.com/media"]')).length,
      len: tx ? tx.innerText.length : 0, head: tx ? tx.innerText.slice(0, 30) : "", tail: tx ? tx.innerText.slice(-30) : "" }; });
  await page.close().catch(() => {}); } catch (e) { r.error = String(e && e.message).slice(0, 200); } console.log(JSON.stringify(r)); process.exit(0); })();
PJS
cd "$W" && "$NODE_BIN" "$PROBE" > "$W/.x330.json" 2>&1
{
echo "# 花火の告知に画像は付いているか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo '```'
tail -n 1 "$W/.x330.json" | cut -c1-600 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'
echo '```'
echo
echo "## 予約時に取り出した画像（キューが指す実ファイル）"
echo '```'
ls -la "$W/data/x-tokyo-bay-hanabi-weekend/" 2>&1 | tail -n 6
"$NODE_BIN" -e 'const q=require(process.argv[1]);const r=(q.queue||q).find(x=>x&&x.id==="blog-promo-20261023-tokyo-bay-hanabi");console.log(r?("image_path="+r.image_path+"\nchain0.image_path="+(r.thread_chain&&r.thread_chain[0]&&r.thread_chain[0].image_path)):"entry なし")' "$W/data/post_queue.json" 2>&1 | sed "s#$HOME#~#g"
echo '```'
echo
echo "## 投稿の本体（post-via-playwright.js）が画像を付けた記録（ログの該当行）"
echo '```'
grep -n -iE 'attach|image|media|upload' "$W/logs/publish-hanabi-oneshot.log" 2>/dev/null | tail -n 10 | cut -c1-240
echo '```'
echo "**再送していない・消していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE" "$W/.x330.json"
echo "x330 / $(basename "$OUT")"
