#!/bin/bash
# **投稿が第三者から見えるかを、3 通りで確かめる。読むだけ。費用 $0。**
#
# ## 何を疑っているか
#
# `x140` で **ログアウト相当が `articles: 0`** だった。
# だが**それが「見えない」の証拠とは限らない。**
#
#   * `connectOverCDP` は**既存の Chrome に繋ぐ**。`browser.newContext()` が
#     期待どおり cookie なしの箱になるとは限らない
#   * X はログアウト時に**ログイン壁**を出すことがあり、
#     `article` が 0 でも「投稿が無い」ことにはならない
#
# **プローブの作りの問題か、アカウント側の問題か。** 切り分けないと直せない。
#
# ## 3 通りで見る
#
#   A. ログイン済みの Chrome（いつもの）
#   B. **curl で oEmbed**（ブラウザも cookie も使わない。X の公開 API）
#   C. **curl で syndication**（埋め込み用の公開エンドポイント）
#
# **B と C が返れば、投稿は公開されている。** A だけで見えて B/C が落ちるなら、
# 非公開・センシティブ・凍結のどれか。**3 つとも落ちるなら投稿自体が無い。**
#
# curl は **cookie を送らない**ので、第三者の目線そのものになる。
# ブラウザの都合（JS・ログイン壁）にも左右されない。
#
# ## 読むだけ。投稿しない
#
# **LLM を呼ばない（$0）。** 出力は公開リポジトリに載るので秘密は伏せる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/public-visibility.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PROBE="$W/.x142-probe.js"   # **$TMPDIR に置かない**（playwright-core が解決できない）
ME="heng_ji31590"
T1="2102732457930064353"
T2="2102740733400912253"

secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }

cat > "$PROBE" <<'PROBEJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const me = process.argv[2];
(async () => {
  const out = [];
  let browser;
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 60000 });
    const ctx = browser.contexts()[0];
    for (const id of process.argv.slice(3)) {
      const page = await ctx.newPage();
      const r = { id };
      try {
        await page.goto("https://x.com/" + me + "/status/" + id,
          { waitUntil: "domcontentloaded", timeout: 30000 });
        await page.waitForTimeout(7000);
        r.articles = (await page.$$('article[data-testid="tweet"]')).length;
        const a = (await page.$$('article[data-testid="tweet"]'))[0];
        if (a) {
          r.photos = await a.$$eval('[data-testid="tweetPhoto"]', (n) => n.length).catch(() => -1);
          const g = await a.$('[role="group"][aria-label]');
          r.metrics = g ? await g.getAttribute("aria-label") : null;
        }
      } catch (e) { r.error = String(e.message).slice(0, 120); }
      out.push(r);
      await page.close().catch(() => {});
    }
  } catch (e) { out.push({ fatal: String(e.message).slice(0, 160) }); }
  console.log(JSON.stringify(out, null, 1));
  if (browser) await browser.close().catch(() => {});
})();
PROBEJS

{
echo "# 投稿が第三者から見えるか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x140\` でログアウト相当が \`articles: 0\` だったが、**プローブの作りかもしれない。**"
echo "> \`connectOverCDP\` は既存の Chrome に繋ぐので、\`newContext()\` が"
echo "> cookie なしの箱になる保証がない。**curl で公開エンドポイントも叩いて切り分ける。**"
echo
echo "対象: \`$T1\`（[1/2]）／ \`$T2\`（[2/2]）"

echo
echo "## A. ログイン済みの Chrome（いつもの見え方）"
echo
echo '```json'
cd "$W" && "$NODE_BIN" "$PROBE" "$ME" "$T1" "$T2" 2>&1 | head -40 | secrets
echo '```'

echo
echo "## B. oEmbed（**cookie を送らない。X の公開 API**）"
echo
echo "**200 が返れば公開されている。** 404 なら非公開か存在しない。"
echo
echo '```'
for id in "$T1" "$T2"; do
  U="https://publish.twitter.com/oembed?url=https%3A%2F%2Fx.com%2F$ME%2Fstatus%2F$id"
  CODE="$(curl -sS -o /tmp/.x142-oe.json -w '%{http_code}' --max-time 25 "$U" 2>/dev/null || echo ERR)"
  printf '  %s  HTTP %s\n' "$id" "$CODE"
  if [ "$CODE" = "200" ]; then
    head -c 220 /tmp/.x142-oe.json 2>/dev/null | secrets; echo
  else
    head -c 160 /tmp/.x142-oe.json 2>/dev/null | secrets; echo
  fi
done
rm -f /tmp/.x142-oe.json
echo '```'

echo
echo "## C. syndication（埋め込み用の公開エンドポイント）"
echo
echo '```'
for id in "$T1" "$T2"; do
  U="https://cdn.syndication.twimg.com/tweet-result?id=$id&lang=ja&token=x"
  CODE="$(curl -sS -o /tmp/.x142-sy.json -w '%{http_code}' --max-time 25 \
          -H 'User-Agent: Mozilla/5.0' "$U" 2>/dev/null || echo ERR)"
  printf '  %s  HTTP %s  %s bytes\n' "$id" "$CODE" "$(wc -c < /tmp/.x142-sy.json 2>/dev/null | tr -d ' ')"
  if [ -s /tmp/.x142-sy.json ]; then
    "$NODE_BIN" -e '
const fs=require("fs");
try{
  const o=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log("    text先頭: "+String(o.text||"").split("\n")[0].slice(0,30));
  console.log("    画像: "+((o.photos&&o.photos.length)||(o.mediaDetails&&o.mediaDetails.length)||0)+" 枚");
  console.log("    親: "+(o.in_reply_to_status_id_str||"（なし）"));
}catch(e){ console.log("    JSON ではない: "+String(fs.readFileSync(process.argv[1],"utf8")).slice(0,100)); }
' /tmp/.x142-sy.json 2>&1 | secrets
  fi
done
rm -f /tmp/.x142-sy.json
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| A | B / C | 意味 |"
echo "| --- | --- | --- |"
echo "| 見える | **返る** | **公開されている。** \`x140\` の 0 件 はプローブの作りのせい |"
echo "| 見える | **404** | **非公開・センシティブ・凍結のどれか。** アカウント側の問題 |"
echo "| 見えない | 404 | **投稿が無い** |"
echo
echo "**B と C は cookie を送らないので、第三者の目線そのもの。**"
echo "ブラウザの JS やログイン壁にも左右されない。"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

rm -f "$PROBE"
[ -f "$OUT" ] && { secrets < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'HTTP 200' "$OUT" 2>/dev/null; then
  echo "公開エンドポイントが 200 を返した。投稿は公開されている / $(basename "$OUT")"
else
  echo "**公開エンドポイントが 200 を返していない。レポート全文を読むこと** / $(basename "$OUT")"
fi
