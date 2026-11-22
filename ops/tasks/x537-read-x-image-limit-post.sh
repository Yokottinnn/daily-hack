#!/bin/bash
# x537（2026-11-22・読むだけ・$0）: X の 1 投稿あたりの画像の上限が増えたという投稿（利用者が blog3 に渡した URL）を読む。
#  投稿の本文・画像の枚数・付いている画像の説明（ALT）を出し、画面を reports/x537/ に保存する。何も押さない・投稿しない。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x537-read-x-image-limit-post.md"; IMG="$RDIR/x537"; PORT="${CDP_PORT:-18810}"
mkdir -p "$IMG"
PWDIR=""; for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
JS="$IMG/.r.cjs"
{
echo "# X の画像の上限の投稿を読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
[ -n "$PWDIR" ] || { echo "playwright-core が無い"; exit 0; }
cat > "$JS" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
const path = require("path");
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const ctx = b.contexts()[0]; const p = await ctx.newPage();
  const u = "https://x.com/alucasunahara/status/2124264395807277487";
  console.log("```");
  try {
    await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForSelector("article", { timeout: 20000 }).catch(() => {});
    await p.waitForTimeout(4000);
    const r = await p.evaluate(() => {
      const arts = [...document.querySelectorAll("article")].slice(0, 4);
      return arts.map((a, i) => ({ i, text: (a.querySelector('[data-testid="tweetText"]') || {}).innerText || "", photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length,
        alts: [...a.querySelectorAll('[data-testid="tweetPhoto"] img')].map(x => (x.alt || "").slice(0, 160)), time: (a.querySelector("time") || {}).dateTime || "" }));
    });
    r.forEach(x => { console.log("--- article " + x.i + " ／ " + x.time + " ／ 画像 " + x.photos + " 枚"); console.log(x.text.replace(/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/g, "@<伏せ>")); x.alts.forEach((a, k) => console.log("  ALT" + (k + 1) + ": " + a)); });
    await p.screenshot({ path: path.join(process.env.IMG, "post.png"), fullPage: false });
    console.log("画面: x537/post.png");
  } catch (e) { console.log("失敗 " + e.message.slice(0, 200)); }
  console.log("```"); await p.close(); process.exit(0);
})();
J
PWDIR="$PWDIR" PORT="$PORT" IMG="$IMG" "$NODE_BIN" "$JS" 2>&1 &
pid=$!; t0=$(date +%s); while kill -0 $pid 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 120 ] && { kill $pid; echo "120 秒で打ち切った"; }; sleep 2; done
rm -f "$JS"
echo; echo "**読むだけ。何も押していない。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '画像 [0-9]+ 枚' "$OUT" | head -3
exit 0
