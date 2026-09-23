#!/bin/bash
# **[2/2] が出ていない。見て、無ければ出し直す。費用 $0。**
#
# ## 何が起きたか
#
# `x137` は `ok:true` と `reply_tweet_id` を返した。
#
#   {"index":1,"role":"cta","ok":true,"reply_tweet_id":"2102732550989115457",...}
#
# **だが利用者が URL を開くと見えない。** つまり **その ID は実在しない。**
#
# `post-comment.js` は GraphQL の応答から ID を拾うが、**拾えた＝出た ではない。**
# ファイル冒頭に「pinned-tweet ID bug 真の修正」とあるとおり、
# **この箇所は過去にも誤った ID を返している。**
#
# ## 片肺のまま放置しない
#
# `[1/2]` は「この全部に勝ったのが ↓↓」で終わる。**続きが無いと意味が通らない。**
# だから見て、無ければ**同じ `[1/2]` にぶら下げ直す。**
#
# ## 二重投稿を絶対に避ける
#
# **先に DOM を見て、自分の返信が既にぶら下がっていれば何もしない。**
# `reply_tweet_id` は信用しない（それが今回 外れたもの）。
#
# ## プローブは**ワークスペースの中**に置く
#
# `$TMPDIR` に置くと `require("playwright-core")` が解決できず、
# **`Cannot find module` で空振りする**（`x138` がまさにこれで失敗した）。
# `node_modules` は `~/.openclaw/workspace/` にあるので、その直下に置く。
#
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るので秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/repair-morning-reply.md"
LOCK="$W/data/.x139-repair.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
CMT="$W/scripts/post-comment.js"
HEALTH="$W/scripts/cdp-health.js"
QJSON="$W/data/post_queue.json"
PROBE="$W/.x139-probe.js"   # **$TMPDIR に置かない。** node_modules を解決できない
ID="blog-promo-20260923-morning-500-2026-v2"
T1="2102732457930064353"
URL="https://daily-hack.fieldbeside.com/posts/morning-500-2026/"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

T2='なか卯の目玉焼き朝食、300円。

ごはん・みそ汁・目玉焼きつきで一食が完結するの。小盛300円、並盛でも320円よ。松屋より30円安い。

朝4:00から11:00まで。モバイルオーダーなら早朝の割増もかからない。

値段もつくものも、全部 公式ページで確かめたやつ。

'"$URL"

cat > "$PROBE" <<'PROBEJS'
// **投稿ページの DOM を見る。** 引数: <tweet-id> <自分のハンドル>
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
(async () => {
  const [id, me] = process.argv.slice(2);
  const r = { id, exists: false };
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const page = await browser.contexts()[0].newPage();
    await page.goto("https://x.com/" + me + "/status/" + id,
      { waitUntil: "domcontentloaded", timeout: 25000 });
    await page.waitForTimeout(6000);
    const arts = await page.$$('article[data-testid="tweet"]');
    r.articles = arts.length;
    if (!arts.length) {
      const t = await page.innerText("body").catch(() => "");
      r.page_says = t.split("\n").filter(Boolean).slice(0, 4).join(" / ").slice(0, 160);
      console.log(JSON.stringify(r)); await browser.close().catch(()=>{}); return;
    }
    r.exists = true;
    // 1 件目 = 当該投稿。2 件目以降 = ぶら下がっている返信
    const main = arts[0];
    r.photos = await main.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1);
    const bodyEl = await main.$('[data-testid="tweetText"]');
    r.head = bodyEl ? (await bodyEl.innerText()).split("\n")[0].slice(0, 26) : null;
    // **自分の返信がぶら下がっているか。** これが二重投稿を防ぐ唯一の根拠
    r.replies = [];
    for (const a of arts.slice(1, 6)) {
      const link = await a.$('a[href*="/status/"]');
      const href = link ? await link.getAttribute("href") : "";
      const txt = await a.$('[data-testid="tweetText"]');
      r.replies.push({
        mine: (href || "").includes("/" + me + "/"),
        photos: await a.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1),
        head: txt ? (await txt.innerText()).split("\n")[0].slice(0, 26) : null,
      });
    }
    await page.close().catch(() => {});
  } catch (e) { r.error = String(e.message).slice(0, 140); }
  console.log(JSON.stringify(r));
  if (browser) await browser.close().catch(() => {});
})();
PROBEJS

{
echo "# [2/2] を出し直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **\`x137\` が返した \`reply_tweet_id\` は実在しなかった**（利用者が URL を開いて確認）。"
echo "> **DOM を見て、自分の返信が無ければ出し直す。**"

if [ -f "$LOCK" ]; then echo; echo "- **ロックがある（$(cat "$LOCK" 2>/dev/null)）。何もしない。**"; exit 0; fi

echo
echo "## 1. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（無い）"; fi
echo '```'

echo
echo "## 2. \`[1/2]\` の実物を見る"
echo
echo "**見るのは 2 つ。** 1 本目が実在するか。**自分の返信が既にぶら下がっていないか。**"
echo
echo '```json'
cd "$W" && R1="$("$NODE_BIN" "$PROBE" "$T1" "$ME" 2>&1 | tail -1)"
printf '%s\n' "$R1" | clean
echo '```'

EXISTS="$(printf '%s' "$R1" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).exists?1:0)}catch(e){console.log(0)}})' 2>/dev/null)"
MINE="$(printf '%s' "$R1" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);console.log((o.replies||[]).filter(r=>r.mine).length)}catch(e){console.log(-1)}})' 2>/dev/null)"

echo
if [ "$EXISTS" != "1" ]; then
  echo "- **\`[1/2]\` も実在しない。** ぶら下げる先が無いので、ここでは何もしない。"
  echo "- **2 本とも出ていない**ということなので、出し直しは別途 判断が要る。"
  exit 1
fi
echo "- \`[1/2]\` は実在する"
if [ "${MINE:-0}" -gt 0 ] 2>/dev/null; then
  echo "- **自分の返信が既に $MINE 件 ぶら下がっている。二重投稿になるので何もしない。**"
  exit 0
fi
echo "- **自分の返信はぶら下がっていない。出し直す。**"

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
  printf '  取得  cover-a.jpg  %s bytes\n' "$(wc -c < "$IMGDIR/cover-a.jpg" | tr -d ' ')"
else
  echo "  **取れない**"; rm -f "$TMP"; rm -f "$LOCK"; echo '```'; exit 1
fi
echo '```'

echo
echo "## 4. \`post-comment.js\` を直接 叩く（**画像つき**）"
echo
echo "\`run-publish.sh\` は通さない。**1 本目はもう出ているので、返信だけを足す。**"
echo
echo '```'
B64="$("$NODE_BIN" -e 'process.stdout.write(Buffer.from(process.argv[1],"utf8").toString("base64"))' "$T2")"
cd "$W" && RES="$("$NODE_BIN" "$CMT" "$B64" "https://x.com/$ME/status/$T1" "$IMGDIR/cover-a.jpg" 2>&1)"; PRC=$?
printf '%s\n' "$RES" | tail -30 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 5. **出たかを DOM で確かめる**（\`reply_tweet_id\` は信用しない）"
echo
echo "**今回 外したのがまさにそこ。** 返り値ではなく、ぶら下がっているかを見る。"
echo
sleep 8
echo '```json'
cd "$W" && R2="$("$NODE_BIN" "$PROBE" "$T1" "$ME" 2>&1 | tail -1)"
printf '%s\n' "$R2" | clean
echo '```'

MINE2="$(printf '%s' "$R2" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);console.log((o.replies||[]).filter(r=>r.mine).length)}catch(e){console.log(-1)}})' 2>/dev/null)"
PH="$(printf '%s' "$R2" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const o=JSON.parse(s);const m=(o.replies||[]).filter(r=>r.mine);console.log(m.length?m[0].photos:-1)}catch(e){console.log(-1)}})' 2>/dev/null)"

echo
echo "### 最終状態"
echo
echo "- ぶら下がっている自分の返信: **${MINE2} 件**（実行前 ${MINE} 件）"
echo "- その返信の画像: **${PH} 枚**（期待 1 枚）"
echo
if [ "${MINE2:-0}" -gt 0 ] 2>/dev/null; then
  echo "**[2/2] が DOM 上に在る。** 画像の枚数も上のとおり。"
else
  echo "**まだ出ていない。** 上の出力の全文を見ること。**\`rc\` は証拠にならない**（最上位ルール 13）。"
fi
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '\[2/2\] が DOM 上に在る' "$OUT" 2>/dev/null; then
  echo "**[2/2] を出し直した。DOM で確認済み** / $(basename "$OUT")"
elif grep -q '二重投稿になるので何もしない' "$OUT" 2>/dev/null; then
  echo "既にぶら下がっていたので何もしていない / $(basename "$OUT")"
else
  echo "**出し直せていない。レポート全文を読むこと** / $(basename "$OUT")"
fi
