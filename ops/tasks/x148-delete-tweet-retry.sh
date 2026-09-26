#!/bin/bash
# **`2103379894306750770` の削除を出し直す。費用 $0。**
#
# ## x147 がどこで落ちたか
#
#   {"ok":false,"step":"confirm","error":"確認ダイアログが出ない",
#    "labels":["削除","プロフィールに固定する", ...]}
#   再取得: HTTP 200  ← **まだ残っている**
#
# **メニューは開いた。「削除」も在った。押した。そのあとが出なかった。**
#
# ## 何を変えるか（**推測で当て直さない**）
#
# | x147 | x148 |
# | --- | --- |
# | `page.$` で 1 回 見るだけ | **`waitForSelector` で 8 秒 待つ** |
# | `waitForTimeout(1200)` | **待ってから探す、ではなく 出るまで待つ** |
# | セレクタ 1 本 | **3 本 試す**（testid / dialog 内のボタン / 文字が「削除」のボタン） |
# | 出なければ諦める | **出なければ DOM を吐く。** 次はもう推測しない |
# | menuitem を click | **menuitem の中の実体も試す**（X は当たり判定が内側にあることがある） |
#
# ## rc=0 を証拠にしない（最上位ルール 13）
#
# **「押せた」は「消えた」ではない。** 消したあと syndication が 404 になることで確かめる。
# x147 は押せていたのに残っていた。
#
# ## やらないこと
#
# **他の投稿に触らない。ループを触らない。LLM も呼ばない（$0）。**
set -uo pipefail

ID="2103379894306750770"
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/delete-tweet-retry.md"
JS="$W/.x148-delete.js"       # **ワークスペースの中。** $TMPDIR だと playwright-core が解決できない
RAW="$W/.x148-tweet.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

fetch_tweet() {
  curl -s -m 25 -o "$RAW" -w '%{http_code}' \
    "https://cdn.syndication.twimg.com/tweet-result?id=$ID&lang=ja&token=x" 2>/dev/null
}

cat > "$JS" <<'DELJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const id = process.argv[2];
const log = [];
const say = (m) => log.push(m);
const out = (o) => console.log(JSON.stringify(Object.assign({ log }, o), null, 1));

(async () => {
  let browser, page, step = "connect";
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = browser.contexts()[0];
    if (!ctx) { out({ ok: false, step, error: "no context" }); return; }
    page = await ctx.newPage();

    step = "goto";
    await page.goto(`https://x.com/i/status/${id}`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(4000);

    step = "find-article";
    const art = await page.waitForSelector('article[data-testid="tweet"]', { timeout: 15000 }).catch(() => null);
    if (!art) { out({ ok: false, step, error: "article が出ない（消えている／見えない）" }); return; }
    say("article あり");

    step = "caret";
    const caret = await art.$('[data-testid="caret"]');
    if (!caret) { out({ ok: false, step, error: "caret が無い" }); return; }
    await caret.click();
    say("caret を押した");

    step = "menu";
    const menu = await page.waitForSelector('[data-testid="Dropdown"], [role="menu"]', { timeout: 10000 }).catch(() => null);
    if (!menu) { out({ ok: false, step, error: "メニューが開かない" }); return; }
    const items = await menu.$$('[role="menuitem"]');
    let del = null;
    for (const it of items) {
      const t = ((await it.textContent()) || "").trim();
      if (/^(削除|Delete)/.test(t)) { del = it; break; }
    }
    if (!del) { out({ ok: false, step, error: "削除の項目が無い" }); return; }
    say("削除の項目を見つけた");

    step = "click-delete";
    // **X は当たり判定が内側にあることがある。** 外側 → 内側の順に試す
    await del.click().catch(() => {});
    let sheet = await page.waitForSelector('[data-testid="confirmationSheetConfirm"]', { timeout: 6000 }).catch(() => null);
    if (!sheet) {
      say("1 回目で確認が出ない。内側の要素を押し直す");
      const inner = await del.$('div[dir], span');
      if (inner) await inner.click().catch(() => {});
      sheet = await page.waitForSelector('[data-testid="confirmationSheetConfirm"]', { timeout: 6000 }).catch(() => null);
    }

    step = "confirm";
    if (!sheet) {
      // **2 本目・3 本目のセレクタ**
      say("testid で出ない。dialog の中のボタンを探す");
      const dlg = await page.$('[data-testid="confirmationSheetDialog"], [role="alertdialog"], [role="dialog"]');
      if (dlg) {
        const btns = await dlg.$$('[role="button"], button');
        for (const b of btns) {
          const t = ((await b.textContent()) || "").trim();
          say("  dialog 内のボタン: " + JSON.stringify(t));
          if (/^(削除|Delete)$/.test(t)) { sheet = b; break; }
        }
      }
    }
    if (!sheet) {
      // **出なければ DOM を吐く。次はもう推測しない**
      const dump = await page.evaluate(() => {
        const ids = [...document.querySelectorAll("[data-testid]")]
          .map((e) => e.getAttribute("data-testid"));
        const uniq = [...new Set(ids)].filter((t) => /confirm|sheet|dialog|delete|Confirm|Sheet|Dialog/i.test(t));
        const roles = [...document.querySelectorAll('[role="dialog"],[role="alertdialog"],[role="menu"]')]
          .map((e) => (e.getAttribute("role") || "") + " :: " + (e.textContent || "").trim().slice(0, 120));
        return { confirmish_testids: uniq, dialogs: roles, testid_count: ids.length };
      });
      out({ ok: false, step, error: "確認ダイアログが出ない", dump });
      return;
    }

    say("確認ダイアログが出た");
    await sheet.click();
    await page.waitForTimeout(4000);
    out({ ok: true, step: "done" });
  } catch (e) {
    out({ ok: false, step, error: String((e && e.message) || e) });
  } finally {
    try { if (page) await page.close(); } catch {}
    try { if (browser) await browser.close(); } catch {}
  }
})();
DELJS

{
echo "# \`$ID\` の削除を出し直す（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> \`x147\` は **\`confirm\` で落ちた**（メニューは開き、削除も押せたのに確認が出なかった）。"

echo
echo "## 1. まだ在るか"
echo
C1="$(fetch_tweet)"
echo '```'
printf '  HTTP %s\n' "$C1"
if [ "$C1" = "200" ] && [ -s "$RAW" ]; then
  node -e '
    const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    console.log("  本文: " + JSON.stringify(d.text||""));
    console.log("  投稿時刻: " + (d.created_at||"-"));
  ' "$RAW" 2>&1 | clean
fi
echo '```'
if [ "$C1" != "200" ]; then
  echo
  echo "- **もう無い。何もせずに終わる。**"
  rm -f "$JS" "$RAW"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 0
fi

echo
echo "## 2. 削除を実行（**出るまで待つ・3 本 試す・出なければ DOM を吐く**）"
echo
echo '```json'
node "$JS" "$ID" 2>&1 | clean | sed 's/^/  /'
echo '```'

echo
echo "## 3. 消えたことの証拠"
echo
C2="$(fetch_tweet)"
echo '```'
printf '  HTTP %s\n' "$C2"
echo '```'
echo
case "$C2" in
  404) echo "- **消えた。** 公開エンドポイントから引けなくなった" ;;
  200) echo "- **まだ残っている。** §2 の \`dump\` を見ること。**次は推測で当て直さない**" ;;
  *)   echo "- **判定できない（HTTP $C2）。** 経路の問題かもしれない" ;;
esac

rm -f "$JS" "$RAW"

echo
echo "## 4. 費用"
echo
echo "**DOM 操作と curl だけ。LLM を呼んでいない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q 'HTTP 404' "$OUT" 2>/dev/null; then
  echo "投稿を削除した（404 で確認済み） / $(basename "$OUT")"
else
  echo "**まだ消えていない。レポートの dump を確認すること** / $(basename "$OUT")"
fi
