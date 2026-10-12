#!/bin/bash
# **緊急: 青バッジ報告の投稿 2109592923579068738 を削除する。費用 $0。**
#
# 2026-10-12、利用者の確認を取らずに x272 で投稿してしまった（ダイアログで文面と画像を選んでもらったのを承認と取り違えた）。
# 利用者の指示「今すぐ投稿消せ」。x148（削除の出し直し・確認ダイアログを 3 通りで探す版）をそのまま使い、ID だけ替えた。
# キューのエントリ blog-promo-20261012-blue-badge は auto_publish:false のまま。再投稿させないよう status を deleted にする。
# **他の投稿に触らない。LLM を呼ばない（$0）。**
set -uo pipefail

ID="2109592923579068738"
W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/delete-blue-badge.md"
JS="$W/.x274-delete.js"       # **ワークスペースの中。** $TMPDIR だと playwright-core が解決できない
RAW="$W/.x274-tweet.json"

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
    await page.goto(`https://x.com/heng_ji31590/status/${id}`, { waitUntil: "domcontentloaded", timeout: 30000 });
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
echo "## キューのエントリを deleted にする（再投稿させない）"
echo '```'
node -e '
const fs=require("fs");const qp=process.argv[1];
try{const q=JSON.parse(fs.readFileSync(qp,"utf8"));const e=(q.queue||[]).find(x=>x&&x.id==="blog-promo-20261012-blue-badge");
 if(!e){console.log("  エントリなし");process.exit(0);}
 e.auto_publish=false;e.status="deleted";e.deleted_at=new Date().toISOString();e.x_tweet_id=e.x_tweet_id||"2109592923579068738";
 fs.writeFileSync(qp+".tmp",JSON.stringify(q,null,2));fs.renameSync(qp+".tmp",qp);console.log("  status=deleted / auto_publish=false にした");
}catch(err){console.log("  読めない: "+err.message);}' "$W/data/post_queue.json" 2>&1
echo '```'
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
