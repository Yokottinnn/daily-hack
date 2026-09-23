#!/bin/bash
# **[2/2] を出し直す（2 回目）。費用 $0。**
#
# ## x139 は「出した」と誤報した
#
# `x139` は返信の判定を **`article` の中の最初の `/status/` リンク**で見ていた。
# X は `article` の中に投稿者プロフィールや引用へのリンクも持つため、
# **`[1/2]` 自身を「自分の返信」と数えた。** だから 0 件 なのに 1 件 と出た。
#
# `x140` は **`time` 要素の親 `a`**（＝その投稿の permalink）を見ており、
# そちらが正しい。**判定はこの方式に統一する。**
#
#   x140 の実測: {"view":"logged-in","articles":1,...}  ← 返信は無い
#
# ## 出したら permalink を必ず記録する
#
# `x139` は ID を取らなかったので、**古い（実在しない）リンクを渡し続けた。**
# **出した返信の href を報告に出す。** それが無ければ「出た」と言わない。
#
# ## 二重投稿を避ける
#
# 出す前に `time` 方式で数え、**自分の返信が 1 件でもあれば何もしない。**
#
# ## プローブはワークスペースの中に置く
#
# `$TMPDIR` だと `playwright-core` が解決できない（`x138` がそれで空振りした）。
#
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るので秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/repost-reply-v2.md"
LOCK="$W/data/.x141-repost.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
CMT="$W/scripts/post-comment.js"
HEALTH="$W/scripts/cdp-health.js"
PROBE="$W/.x141-probe.js"
T1="2102732457930064353"
URL="https://daily-hack.fieldbeside.com/posts/morning-500-2026/"
ME="heng_ji31590"

secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }

T2='なか卯の目玉焼き朝食、300円。

ごはん・みそ汁・目玉焼きつきで一食が完結するの。小盛300円、並盛でも320円よ。松屋より30円安い。

朝4:00から11:00まで。モバイルオーダーなら早朝の割増もかからない。

値段もつくものも、全部 公式ページで確かめたやつ。

'"$URL"

cat > "$PROBE" <<'PROBEJS'
// **`time` の親 a を permalink として読む**（x140 と同じ方式）。
// article 内の最初の /status/ リンクでは [1/2] 自身を拾ってしまう（x139 の誤報の原因）。
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const [t1, me] = process.argv.slice(2);
(async () => {
  const r = { articles: 0, self: null, replies: [] };
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await browser.contexts()[0].newPage();
    await page.goto("https://x.com/" + me + "/status/" + t1,
      { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(8000);
    const arts = await page.$$('article[data-testid="tweet"]');
    r.articles = arts.length;
    for (const a of arts) {
      const t = await a.$("time");
      let href = null;
      if (t) {
        const p = await t.evaluateHandle((e) => e.closest("a"));
        href = p ? await p.evaluate((e) => e && e.getAttribute("href")) : null;
      }
      const txt = await a.$('[data-testid="tweetText"]');
      const item = {
        href,
        photos: await a.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1),
        head: txt ? (await txt.innerText()).split("\n")[0].slice(0, 24) : null,
      };
      // **permalink に t1 が入っていれば本体。** それ以外で自分のハンドルなら返信
      if (href && href.includes("/status/" + t1)) r.self = item;
      else if (href && href.startsWith("/" + me + "/status/")) r.replies.push(item);
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e.message).slice(0, 140); }
  console.log(JSON.stringify(r));
  if (browser) await browser.close().catch(() => {});
})();
PROBEJS

count_replies() {
  cd "$W" && "$NODE_BIN" "$PROBE" "$T1" "$ME" 2>/dev/null | tail -1
}
n_of() {
  printf '%s' "$1" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log((JSON.parse(s).replies||[]).length)}catch(e){console.log(-1)}})' 2>/dev/null
}

{
echo "# [2/2] を出し直す（2 回目・$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **\`x139\` は「出した」と誤報した。** 返信の判定が \`article\` 内の最初の"
echo "> \`/status/\` リンクで、**\`[1/2]\` 自身を数えていた。**"
echo "> ここでは \`time\` の親 \`a\` を permalink として読む（\`x140\` と同じ）。"

if [ -f "$LOCK" ]; then echo; echo "- **ロックがある（$(cat "$LOCK" 2>/dev/null)）。何もしない。**"; exit 0; fi

echo
echo "## 1. Chrome は健全か"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | secrets; echo "(rc=$?)"; else echo "（無い）"; fi
echo '```'

echo
echo "## 2. いまの状態（**出す前**）"
echo
echo '```json'
BEFORE="$(count_replies)"; printf '%s\n' "$BEFORE" | secrets
echo '```'
NB="$(n_of "$BEFORE")"
echo
echo "- ぶら下がっている自分の返信: **${NB} 件**"
if [ "$NB" = "-1" ]; then echo; echo "- **読めない。何もしない。**"; exit 1; fi
if [ "${NB:-0}" -gt 0 ] 2>/dev/null; then
  echo; echo "- **既にある。二重投稿になるので何もしない。**"; exit 0
fi

mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo
echo "## 3. 画像を \`origin/main\` から取り直す"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
TMP="$IMGDIR/.dl-cover-a.jpg"
if git -C "$REPO" show "origin/main:$SRCDIR/cover-a.jpg" > "$TMP" 2>/dev/null \
   && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 20000 ]; then
  mv "$TMP" "$IMGDIR/cover-a.jpg"
  printf '  cover-a.jpg  %s bytes\n' "$(wc -c < "$IMGDIR/cover-a.jpg" | tr -d ' ')"
else
  echo "  **取れない**"; rm -f "$TMP" "$LOCK"; echo '```'; exit 1
fi
echo '```'

echo
echo "## 4. 返信を出す"
echo
echo '```'
B64="$("$NODE_BIN" -e 'process.stdout.write(Buffer.from(process.argv[1],"utf8").toString("base64"))' "$T2")"
cd "$W" && RES="$("$NODE_BIN" "$CMT" "$B64" "https://x.com/$ME/status/$T1" "$IMGDIR/cover-a.jpg" 2>&1)"; PRC=$?
printf '%s\n' "$RES" | tail -25 | secrets
echo "(rc=$PRC)"
echo '```'
echo
echo "**この rc も返り値も判定に使わない**（それで 2 回 外した）。次で DOM を見る。"

echo
echo "## 5. 出たか（**DOM で見る。permalink を必ず出す**）"
echo
sleep 10
echo '```json'
AFTER="$(count_replies)"; printf '%s\n' "$AFTER" | secrets
echo '```'
NA="$(n_of "$AFTER")"

echo
echo "### 結果"
echo
echo "- 自分の返信: **${NA} 件**（出す前 ${NB} 件）"
echo
if [ "${NA:-0}" -gt 0 ] 2>/dev/null; then
  HREF="$(printf '%s' "$AFTER" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const r=JSON.parse(s).replies[0];console.log("https://x.com"+r.href+"  photos="+r.photos)}catch(e){console.log("(取れない)")}})' 2>/dev/null)"
  echo "**[2/2] の URL: $HREF**"
  echo
  echo "**このリンクを報告に使う。** 古い ID を貼らない（それで「出てない」と言われた）。"
else
  echo "**出ていない。** 上の出力の全文を読むこと。**勝手に「出た」と言わない。**"
fi
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { secrets < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '^\*\*\[2/2\] の URL' "$OUT" 2>/dev/null; then
  echo "**[2/2] を出した。URL はレポートに** / $(basename "$OUT")"
elif grep -q '既にある。二重投稿' "$OUT" 2>/dev/null; then
  echo "既にあったので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。レポート全文を読むこと** / $(basename "$OUT")"
fi
