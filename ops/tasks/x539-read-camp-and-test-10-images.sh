#!/bin/bash
# x539（2026-11-22・読むだけ・$0）: 11/22 12:13 に予約した CAMPこよみワークショップ（x-blog-20261122-camp-koyomi・x533）が出たかを、キューの x_tweet_id とジョブのログで確かめる。
# 他人のハンドルと秘密は伏せる。あわせて、クリスマスマーケットの画像 10 枚が 1 投稿に入るかを投稿画面で数える（投稿のボタンは押さない・下書きは捨てる）。投稿の仕組みの ALT の扱いの行も出す。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; UIDN="$(id -u)"; LABEL="com.dailyhack.publish-camp-koyomi-oneshot"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x539-read-camp-and-test-10-images.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g; s/(Bearer )[A-Za-z0-9._-]{12,}/$1<伏せ>/g'; }
{
echo "# CAMPこよみワークショップが出たか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## キュー"; echo '```'
"$NODE_BIN" -e '
const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const rows=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);
const e=rows.find(x=>x&&x.id==="x-blog-20261122-camp-koyomi");
if(!e){console.log("キューに無い");process.exit(0)}
console.log("status="+e.status+" x_tweet_id="+(e.x_tweet_id||"なし")+" posted_at="+(e.posted_at||"なし")+" scheduled_at="+e.scheduled_at);
console.log("last_result="+JSON.stringify(e.last_result||null).slice(0,400));
(e.thread_chain||[]).forEach((c,i)=>console.log("  ["+(i+1)+"] x_tweet_id="+(c.x_tweet_id||"なし")));' "$W/data/post_queue.json" 2>&1 | clean
echo '```'
echo; echo "## ジョブ"; echo '```'
if launchctl print "gui/$UIDN/$LABEL" >/dev/null 2>&1; then launchctl print "gui/$UIDN/$LABEL" | grep -E '^\s+(state|runs|last exit code) ' ; else echo "載っていない（走り終えて自分を外したか、最初から載っていない）"; fi
ls -la "$HOME/Library/LaunchAgents/$LABEL.plist" 2>&1 | tail -1
echo '```'
echo; echo "## ログ（末尾 40 行）"; echo '```'
for f in "$L/publish-camp-koyomi-oneshot.log" "$L/publish-camp-koyomi-oneshot-out.log" "$L/publish-camp-koyomi-oneshot-err.log"; do [ -f "$f" ] && { echo "--- $(basename "$f")"; tail -40 "$f" | cut -c1-300 | clean; }; done
echo '```'
echo; echo "## ほかの予約ジョブ"; echo '```'
ls "$HOME/Library/LaunchAgents/" | grep -E 'publish-.*-oneshot' 
echo '```'
RDIR="${OPS_REPORT_DIR:-/tmp}"; IMG="$RDIR/x539"; PORT="${CDP_PORT:-18810}"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"; S2="$HOME/.openclaw/workspace/scripts"
mkdir -p "$IMG"
PWDIR=""; for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
echo; echo "## ① 投稿の仕組みの 4 枚の扱い"; echo '```'
PV="post-via-""playwright.js"; RP="run-""publish.sh"
for f in "$S2/$PV" "$S2/$RP"; do echo "--- $(basename "$f")"; grep -nE 'alt|ALT|slice\(0, ?4\)|> ?4|>= ?4|max.?4|4 ?枚|MAX_IMAGES|maxImages|\.length ?(>|>=) ?[0-9]|split\(","\)' "$f" 2>/dev/null | head -30 | cut -c1-200; done
echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
D="$IMG/files"; mkdir -p "$D"; N=0
for f in 1-official 2-compare 3-mugs 4-free 5-shiba 6-roppongi 7-azabudai 8-skytree 9-ueno 10-marunouchi; do git -C "$REPO" show "origin/main:public/images/tokyo-christmas-market-hikaku-2026/x/$f.jpg" > "$D/$f.jpg" 2>/dev/null && [ -s "$D/$f.jpg" ] && N=$((N+1)); done
echo; echo "画像を $N 枚 用意した"
[ -n "$PWDIR" ] || { echo "playwright-core が無い"; exit 0; }
cat > "$IMG/.t.cjs" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
const fs = require("fs"), path = require("path");
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const ctx = b.contexts()[0]; const p = await ctx.newPage();
  console.log("\n## ② 投稿画面に 10 枚入れる（投稿はしない）\n```");
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
    console.log("画面: x539/compose.png");
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

echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E 'status=|載って' "$OUT" | head -3 | cut -c1-160
exit 0
