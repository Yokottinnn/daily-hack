#!/bin/bash
# **エラーの全文を取る。そのうえで、出せるなら出す。**
#
# ## t049 で分かったこと
#
#   * CDP の口は **18810**（`ensure-chrome.sh` に書いてある）。**9222 は私の誤り**
#   * その 18810 は**生きている**。`ensure-chrome.sh` も rc=0
#   * 画像は取り直せた（`1-summary.jpg` 245671 → 250062）
#   * `run-publish.sh` は `thread_chain mode` に入り、**本投稿の実行で落ちた**
#   * **両方とも `posted: false`。片肺にもなっていない。何も出ていない**
#
# ## 何が分からないままか
#
#   {"ok":false,"step":"thread-main-exec","error":"Command failed: ... "<MASKED>
#
# **エラーの本文を、私のマスクと `cut -c1-170` が食い潰した。**
# Chrome が悪いのではなく、**私が証拠を消した。**
# CLAUDE.md ルール 4 が言っている「『うまくいきませんでした』では足りない」を
# 自分でやってしまった。
#
# ## だからこのタスクは、まず全文を取る
#
#   * **`cut` で切らない。**
#   * **マスクを秘密だけに絞る。** 長い英数字を無差別に潰していたので、
#     エラー本文とファイルパスが巻き込まれていた。
#     潰すのは `sk-` 系・`Bearer` 系・`auth_token=` / `ct0=` のクッキーだけ
#   * `post-via-playwright.js` の**エラー処理と、直近のログ**も出す
#   * X にログインできているかを **`cdp-health.js` と開いているタブ**で見る
#
# ## 出せるなら出す
#
# 原因が分かる保証はないので、**全文を取ったうえで もう一度 `run-publish.sh` を叩く。**
# 失敗しても、そのときは**全文が残る。**
#
# ## 二重投稿をしない
#
# 開始前に「投稿済み」を数え、1 件でもあれば何もしない。積み直さない。
# **片肺で終わったら、そう報告する。**
#
# **LLM を呼ばない（費用 $0）。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/publish-morning-verbose.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260905-morning-500-2026"
QJSON="$W/data/post_queue.json"
RUNPUB="$W/scripts/run-publish.sh"
PVP="$W/scripts/post-via-playwright.js"
HEALTH="$W/scripts/cdp-health.js"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
CDP="http://127.0.0.1:18810"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
# **秘密だけを潰す。** 長い英数字を無差別に消すと、エラー本文ごと消える（t049 の失敗）
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(AAAA)[A-Za-z0-9%._-]{30,}#\1<MASKED>#g'
}
clean() { hide | secrets; }

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=q.queue||q||[];
  console.log(rows.filter(e=>{
    if(!e||typeof e!=="object") return false;
    const t=(e.id||"")+" "+(e.text||"")+" "+(e.target_url||"");
    return t.includes("morning-500-2026")
        && (e.status==="posted"||e.x_tweet_id||e.tweet_id);
  }).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

entry_dump() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=q.queue||q||[];
  const e=rows.find(x=>x&&x.id===process.argv[2]);
  if(!e){ console.log("（該当エントリが無い）"); process.exit(0); }
  console.log(JSON.stringify({
    id:e.id, status:e.status, x_tweet_id:e.x_tweet_id||e.tweet_id||null,
    images:String(e.image_path||"").split(",").filter(Boolean).length,
    chain:(e.thread_chain||[]).map((c,i)=>({
      n:i+1, role:c.role||null, tweet_id:c.x_tweet_id||c.tweet_id||null,
      posted:!!(c.x_tweet_id||c.tweet_id||c.posted_at)
    })),
    error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
}

{
echo "# エラーの全文を取ってから出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> \`t049\` は **CDP の口が 18810 で生きている**ところまで突き止めたが、"
echo "> 本投稿の実行で落ちた。**そのエラー本文を、私のマスクと \`cut\` が食い潰した。**"
echo "> このタスクは **\`cut\` で切らず、マスクを秘密だけに絞って**全文を残す。"

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo; echo "- **キューが読めない。何もしない。**"; exit 1; fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo; echo "- → **既に出ている。何もしない。**"; echo; echo '```json'
  entry_dump | clean; echo '```'; exit 0
fi

echo
echo "## 1. 画像を取り直す"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
for f in 1-summary.jpg 2-matsuya.jpg 3-komeda.jpg 4-sukiya.jpg; do
  old="$( [ -f "$IMGDIR/$f" ] && wc -c < "$IMGDIR/$f" | tr -d ' ' || echo 0 )"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f.new" 2>/dev/null \
     && [ "$(wc -c < "$IMGDIR/$f.new" | tr -d ' ')" -ge 20000 ]; then
    mv "$IMGDIR/$f.new" "$IMGDIR/$f"
    printf '  %-16s %s → %s bytes\n' "$f" "$old" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
  else
    printf '  **取れない** %s\n' "$f"; rm -f "$IMGDIR/$f.new"
  fi
done
echo '```'

echo
echo "## 2. X にログインできているか"
echo
echo "\`ensure-chrome.sh\` の但し書き: **cookie がディスクに永続化できておらず、再起動＝即ログアウト。**"
echo
echo "### \`cdp-health.js\`"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（無い: $HEALTH）"; fi
echo '```'
echo
echo "### いま開いているタブ"
echo
echo '```'
curl -s --max-time 6 "$CDP/json/list" 2>/dev/null | "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  try{
    const j=JSON.parse(s);
    if(!j.length){ console.log("（タブが無い）"); return; }
    j.slice(0,12).forEach(t=>console.log((t.type||"?")+"  "+String(t.url||"").slice(0,110)));
  }catch(e){ console.log("読めない: "+e.message); }
});' 2>&1 | clean
echo '```'
echo
echo "**\`x.com/login\` や \`/i/flow/login\` が出ていればログアウトしている。**"

echo
echo "## 3. 直近のログ（**切らずに出す**）"
echo
for n in publish post-via-playwright ensure-chrome auto-x-publisher; do
  f="$W/logs/$n.log"
  [ -f "$f" ] || continue
  echo "### \`$n.log\` — 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  echo
  echo '```'
  tail -25 "$f" 2>/dev/null | clean
  echo '```'
  echo
done

echo
echo "## 4. \`post-via-playwright.js\` のエラー処理"
echo
if [ -f "$PVP" ]; then
  echo '```javascript'
  grep -nE 'throw|catch|error|Error|timeout|selector|waitFor|login|not found' "$PVP" 2>/dev/null \
    | head -40 | clean
  echo '```'
else
  echo "- **無い**（\`$PVP\`）"
fi

echo
echo "## 5. もう一度 出す（**全文を残す**）"
echo
if [ ! -x "$RUNPUB" ]; then echo "- **\`run-publish.sh\` が実行できない。**"; exit 1; fi
echo '```'
"$RUNPUB" "$ID" 2>&1 | tail -120 | clean
echo "(rc=$?)"
echo '```'

echo
echo "## 6. [1/2] と [2/2] は両方 出たか"
echo
AFTER="$(posted_count)"
echo "- 投稿済みエントリ: **${AFTER} 件**（開始前 ${BEFORE} 件）"
echo
echo '```json'
entry_dump | clean
echo '```'
echo
echo "**2 本とも \`posted: true\` でなければ、出ていないか片肺。黙って「出ました」と言わない。**"

echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0）。** **X 上の手動投稿はキューからは見えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -qE '"posted": true' "$OUT" 2>/dev/null; then
  echo "**告知を出した。chain の中身を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**まだ出せていない。エラーの全文をレポートに残した** / $(basename "$OUT")"
fi
