#!/bin/bash
# **PAY ID のスレッドが「どこまで出たか」を確定させる。読むだけ。費用 $0。最優先。**
#
# ## 分かっていること（`x165` のレポート・2026-09-27 15:44 JST）
#
#   キューの thread_chain 3 本すべて  tweet_id=**無い**
#   publish-payid-oneshot.log（12:00）
#     [post-via-playwright] attached 4/4 image(s)
#     [step] navigate-target      ← **返信先へ移動している**
#     [step] find-reply-textarea  ← **返信欄を探している**
#     [x154] like 付いた
#     {"ok":false,"step":"thread-reply-1-exec", ...}
#
# base64 を復号すると `BASEで作られたショップ——の個人商店みたい…` で、
# **これは [2/3] の本文。** つまり **[1/3] は出ていて、[2/3] で落ちた**ように見える。
#
# **だがこれは推測である。** `navigate-target` の行だけでは、
# 自分の [1/3] へ移動したのか別のものへ移動したのか区別できない。
# **キューに id が無いので、キューからは答えが出ない。**
#
# ## だから自分の TL を直接 見る（**一次情報**）
#
#   ① `publish-payid-oneshot.log` を**丸ごと** grep して tweet id / status URL を探す
#   ② キューの行を**キーを選ばず全部**出す（`x165` は 11 キーしか出していない）
#   ③ **自分のプロフィールの最新の投稿を DOM から読む**（これが決め手）
#
# ## やらないこと
#
# **投稿しない。消さない。キューも plist も触らない。LLM も呼ばない（$0）。**
# **消すかどうかは利用者が決める**（過去に承認なしで消して差し戻された経緯がある）。
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
OUT="${OPS_REPORT_DIR:-/tmp}/payid-thread-truth.md"
PROBE="$W/.x167-probe.js"
ME="heng_ji31590"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
# **自分のハンドルは伏せない。** 確認してもらう対象そのもの
clean() { hide | sed -E "s/@<伏せ>\/status/@$ME\/status/g"; }

{
echo "# PAY ID のスレッドはどこまで出たか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 投稿も削除もしていない。**消すかどうかは利用者が決める。**"

echo
echo "## 1. ログの全体から tweet id / URL を探す"
echo
echo "**\`x165\` は末尾 14 行しか出していない。** 頭から見る。"
echo
echo '```'
F="$L/publish-payid-oneshot.log"
if [ ! -f "$F" ]; then
  echo "  **ログが無い: publish-payid-oneshot.log**"
else
  printf '  %s 行 / %s bytes / 更新 %s\n' \
    "$(wc -l < "$F" | tr -d ' ')" "$(wc -c < "$F" | tr -d ' ')" \
    "$(stat -f '%Sm' -t '%m-%d %H:%M:%S' "$F" 2>/dev/null)"
  echo
  echo "  --- status URL / 19 桁前後の数字 ---"
  grep -oE 'status/[0-9]{15,25}|"(x_tweet_id|tweet_id|rest_id)"[[:space:]]*:[[:space:]]*"?[0-9]{15,25}' "$F" 2>/dev/null \
    | sort -u | head -20 | sed 's/^/    /'
  N="$(grep -cE 'status/[0-9]{15,25}|(x_tweet_id|tweet_id|rest_id)' "$F" 2>/dev/null | head -1)"
  case "$N" in ''|*[!0-9]*) N=0 ;; esac
  [ "$N" = "0" ] && echo "    **1 本も無い。ログからは id が取れない。**"
  echo
  echo "  --- 先頭 40 行（何をしてから落ちたか）---"
  head -40 "$F" 2>/dev/null | cut -c1-190 | clean | sed 's/^/    /'
fi
echo '```'

echo
echo "## 2. キューの行を、キーを選ばず全部 出す"
echo
echo "**\`x165\` は 11 キーだけ出した。** id が別のキーに入っているかもしれない。"
echo
echo '```json'
node -e '
  const fs = require("fs");
  const [fp, id] = process.argv.slice(1);
  let j; try { j = JSON.parse(fs.readFileSync(fp, "utf8")); }
  catch (e) { console.log("  **読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const r = rows.find((x) => x && String(x.id || "") === id);
  if (!r) { console.log("  **id が無い: " + id + "**"); process.exit(0); }
  // 本文は長いので削る。それ以外は全部 出す
  const shown = JSON.parse(JSON.stringify(r, (k, v) =>
    (typeof v === "string" && v.length > 120) ? v.slice(0, 120) + "…(略)" : v));
  console.log(JSON.stringify(shown, null, 2).split("\n").map((l) => "  " + l).join("\n"));
' "$D/post_queue.json" "blog-promo-20260927-payid-a" 2>&1 | clean
echo '```'

echo
echo "## 3. 自分の TL の最新の投稿を読む（**これが決め手**）"
echo
echo "**キューとログで分からないなら、実物を見る。**"
echo
# **プローブはワークスペースの中に置く。** $TMPDIR だと playwright-core が解決できない
cat > "$PROBE" <<'PJS'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
const ME = process.env.X_ME || "heng_ji31590";
(async () => {
  let b, p;
  try {
    b = await chromium.connectOverCDP(CDP, { timeout: 20000 });
    const ctx = b.contexts()[0];
    if (!ctx) { console.log(JSON.stringify({ ok: false, error: "no context" })); return; }
    p = await ctx.newPage();
    await p.goto("https://x.com/" + ME + "/with_replies", { waitUntil: "domcontentloaded", timeout: 30000 });
    await p.waitForTimeout(5000);
    const rows = await p.evaluate((me) => {
      const out = [];
      for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
        const a = [...art.querySelectorAll('a[href*="/status/"]')]
          .map((x) => x.getAttribute("href") || "")
          .find((h) => new RegExp("^/" + me + "/status/\\d+").test(h));
        const t = art.querySelector('[data-testid="tweetText"]');
        const time = art.querySelector("time");
        out.push({
          url: a ? "https://x.com" + a.split("/photo/")[0] : null,
          at: time ? time.getAttribute("datetime") : null,
          text: (t ? t.textContent : "").replace(/\s+/g, " ").slice(0, 110),
        });
        if (out.length >= 12) break;
      }
      return out;
    }, ME);
    console.log(JSON.stringify({ ok: true, count: rows.length, rows }, null, 2));
  } catch (e) {
    console.log(JSON.stringify({ ok: false, error: String((e && e.message) || e).slice(0, 160) }));
  } finally {
    try { if (p) await p.close(); } catch {}
    try { if (b) await b.close(); } catch {}
  }
})();
PJS
echo '```json'
X_ME="$ME" node "$PROBE" 2>&1 | cut -c1-220 | clean | sed 's/^/  /'
echo '```'
rm -f "$PROBE"
echo
echo "**取れなければ「取れない」と書く。** 推測の結論は置かない（最上位ルール 11）。"

echo
echo "## 4. 招待コードとリンクが出ているか"
echo
echo "**[1/3] に \`YY8RQV\` と \`s.payid.jp/nNE1nwcd\` を必ず入れる**という指示だった。"
echo "**出ているなら、その 1 本だけでも用は足りている。** 判断材料にする。"
echo
echo '```'
if [ -f "$F" ]; then
  printf '  ログに YY8RQV     %s 箇所\n' "$(c="$(grep -c 'YY8RQV' "$F" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0;; esac; printf '%s' "$c")"
  printf '  ログに nNE1nwcd   %s 箇所\n' "$(c="$(grep -c 'nNE1nwcd' "$F" 2>/dev/null | head -1)"; case "$c" in ''|*[!0-9]*) c=0;; esac; printf '%s' "$c")"
else
  echo "  **ログが無いので数えられない**"
fi
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §3 の出方 | 結論 |"
echo "| --- | --- |"
echo "| **[1/3] の文が在り、[2/3] が無い** | **途中まで出た。** 続きを足すか、消して出し直すかを利用者が決める |"
echo "| 3 本 とも無い | **1 本も出ていない。** 出し直せばよい |"
echo "| 3 本 とも在る | **全部 出ている。** キューの記録が漏れただけ |"
echo "| \`ok:false\` で取れない | **Chrome か CDP の問題。** 数字は書かない |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '自分の TL の最新の投稿' "$OUT" 2>/dev/null; then
  echo "スレッドがどこまで出たかを確かめた / $(basename "$OUT")"
else
  echo "**確かめられていない。レポートを確認すること** / $(basename "$OUT")"
fi
