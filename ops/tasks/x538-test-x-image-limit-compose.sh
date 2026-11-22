#!/bin/bash
# x538（2026-11-22・$0）: 1 投稿に画像を 5 枚以上付けられるかを確かめる（blog3 経由の利用者の依頼。x537 で他人の投稿に 16 枚付いていた）。
#  ① 投稿の仕組み（post-via-playwright.js・run-publish.sh）に 4 枚で切る処理があるか（行だけ出す）
#  ② 投稿画面を開き、クルーズの画像 6 枚を入れて、プレビューが何枚出るか・エラーの文が出るかを数える。
#     **投稿のボタンは押さない。** 終わったら下書きを捨てて閉じる（「破棄」を押す）。画面を reports/x538/ に保存。LLM 不使用。
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x538-test-x-image-limit-compose.md"; IMG="$RDIR/x538"; PORT="${CDP_PORT:-18810}"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"; W="$HOME/.openclaw/workspace"; S="$W/scripts"
mkdir -p "$IMG"
PWDIR=""; for d in "$W/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 1 投稿に画像を何枚付けられるか（$(date '+%Y-%m-%d %H:%M:%S') JST・投稿はしない・\$0）"
echo; echo "## ① 投稿の仕組みの 4 枚の扱い"; echo '```'
for f in "$S/post-via-playwright.js" "$S/run-publish.sh"; do echo "--- $(basename "$f")"; grep -nE 'slice\(0, ?4\)|> ?4|>= ?4|max.?4|4 ?枚|MAX_IMAGES|maxImages|\.length ?(>|>=) ?[0-9]|split\(","\)' "$f" 2>/dev/null | head -12 | cut -c1-200; done
echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
D="$IMG/files"; mkdir -p "$D"; N=0
for f in 1-rank 2-tokyo 3-nagasaki 4-kobe 5-ishigaki 6-sasebo; do git -C "$REPO" show "origin/main:public/images/cruise-port-ranking-2026/x/$f.jpg" > "$D/$f.jpg" 2>/dev/null && [ -s "$D/$f.jpg" ] && N=$((N+1)); done
echo; echo "画像を $N 枚 用意した"
[ -n "$PWDIR" ] || { echo "playwright-core が無い"; exit 0; }
cat > "$IMG/.t.cjs" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
const fs = require("fs"), path = require("path");
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const ctx = b.contexts()[0]; const p = await ctx.newPage();
  console.log("\n## ② 投稿画面に 6 枚入れる（投稿はしない）\n```");
  try {
    await p.goto("https://x.com/compose/post", { waitUntil: "domcontentloaded", timeout: 30000 });
    const input = await p.waitForSelector('input[data-testid="fileInput"]', { state: "attached", timeout: 20000 });
    const accept = await input.getAttribute("accept"); const multiple = await input.getAttribute("multiple");
    console.log("入力欄: accept=" + accept + " multiple=" + multiple);
    const files = fs.readdirSync(process.env.D).filter(f => f.endsWith(".jpg")).sort().map(f => path.join(process.env.D, f));
    await input.setInputFiles(files);
    await p.waitForTimeout(8000);
    const r = await p.evaluate(() => {
      const dlg = document.querySelector('[role="dialog"]') || document;
      const prev = dlg.querySelectorAll('[data-testid="attachments"] img, [data-testid="attachments"] [data-testid="tweetPhoto"]').length;
      const toast = [...document.querySelectorAll('[data-testid="toast"], [role="alert"]')].map(x => x.innerText).join(" ／ ");
      return { prev, toast, att: !!dlg.querySelector('[data-testid="attachments"]') };
    });
    console.log("入れた: " + files.length + " 枚 ／ プレビュー: " + r.prev + " ／ 添付欄: " + r.att + " ／ 出た文: " + (r.toast || "なし"));
    await p.screenshot({ path: path.join(process.env.IMG, "compose.png") });
    console.log("画面: x538/compose.png");
    // 捨てる（投稿しない）
    await p.keyboard.press("Escape"); await p.waitForTimeout(1500);
    const disc = await p.$('[data-testid="confirmationSheetCancel"]');
    if (disc) { await disc.click(); console.log("下書きを捨てた（破棄）"); } else console.log("破棄の確認は出なかった");
    await p.waitForTimeout(1000);
  } catch (e) { console.log("失敗 " + e.message.slice(0, 200)); }
  console.log("```"); await p.close(); process.exit(0);
})();
J
PWDIR="$PWDIR" PORT="$PORT" IMG="$IMG" D="$D" "$NODE_BIN" "$IMG/.t.cjs" 2>&1 &
pid=$!; t0=$(date +%s); while kill -0 $pid 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 120 ] && { kill $pid; echo "120 秒で打ち切った"; }; sleep 2; done
rm -rf "$IMG/.t.cjs" "$D"
echo; echo "**投稿のボタンは押していない。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E 'プレビュー|捨てた|失敗' "$OUT" | head -3
exit 0
