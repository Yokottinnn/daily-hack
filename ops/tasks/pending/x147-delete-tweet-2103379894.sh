#!/bin/bash
# **`2103379894306750770` を削除する。まだ走らない。費用 $0。**
#
# ## これは `ops/tasks/pending/` に置いてある＝**実行されない**
#
# `scripts/ops-run-tasks.sh:176` は `git ls-tree --name-only origin/main:ops/tasks` を
# **非再帰で**回し、`*.sh` でないものを飛ばす。`pending` はディレクトリなので飛ばされる。
#
#   走らせるとき: **`ops/tasks/` の直下へ移す**（`git mv`）
#
# **削除は取り消せない。** 利用者が「消す」と言うまで、ここから動かさない。
#
# ## 消す前に本文を控えてある
#
# 消すと何が起きたかの証拠も消える。**`x145` が既に一次情報を取ってある。**
#
#   本文  「シも今年は結局満額いったわ😉」  ← **「アタ」が落ちている**
#   親    （なし）                          ← 返信のつもりが単独の投稿になった
#   出所  comment-warmup / entry comment-20260925-1603-2
#        published_via: auto-reply-no-approval
#
# このタスクも**消す直前にもう一度 本文を取って**レポートに残す。**二重に控える。**
#
# ## rc=0 を証拠にしない（最上位ルール 13）
#
# 「削除ボタンを押せた」は「消えた」ではない。
# **消したあと syndication を叩いて 404 になることで確かめる。**
#
# ## やらないこと
#
# **他の投稿に触らない**（id を 1 つだけ受け取り、URL も id で組む）。
# **ループの起動・停止をしない**（`x146` の担当）。**LLM も呼ばない（$0）。**
set -uo pipefail

ID="2103379894306750770"
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/delete-tweet.md"
JS="$W/.x147-delete.js"      # **ワークスペースの中に置く。** $TMPDIR だと playwright-core が解決できない
RAW="$W/.x147-tweet.json"

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
const out = (o) => console.log(JSON.stringify(o));

(async () => {
  let browser, page, step = "connect";
  try {
    browser = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    // **既存のログイン済みコンテキストを使う。** newContext() は cookie を持たない
    const ctx = browser.contexts()[0];
    if (!ctx) { out({ ok: false, step, error: "no context" }); return; }
    page = await ctx.newPage();

    step = "goto";
    await page.goto(`https://x.com/i/status/${id}`, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(3500);

    step = "find-article";
    const art = await page.$('article[data-testid="tweet"]');
    if (!art) { out({ ok: false, step, error: "article が出ない（消えている／見えない）" }); return; }

    step = "caret";
    const caret = await art.$('[data-testid="caret"]');
    if (!caret) { out({ ok: false, step, error: "caret が無い（自分の投稿ではない？）" }); return; }
    await caret.click();
    await page.waitForTimeout(1200);

    step = "menu";
    const menu = await page.$('[data-testid="Dropdown"], [role="menu"]');
    if (!menu) { out({ ok: false, step, error: "メニューが開かない" }); return; }
    const items = await menu.$$('[role="menuitem"]');
    const labels = [];
    let del = null;
    for (const it of items) {
      const t = ((await it.textContent()) || "").trim();
      labels.push(t);
      if (/削除|Delete/.test(t)) del = it;
    }
    if (!del) { out({ ok: false, step, error: "削除の項目が無い", labels }); return; }

    step = "click-delete";
    await del.click();
    await page.waitForTimeout(1200);

    step = "confirm";
    const btn = await page.$('[data-testid="confirmationSheetConfirm"]');
    if (!btn) { out({ ok: false, step, error: "確認ダイアログが出ない", labels }); return; }
    await btn.click();
    await page.waitForTimeout(3500);

    out({ ok: true, step: "done", labels });
  } catch (e) {
    out({ ok: false, step, error: String(e && e.message || e) });
  } finally {
    try { if (page) await page.close(); } catch {}
    try { if (browser) await browser.close(); } catch {}
  }
})();
DELJS

{
echo "# \`$ID\` を削除する（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"

echo
echo "## 1. 消す直前の本文（**二重に控える**）"
echo
C1="$(fetch_tweet)"
echo '```'
printf '  HTTP %s\n' "$C1"
if [ "$C1" = "200" ] && [ -s "$RAW" ]; then
  node -e '
    const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    console.log("  本文: " + JSON.stringify(d.text||""));
    console.log("  投稿時刻: " + (d.created_at||"-"));
    console.log("  親: " + (d.in_reply_to_status_id_str||"（なし）"));
    console.log("  画像: " + ((d.photos||[]).length) + " 枚");
  ' "$RAW" 2>&1 | clean
else
  echo "  **200 で取れない。もう消えているか、経路が塞がれている。**"
fi
echo '```'
if [ "$C1" != "200" ]; then
  echo
  echo "- **消す対象が見つからない。何もせずに終わる。**"
  rm -f "$JS" "$RAW"
  echo
  echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
  exit 0
fi

echo
echo "## 2. 削除を実行"
echo
echo '```json'
RES="$(node "$JS" "$ID" 2>&1)"
printf '%s\n' "$RES" | clean | sed 's/^/  /'
echo '```'

echo
echo "## 3. 消えたことの証拠（**「押せた」は「消えた」ではない**）"
echo
echo "もう一度 syndication を叩く。**404 になって初めて消えている。**"
echo
C2="$(fetch_tweet)"
echo '```'
printf '  HTTP %s\n' "$C2"
echo '```'
echo
case "$C2" in
  404) echo "- **消えた。** 公開エンドポイントから引けなくなった" ;;
  200) echo "- **まだ残っている。** 削除は通っていない。§2 の \`step\` を見ること" ;;
  *)   echo "- **判定できない（HTTP $C2）。** 経路の問題かもしれない。時間を置いて確かめる" ;;
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
  echo "**消えていない。レポートを確認すること** / $(basename "$OUT")"
fi
