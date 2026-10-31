#!/bin/bash
# **浜離宮の告知 [1/2]（2116399877550936189）の本文が最後まで出ているかを読む（x390）。読むだけ・$0。**
# x389 の確認で、投稿ページの本文が 534 字しか読めなかった（元は 1,376 字）。「さらに表示」で畳まれているだけか、途中で切れたかを確かめる。
set -uo pipefail
W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/x390-hamarikyu-fulltext.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
WANT="$(git -C "$REPO" show origin/main:scripts/image-review/posts.json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).hamarikyu[0]))')"
PROBE="$W/.x390-probe.js"
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
setTimeout(() => { console.log(JSON.stringify({ error: "90 秒で打ち切った" })); process.exit(2); }, 90000).unref();
const want = process.argv[2];
(async () => { const r = {}; let page; try {
  const b = await chromium.connectOverCDP(process.env.CHROME_CDP_URL || "http://127.0.0.1:18810", { timeout: 30000 });
  page = await b.contexts()[0].newPage();
  await page.goto("https://x.com/heng_ji31590/status/2116399877550936189", { waitUntil: "domcontentloaded", timeout: 40000 });
  await page.waitForSelector('article[data-testid="tweet"] [data-testid="tweetText"]', { timeout: 20000 }).catch(() => {});
  await page.waitForTimeout(4000);
  const a = page.locator('article[data-testid="tweet"]').first();
  r.before = await a.locator('[data-testid="tweetText"]').innerText().then((t) => t.length).catch(() => -1);
  const more = a.locator('[data-testid="tweet-text-show-more-link"]');
  r.showMore = await more.count();
  if (r.showMore) { await more.first().click().catch(() => {}); await page.waitForTimeout(3000); }
  const got = await page.locator('article[data-testid="tweet"]').first().locator('[data-testid="tweetText"]').innerText().catch(() => "");
  const n = (s) => s.replace(/\s+/g, "");
  r.after = got.length; r.want = want.length;
  r.same = n(got) === n(want);
  if (!r.same) { const A = n(got), B = n(want); let i = 0; while (i < A.length && A[i] === B[i]) i++; r.firstDiffAt = i; r.got_around = A.slice(Math.max(0, i - 20), i + 30); r.want_around = B.slice(Math.max(0, i - 20), i + 30); }
  r.tail = got.slice(-60);
} catch (e) { r.error = String(e && e.message).slice(0, 200); }
if (page) await page.close().catch(() => {});
console.log(JSON.stringify(r)); process.exit(0); })();
PJS
{
echo "# 浜離宮 [1/2] の本文を最後まで読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"; echo '```'
cd "$W" && "$NODE_BIN" "$PROBE" "$WANT" 2>&1 | tail -1
echo '```'
echo "before＝開いた直後の本文の長さ／showMore＝「さらに表示」の数／after＝押したあとの長さ／want＝レビューページの文面の長さ／same＝空白を除いて一致したか"
echo "**読んだだけ（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
rm -f "$PROBE"
echo "x390 / $(basename "$OUT")"
