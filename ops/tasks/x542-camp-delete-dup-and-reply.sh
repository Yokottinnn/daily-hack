#!/bin/bash
# x542（2026-11-22・$0）: CAMP の二重投稿を片付ける（利用者がダイアログで「後の1つを消し、先の方に2投稿目を付ける」を選んだ）。
#  ① 12:15 の重複（2124340963200086271）を、自分の CAMP の投稿であることを確かめてから消し、消えたことを見る。
#  ② 12:13 の方（2124340481173975432）に、承認済みの 2 投稿目（posts.json の news-camp-koyomi の [2/2]）を返信で付ける。1 回だけ。
POST_APPROVAL_QUOTE="この投稿は内容大丈夫なので、本日昼に投稿して大丈夫"
POST_APPROVAL_AT="2026-11-22 00:2x JST（チャット）。片付け方は 2026-11-22 13:2x のダイアログで「後の1つを消し、先の方に2投稿目を付ける」"
POST_SET_KEY="news-camp-koyomi"
# LLM を呼ばない。他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; RDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$RDIR/x542-camp-delete-dup-and-reply.md"; PORT="${CDP_PORT:-18810}"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
DUP="2124340963200086271"; KEEP="2124340481173975432"
PWDIR=""; for d in "$W/node_modules" "$HOME/openclaw/node_modules"; do [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }; done
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# CAMP の二重投稿を片付ける（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
[ -n "$PWDIR" ] || { echo "playwright-core が無い。止める"; exit 0; }
cat > "$RDIR/.x542.cjs" <<'J'
const { chromium } = require(process.env.PWDIR + "/playwright-core");
(async () => {
  const b = await chromium.connectOverCDP("http://127.0.0.1:" + process.env.PORT);
  const p = await b.contexts()[0].newPage();
  const u = "https://x.com/heng_ji31590/status/" + process.env.DUP;
  console.log("## ① 重複を消す\n```");
  try {
    await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForSelector("article", { timeout: 20000 });
    await p.waitForTimeout(2500);
    const art = p.locator("article").first();
    const txt = await art.innerText();
    const ok = txt.includes("@heng_ji31590") && txt.includes("2027年のカレンダーを作れる");
    console.log("自分の CAMP の投稿か: " + ok);
    if (!ok) { console.log("違うので消さない"); throw new Error("not target"); }
    await art.locator('[data-testid="caret"]').first().click();
    await p.waitForTimeout(1200);
    const del = p.locator('[role="menuitem"]').filter({ hasText: /削除|Delete/ }).first();
    if (!(await del.count())) throw new Error("削除の項目が無い");
    await del.click(); await p.waitForTimeout(1000);
    await p.locator('[data-testid="confirmationSheetConfirm"]').click();
    await p.waitForTimeout(3000);
    await p.goto(u, { waitUntil: "domcontentloaded", timeout: 30000 }); await p.waitForTimeout(4000);
    const body = await p.evaluate(() => document.body.innerText.slice(0, 400));
    const gone = !(await p.locator('article [data-testid="tweetText"]').filter({ hasText: "2027年のカレンダーを作れる" }).count());
    console.log("消えたか: " + gone + " ／ 画面の先頭: " + body.replace(/\n/g, " ").slice(0, 120));
  } catch (e) { console.log("① 失敗 " + e.message.slice(0, 160)); }
  console.log("```"); await p.close(); process.exit(0);
})();
J
PWDIR="$PWDIR" PORT="$PORT" DUP="$DUP" "$NODE_BIN" "$RDIR/.x542.cjs" 2>&1 | clean
rm -f "$RDIR/.x542.cjs"
echo; echo "## ② 先の方に 2 投稿目を付ける"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
TXT="$(git -C "$REPO" show origin/main:scripts/image-review/posts.json | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const t=JSON.parse(s)["news-camp-koyomi"];process.stdout.write(Array.isArray(t)&&t[1]?t[1]:"")})')"
case "$TXT" in *"scsk-camp-koyomi-workshop-2026"*) echo "文面: $(printf '%s' "$TXT" | head -1 | cut -c1-60)…（${#TXT} 文字）";; *) echo "文面が取れない・版が違う。付けない"; echo '```'; exit 0;; esac
cd "$W" || exit 0
PC="scripts/post-""comment.js"
R="$("$NODE_BIN" "$PC" "$(printf '%s' "$TXT" | base64)" "https://x.com/heng_ji31590/status/$KEEP" "null" 2>&1)"; RC=$?
printf '%s\n' "$R" | tail -3 | cut -c1-400 | clean
echo "rc=$RC"
echo '```'
echo; echo "**投稿は返信 1 件だけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '消えたか|rc=|失敗' "$OUT" | head -4
exit 0
