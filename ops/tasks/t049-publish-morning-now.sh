#!/bin/bash
# **積んであるモーニング告知を出す。CDP の口は決め打ちせず、実物のソースから読む。**
#
# ## t048 で何が起きたか
#
# 積むところまでは契約どおり通った。
#
#   {"ok":true,"id":"blog-promo-20260905-morning-500-2026"}
#   画像 4 枚とも取得 / thread_chain 2 本
#
# 止まったのは Chrome の接続確認だけ。**ただしその判定は当て推量だった。**
# `curl http://127.0.0.1:9222/json/version` を叩いて NG としたが、
# **9222 という根拠はどこにも無い。** `docs/x-publisher-contract.md` に
# ポートの記載は無く、実物を読まずに決めた。
#
# **Chrome は健全なのに、私が違う穴を覗いていただけ**でありうる。
# だからこのタスクは、**まずソースから口を読み取る。**
#
# ## やること
#
#   1. `ensure-chrome.sh` と `post-via-playwright.js` を**出して読む**
#   2. そこに書かれているポート・エンドポイントを**抜き出す**（決め打ちしない）
#   3. 見つかった口を全部 叩いて、生きているものを探す
#   4. Chrome のプロセスが居るかを見る
#   5. **口が生きていたら `run-publish.sh <id>` を叩く**
#   6. 出た後、[1/2] と [2/2] が両方 出たかを**エントリの中身で確かめる**
#
# ## 二重投稿をしない
#
# **積み直さない。** t048 が積んだエントリをそのまま使う。
# 開始前に「投稿済み」を数え、1 件でもあれば何もしない。
#
# ## 片肺で終わったら、そう報告する
#
# ログアウト状態だと **[1/2] だけ出て [2/2] が落ちる。**
# 出た後に `thread_chain` の結果を出すので、**片方だけなら次のタスクで [2/2] を足す。**
# 黙って「出ました」と言わない。
#
# **LLM を呼ばない（費用 $0）。ハンドルは伏せる。トークンは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/publish-morning-now.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260905-morning-500-2026"
QJSON="$W/data/post_queue.json"
RUNPUB="$W/scripts/run-publish.sh"
ENSURE="$W/scripts/ensure-chrome.sh"
PVP="$W/scripts/post-via-playwright.js"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

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
    id:e.id, kind:e.kind, status:e.status,
    x_tweet_id:e.x_tweet_id||e.tweet_id||null,
    images:String(e.image_path||"").split(",").filter(Boolean).length,
    chain:(e.thread_chain||[]).map((c,i)=>({
      n:i+1, role:c.role||null,
      tweet_id:c.x_tweet_id||c.tweet_id||null,
      posted:!!(c.x_tweet_id||c.tweet_id||c.posted_at),
      images:String(c.image_path||"").split(",").filter(Boolean).length
    })),
    posted_at:e.posted_at||null, error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
}

{
echo "# 積んである告知を出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> t048 は積むところまで成功し、**CDP の判定だけで止まった。**"
echo "> だがその \`127.0.0.1:9222\` に根拠は無かった。**今回はソースから口を読む。**"

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then
  echo; echo "- **\`post_queue.json\` が読めない。何もしない。**"; exit 1
fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo; echo "- → **既に出ている。何もしない。**"; echo; echo '```json'
  entry_dump | hide | mask; echo '```'; exit 0
fi
echo
echo "### t048 が積んだエントリ（積み直さない）"
echo
echo '```json'
entry_dump | hide | mask
echo '```'

echo
echo "## 0-B. 画像を取り直す（**古い絵で出さないため**）"
echo
echo "\`t048\` は画像を \`$IMGDIR\` に**取り出し済み**で、キューのエントリはその"
echo "**実ファイルを指している。** その後に絵を差し替えているので、"
echo "**取り直さないと古い絵のまま出る。** パスは同じなのでキューは触らなくてよい。"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
BAD=0
echo '```'
for f in 1-summary.jpg 2-matsuya.jpg 3-komeda.jpg 4-sukiya.jpg; do
  old="$( [ -f "$IMGDIR/$f" ] && wc -c < "$IMGDIR/$f" | tr -d ' ' || echo 0 )"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f.new" 2>/dev/null \
     && [ -s "$IMGDIR/$f.new" ] && [ "$(wc -c < "$IMGDIR/$f.new" | tr -d ' ')" -ge 20000 ]; then
    mv "$IMGDIR/$f.new" "$IMGDIR/$f"
    new="$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    if [ "$old" = "$new" ]; then
      printf '  同じ      %-16s %s bytes\n' "$f" "$new"
    else
      printf '  **更新**  %-16s %s → %s bytes\n' "$f" "$old" "$new"
    fi
  else
    printf '  **取れない** %s（origin/main に無い）\n' "$f"; BAD=1
    rm -f "$IMGDIR/$f.new"
  fi
done
echo '```'
if [ "$BAD" = "1" ]; then
  echo
  echo "- **画像が揃わない。出さない。**"
  exit 1
fi

echo
echo "## 1. Chrome まわりのソースを出して読む"
echo
echo "### \`ensure-chrome.sh\`"
echo
if [ -f "$ENSURE" ]; then
  echo '```bash'
  cat "$ENSURE" 2>/dev/null | head -70 | cut -c1-170 | hide | mask
  echo '```'
else
  echo "- **無い**（\`$ENSURE\`）"
fi
echo
echo "### \`post-via-playwright.js\` の接続まわり"
echo
if [ -f "$PVP" ]; then
  echo '```javascript'
  grep -nE 'connectOverCDP|launch|9[0-9]{3}|endpoint|wsEndpoint|http://|userDataDir|channel' "$PVP" 2>/dev/null \
    | head -25 | cut -c1-170 | hide | mask
  echo '```'
else
  echo "- **無い**（\`$PVP\`）"
fi
echo
echo "### \`run-publish.sh\` の冒頭"
echo
if [ -f "$RUNPUB" ]; then
  echo '```bash'
  head -40 "$RUNPUB" 2>/dev/null | cut -c1-170 | hide | mask
  echo '```'
else
  echo "- **無い**（\`$RUNPUB\`）"
fi

echo
echo "## 2. ソースに書かれている口を全部 叩く（決め打ちしない）"
echo
PORTS="$(cat "$ENSURE" "$PVP" "$RUNPUB" 2>/dev/null \
  | grep -oE '(127\.0\.0\.1|localhost):[0-9]{2,5}|remote-debugging-port=[0-9]{2,5}|\b9[0-9]{3}\b' \
  | grep -oE '[0-9]{2,5}$' | sort -un | head -8)"
[ -z "$PORTS" ] && PORTS="9222"
echo '```'
LIVE=""
for p in $PORTS; do
  v="$(curl -s --max-time 4 "http://127.0.0.1:$p/json/version" 2>/dev/null)"
  if [ -n "$v" ]; then
    printf '  **生きている** :%-6s %s\n' "$p" "$(printf '%s' "$v" | tr -d '\n' | cut -c1-90)"
    LIVE="${LIVE:+$LIVE }$p"
  else
    printf '  応答なし     :%s\n' "$p"
  fi
done
echo '```'
echo
echo "- ソースから拾った口: \`$(echo $PORTS | tr '\n' ' ')\`"
echo "- 生きている口: **\`${LIVE:-なし}\`**"

echo
echo "## 3. Chrome のプロセス"
echo
echo '```'
ps ax -o pid,etime,command 2>/dev/null \
  | grep -iE 'chrome|chromium' | grep -v grep \
  | head -6 | cut -c1-160 | hide | mask
echo '```'

echo
echo "## 4. \`ensure-chrome.sh\` を走らせる（stderr も出す）"
echo
if [ -x "$ENSURE" ]; then
  echo '```'
  "$ENSURE" 2>&1 | tail -20 | cut -c1-170 | hide | mask
  echo "(rc=$?)"
  echo '```'
  # 走らせた後にもう一度 全部の口を叩く
  for p in $PORTS; do
    curl -s --max-time 4 "http://127.0.0.1:$p/json/version" >/dev/null 2>&1 \
      && LIVE="${LIVE:+$LIVE }$p"
  done
  LIVE="$(echo $LIVE | tr ' ' '\n' | sort -un | tr '\n' ' ' | sed 's/ $//')"
  echo
  echo "- 走らせた後に生きている口: **\`${LIVE:-なし}\`**"
elif [ -f "$ENSURE" ]; then
  echo "- **実行権が無い**（\`$ENSURE\`）"
else
  echo "- **無い**（\`$ENSURE\`）"
fi

echo
echo "## 5. 出す"
echo
if [ ! -x "$RUNPUB" ]; then
  echo "- **\`run-publish.sh\` が実行できない。出せない。**"
  echo
  echo '```'
  ls -la "$W/scripts" 2>/dev/null | grep -iE 'publish|post|chrome' | cut -c1-140
  echo '```'
  exit 1
fi
if [ -z "$LIVE" ]; then
  echo "> **CDP の口がひとつも生きていない。** 上の 1〜4 章に実物が出ている。"
  echo "> ここで諦めず、**\`run-publish.sh\` 自身の判断に委ねて叩く。**"
  echo "> \`run-publish.sh\` は冒頭で \`ensure-chrome.sh\` を呼ぶので、"
  echo "> 私の口の探し方が間違っていただけなら、これで通る。"
  echo "> **通らなければ、その実物のエラーが下に出る。**「うまくいきませんでした」では足りない。"
  echo
fi
echo '```'
"$RUNPUB" "$ID" 2>&1 | tail -50 | cut -c1-170 | hide | mask
echo "(rc=$?)"
echo '```'

echo
echo "## 6. [1/2] と [2/2] は両方 出たか"
echo
AFTER="$(posted_count)"
echo "- 投稿済みエントリ: **${AFTER} 件**（開始前 ${BEFORE} 件）"
echo
echo '```json'
entry_dump | hide | mask
echo '```'
echo
echo "**\`chain\` の 2 本とも \`posted: true\` でなければ、片肺で終わっている。**"
echo "その場合は [2/2] を足すタスクを別に出すこと。**黙って「出ました」と言わない。**"

echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0）。** **X 上の手動投稿はキューからは見えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -qE '"posted": true' "$OUT" 2>/dev/null; then
  echo "**告知を出した。chain の中身を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。** CDP の口とエラーの実物をレポートに出した / $(basename "$OUT")"
fi
