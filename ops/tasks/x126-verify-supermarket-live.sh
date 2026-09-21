#!/bin/bash
# **出し直した 2 本が、いま X 上に在るかを見る。測るだけ。費用 $0（DOM を読むだけ）。**
#
# ## なぜ
#
# 2026-09-21 18:22 に `run-publish.sh` が graphql 応答で tweet_id を返し、
# キューにも `posted` で書き戻した。
#
#   [1/2] 2101965436426564045
#   [2/2] 2101965516718187002
#
# **だがそれは 18:22 時点の話で、「いま」ではない**（最上位ルール 11）。
# 22:23 に利用者から「まだな気がする」と言われた。**4 時間 空いている。**
#
# **キューの tweet_id は「投稿 API が ID を返した」証拠であって、
# 「いまタイムラインに在る」証拠ではない。** 別の口で見る。
#
# ## 何を見るか
#
#   ① 2 本の URL を開いて、**本文が出るか / 削除・非公開になっていないか**
#   ② 同時に**自分のタイムライン**を見て、実際に並んでいるか
#   ③ キューの現状（18:22 以降に誰かが触っていないか）
#
# ## 判定の仕方（**推測しない**）
#
# X は削除済みツイートに「このポストは削除されました」等を出す。
# **本文の一部（「1店舗あたりの年商」）が DOM に在るかどうかで判定する。**
# 見つからなければ、そのときの `article` の中身をそのまま出す。
#
# ## やらないこと
#
# **投稿しない。消さない。直さない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
QJSON="$W/data/post_queue.json"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-supermarket-live.md"
RUNNER="$S/.x126-verify.js"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260921-tokyo-discount-supermarket-2026-v2"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
         -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# **拡張子は `.js` のまま**（`.new` を付けると macOS の node が弾く・最上位ルール 14）
cat > "$RUNNER" <<'JSEOF'
// x126: 2 本がいま在るかを見る。$0。
// **playwright-core**（`playwright` はこのワークスペースに無い）
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const HANDLE = "heng_ji31590";
const IDS = ["2101965436426564045", "2101965516718187002"];
// **本文の一部で判定する。** 「出た」と言い切るための証拠
const NEEDLE = ["1店舗あたりの年商", "都心の安いスーパーどこ"];

(async () => {
  const b = await chromium.connectOverCDP(CDP, { timeout: 60000 });
  const p = await b.contexts()[0].newPage();
  const out = { checks: [], timeline: null };

  for (let i = 0; i < IDS.length; i++) {
    const id = IDS[i];
    const url = "https://x.com/" + HANDLE + "/status/" + id;
    const r = { n: i + 1, tweet_id: id, url };
    try {
      const resp = await p.goto(url, { waitUntil: "domcontentloaded", timeout: 40000 });
      r.http = resp ? resp.status() : null;
      await p.waitForTimeout(5000);
      const got = await p.evaluate(() => {
        const art = document.querySelector("article");
        const body = document.body ? document.body.innerText : "";
        return {
          hasArticle: !!art,
          artText: art ? art.innerText.replace(/\s+/g, " ").slice(0, 300) : null,
          // 削除・非公開のときに出る文言
          gone: /削除されました|このポストは表示できません|Hmm\.\.\.this page|doesn’t exist|does not exist|Page not found/i.test(body),
          imgs: art ? art.querySelectorAll('img[src*="media"]').length : 0,
        };
      });
      Object.assign(r, got);
      r.needleFound = got.artText ? got.artText.includes(NEEDLE[i] || "") : false;
      r.verdict = got.gone ? "**消えている**"
                : (r.needleFound ? "在る" : "**判定できない**（本文が一致しない）");
    } catch (e) {
      r.error = String(e && e.message).slice(0, 160);
      r.verdict = "**開けなかった**";
    }
    out.checks.push(r);
  }

  // **タイムラインも見る。** 個別 URL が出ても並んでいないことがある
  try {
    await p.goto("https://x.com/" + HANDLE, { waitUntil: "domcontentloaded", timeout: 40000 });
    await p.waitForTimeout(6000);
    out.timeline = await p.evaluate(() => {
      const arts = [...document.querySelectorAll("article")].slice(0, 6);
      return arts.map((a) => {
        const t = a.innerText.replace(/\s+/g, " ").slice(0, 120);
        const link = [...a.querySelectorAll('a[href*="/status/"]')]
          .map((x) => (x.getAttribute("href") || "").match(/status\/(\d+)/))
          .filter(Boolean).map((m) => m[1])[0] || null;
        return { id: link, text: t };
      });
    });
  } catch (e) { out.timeline = { error: String(e && e.message).slice(0, 160) }; }

  await p.close(); await b.close();
  console.log(JSON.stringify(out, null, 1));
})().catch((e) => {
  console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) }, null, 1));
  process.exit(1);
});
JSEOF

{
echo "# 出し直した 2 本は、いま在るか（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 18:22 に \`run-publish.sh\` が graphql 応答で tweet_id を返し、キューにも書き戻した。"
echo "> **だがそれは 18:22 時点の話で「いま」ではない**（最上位ルール 11）。"
echo "> **キューの tweet_id は「API が ID を返した」証拠であって、**"
echo "> **「いまタイムラインに在る」証拠ではない。** 別の口で見る。"

echo
echo "## 1. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$S/cdp-health.js" ]; then "$NODE_BIN" "$S/cdp-health.js" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'
echo
echo "**ログアウトしていると、在るのに「無い」と出る。** 上が OK でなければ以降は信用しない。"

echo
echo "## 2. 2 本を開いて、本文が出るか"
echo
echo '```json'
if ! "$NODE_BIN" --check "$RUNNER" >/dev/null 2>&1; then
  echo "  **構文エラーなので走らせない。**"
  "$NODE_BIN" --check "$RUNNER" 2>&1 | head -5
else
  RES="${TMPDIR:-/tmp}/.x126-result.json"
  ( cd "$S" && "$NODE_BIN" "$(basename "$RUNNER")" ) > "$RES" 2>&1
  echo "  rc=$? （**rc は証拠にならない。中身を見る**）"
  head -c 5000 "$RES" | clean
  echo
  rm -f "$RES" 2>/dev/null || true
fi
echo '```'
echo
echo "**\`verdict\` が「在る」でなければ、出ていないか消えている。**"
echo "\`gone: true\` なら削除・非公開。\`needleFound: false\` なら本文が違う。"

echo
echo "## 3. キューはいまどうなっているか"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=(q.queue||[]).filter(e=>e&&String(e.id||"").includes("tokyo-discount-supermarket"));
  if(!rows.length){ console.log("  該当エントリが無い"); process.exit(0); }
  console.log(JSON.stringify(rows.map(e=>({
    id:e.id, status:e.status,
    x_tweet_id:e.x_tweet_id||null,
    deleted_x_tweet_id:e.deleted_x_tweet_id||null,
    posted_at:e.posted_at||null, deleted_at:e.deleted_at||null,
    chain:(e.thread_chain||[]).map((c,i)=>({n:i+1, tweet_id:c.x_tweet_id||null}))
  })),null,1));
}catch(err){ console.log("  キューが読めない: "+err.message); }
' "$QJSON" 2>&1 | clean
echo '```'
echo
echo "**18:22 以降に誰かが触っていれば、ここに出る。**"

echo
echo "## 4. 読み方"
echo
echo "| 出方 | 意味 |"
echo "| --- | --- |"
echo "| \`verdict: 在る\` が 2 本 | **出ている。** 利用者の画面の問題（キャッシュ等） |"
echo "| \`gone: true\` | **消えている。** 誰が消したかを次に調べる |"
echo "| \`開けなかった\` ＋ CDP が NG | **判定できていない。** Chrome を直してから測り直す |"
echo "| タイムラインに並んでいない | 個別 URL が出ても届いていない。X 側の制限を疑う |"
echo
echo "**どれであっても「たぶん出ています」とは言わない**（最上位ルール 11）。"

echo
echo "## 5. 費用"
echo
echo "**DOM を読むだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

rm -f "$RUNNER" 2>/dev/null || true
[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "2 本がいま在るかを見た / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
