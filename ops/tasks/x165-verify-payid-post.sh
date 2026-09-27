#!/bin/bash
# **PAY ID パターン A が 9/27 12:00 に出たかを、一次情報で確かめる。読むだけ。費用 $0。**
#
# ## なぜ要るか
#
# `x159` で 9/27 12:00 JST の 1 回だけ走る plist を置いた。**置いたことは確認済み**
# （`launchctl print` で `state = not running` / `runs = 0`）。
# **だが「載った」は「出た」ではない**（最上位ルール 13）。
#
# ## 一次情報は 2 つだけ（最上位ルール 11）
#
#   ① キューの **`x_tweet_id` / `tweet_id`**
#   ② **投稿 URL の実物**
#
# **これ以外を根拠にしない。** ログの行数・`posted_today`・`rc=0`・過去レポートは
# 一次情報ではない。**ここで出すのは ① と、① から組んだ ② の実在確認だけ。**
#
# ## 気をつけること
#
# - **syndication は削除済みでも HTTP 200 を返す。** 本文が空かどうかで見る
#   （`x148` でこれを取り違えた）
# - **id が無ければ「無い」と書く。** 推測の結論を置かない
# - **ハンドルは伏せる**（公開リポジトリに載る）。**ただし自分の投稿 URL は伏せない**
#   ——これが確認してもらう対象そのもの
#
# ## やらないこと
#
# **投稿しない。キューを書き換えない。plist も触らない。LLM も呼ばない（$0）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
D="$W/data"
L="$W/logs"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
ID="blog-promo-20260927-payid-a"
LABEL="ai.openclaw.publish-payid-oneshot"
OUT="${OPS_REPORT_DIR:-/tmp}/payid-post-verify.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
clean() { hide; }

{
echo "# PAY ID パターン A は出たか（$(date '+%Y-%m-%d %H:%M') JST・\$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **読むだけ。** 投稿もキューの書き換えもしていない。"

echo
echo "## 1. キューの行（**一次情報 ①**）"
echo
echo '```json'
node -e '
  const fs = require("fs");
  const [fp, id] = process.argv.slice(1);
  let j; try { j = JSON.parse(fs.readFileSync(fp, "utf8")); }
  catch (e) { console.log("  **post_queue.json が読めない: " + e.message + "**"); process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) { console.log("  **配列が取れない**"); process.exit(0); }
  const r = rows.find((x) => x && String(x.id || "") === id);
  if (!r) {
    console.log("  **id が無い: " + id + "**");
    console.log("  （キュー全体 " + rows.length + " 行）");
    process.exit(0);
  }
  const keys = ["id","status","kind","auto_publish","scheduled_at","posted_at","x_tweet_id","tweet_id","error","attempts","last_error"];
  for (const k of keys) {
    if (!(k in r)) continue;
    let v = r[k];
    if (typeof v === "object") v = JSON.stringify(v).slice(0, 120);
    console.log("  " + String(k).padEnd(15) + " " + String(v).slice(0, 160));
  }
  const chain = Array.isArray(r.thread_chain) ? r.thread_chain : [];
  console.log("  thread_chain    " + chain.length + " 本");
  chain.forEach((c, i) => {
    const tid = c && (c.x_tweet_id || c.tweet_id || c.id);
    console.log("    [" + (i + 1) + "/" + chain.length + "] tweet_id=" + (tid || "**無い**"));
  });
' "$D/post_queue.json" "$ID" 2>&1
echo '```'
echo
echo "> **\`x_tweet_id\` が空なら、出ていない。** それが答えになる。"

echo
echo "## 2. 投稿 URL の実物（**一次情報 ②**）"
echo
echo "**§1 で取れた id だけを当たる。** 取れなければ、ここは空で終わる。"
echo
echo '```'
IDS="$(node -e '
  const fs = require("fs");
  const [fp, id] = process.argv.slice(1);
  let j; try { j = JSON.parse(fs.readFileSync(fp, "utf8")); } catch { process.exit(0); }
  const rows = Array.isArray(j) ? j : (j.items || j.queue || j.posts || Object.values(j));
  if (!Array.isArray(rows)) process.exit(0);
  const r = rows.find((x) => x && String(x.id || "") === id);
  if (!r) process.exit(0);
  const out = [];
  const push = (v) => { if (v && /^[0-9]{10,25}$/.test(String(v))) out.push(String(v)); };
  push(r.x_tweet_id); push(r.tweet_id);
  for (const c of (Array.isArray(r.thread_chain) ? r.thread_chain : [])) { if (c) { push(c.x_tweet_id); push(c.tweet_id); push(c.id); } }
  // **末尾に改行を付ける**（最上位ルール 14。付けないと最後の 1 行が読まれない）
  if (out.length) process.stdout.write([...new Set(out)].join("\n") + "\n");
' "$D/post_queue.json" "$ID" 2>/dev/null)"

if [ -z "$IDS" ]; then
  echo "  **tweet id が 1 本も取れない。投稿 URL は確かめられない。**"
else
  N=0
  printf '%s\n' "$IDS" | while IFS= read -r tid || [ -n "$tid" ]; do
    [ -n "$tid" ] || continue
    N=$((N+1))
    U="https://cdn.syndication.twimg.com/tweet-result?id=$tid&lang=ja"
    HTTP="$(curl -sS -o /tmp/.x165body -w '%{http_code}' "$U" 2>/dev/null || echo "000")"
    LEN="$(wc -c < /tmp/.x165body 2>/dev/null | tr -d ' ')"
    TXT="$(node -e '
      const fs=require("fs");
      let t="";
      try{ const j=JSON.parse(fs.readFileSync("/tmp/.x165body","utf8")); t=String(j.text||j.full_text||""); }catch{}
      process.stdout.write(t.replace(/\s+/g," ").slice(0,90));
    ' 2>/dev/null)"
    echo "  --- $tid ---"
    echo "  投稿 URL: https://x.com/heng_ji31590/status/$tid"
    printf '  syndication: HTTP %s / 本文 %s bytes\n' "$HTTP" "$LEN"
    if [ -n "$TXT" ]; then
      printf '  本文の頭: %s\n' "$TXT"
      echo "  → **在る。出ている。**"
    else
      echo "  本文: （空）"
      echo "  → **HTTP 200 でも本文が空なら、消えているか非公開。**（\`x148\` で取り違えた点）"
    fi
    echo
  done
  rm -f /tmp/.x165body
fi
echo '```'

echo
echo "## 3. 1 回だけの plist はどうなったか"
echo
echo "**走ったら自分を外して消える**作りにした。**消えていれば走った合図**になる"
echo "（ただし合図であって一次情報ではない。判断は §1・§2 で行う）。"
echo
echo '```'
if launchctl print "gui/$UID_N/$LABEL" >/dev/null 2>&1; then
  echo "  **まだ載っている**"
  launchctl print "gui/$UID_N/$LABEL" 2>/dev/null | grep -E '^[[:space:]]+(state|runs|last exit code) ' | sed 's/^/    /'
else
  echo "  載っていない（外れている）"
fi
if [ -f "$LA/$LABEL.plist" ]; then
  echo "  plist: **まだ在る** $(stat -f '%Sm' -t '%m-%d %H:%M' "$LA/$LABEL.plist" 2>/dev/null)"
else
  echo "  plist: 消えている"
fi
echo '```'

echo
echo "## 4. publisher のログの末尾（**参考。一次情報ではない**）"
echo
echo '```'
for n in auto-x-publisher publish-payid-oneshot; do
  f="$L/$n.log"
  if [ -f "$f" ]; then
    printf '  === %s（更新 %s）===\n' "$n" "$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
    tail -14 "$f" 2>/dev/null | cut -c1-200 | clean | sed 's/^/    /'
  else
    printf '  === %s: **ログが無い** ===\n' "$n"
  fi
  echo
done
echo '```'

echo
echo "---"
echo
echo "## 読み方"
echo
echo "| §1 の \`x_tweet_id\` | §2 の本文 | 結論 |"
echo "| --- | --- | --- |"
echo "| 在る | 在る | **出ている。** URL をそのまま報告する |"
echo "| 在る | 空 | **出たが消えている／見えない。** 原因を追う |"
echo "| 空・id ごと無い | — | **出ていない。** §4 で止まった場所を探す |"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.work" && mv "$OUT.work" "$OUT"; }

if grep -q '投稿 URL の実物' "$OUT" 2>/dev/null; then
  echo "PAY ID の投稿を一次情報で確かめた / $(basename "$OUT")"
else
  echo "**確かめられていない。レポートを確認すること** / $(basename "$OUT")"
fi
