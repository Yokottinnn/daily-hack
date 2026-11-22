#!/bin/bash
# x540（2026-11-22・読むだけ・$0）: CAMP の予約投稿（x533）が 2 投稿目の段階で失敗した（x539）。1 投稿目だけがタイムラインに出ていないか（出し直しで 2 回出ていないか）を、
#  自分のプロフィールの最新の投稿で確かめる。あわせてログのエラー行の全文（本文の base64 は除く）を出す。何も押さない。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x540-read-own-timeline-camp.md"; PORT="${CDP_PORT:-18810}"; W="$HOME/.openclaw/workspace"
PWDIR=""; for d in "$W/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 自分の最新の投稿と CAMP のエラー（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## エラー行（本文の base64 を除く）"; echo '```'
grep -a '"ok":false' "$W/logs/publish-camp-koyomi-oneshot.log" | perl -pe 's/post-comment\.js \\"[A-Za-z0-9+\/=]+\\"/post-comment.js <本文>/g; s/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g' | cut -c1-1500
echo '```'
cat > "$RDIR/.x540.cjs" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const p = await b.contexts()[0].newPage();
  console.log("\n## 自分のプロフィールの最新の投稿\n```");
  try {
    await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForSelector("article", { timeout: 20000 }).catch(() => {});
    await p.waitForTimeout(4000);
    const r = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 8).map(a => {
      const t = a.querySelector("time"); const link = t && t.closest("a");
      return { time: t ? t.dateTime : "", url: link ? link.getAttribute("href") : "", text: ((a.querySelector('[data-testid="tweetText"]') || {}).innerText || "").replace(/\n/g, " ").slice(0, 70), photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length, pinned: /固定|Pinned/.test(a.innerText.slice(0, 40)) };
    }));
    r.forEach(x => console.log((x.pinned ? "[固定] " : "") + x.time + " " + x.url + " 画像" + x.photos + " ｜ " + x.text));
  } catch (e) { console.log("失敗 " + e.message.slice(0, 160)); }
  console.log("```"); await p.close(); process.exit(0);
})();
J
PWDIR="$PWDIR" PORT="$PORT" "$NODE_BIN" "$RDIR/.x540.cjs" 2>&1 | perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g' &
pid=$!; t0=$(date +%s); while kill -0 $pid 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 90 ] && { kill $pid; echo "90 秒で打ち切った"; }; sleep 2; done
rm -f "$RDIR/.x540.cjs"
echo; echo "**読むだけ。何も押していない。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -cE 'status/' "$OUT"
exit 0
