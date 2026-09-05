#!/bin/bash
# **モーニング記事の告知スレッド（[1/2] + [2/2]）を X へ出す。**
#
# 本文と画像 4 枚は **2026-09-05 にこのチャットで実物を見たうえで承認済み**
# （最上位ルール 4「画像確認なしの投稿は絶対に許可されない」を満たしている）。
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
# 過去に 3 回（t002 / t004 / t006）外して **2 時間 20 分 失っている。**
# 外しやすいところを先に書いておく。
#
#   * **`blog-promo` は kind ではなくモードの名前。** 積む kind は **`"thread"`**
#   * **`id` は `blog-promo-` で始まらないと候補にならない**
#   * 画像のフィールドは **`image_path`**（`images` ではない）。**カンマ区切りで最大 4 枚**
#   * **スレッドは `thread_chain[]` を作り `run-publish.sh <id>` で出す。**
#     `auto-x-publisher.js` を 2 回叩いても同日ガードで [2/2] は構造的に出ない
#   * `queue-manager.js approve` は**存在しない**ので呼ばない
#
# ## 画像は origin/main から取り出す（作業ツリーを当てにしない）
#
# `ops-run-tasks.sh` は `git show origin/main:...` でタスクを読むだけで、
# **リポジトリの作業ツリーを main に切り替えない。** ディスク上のファイルは
# 別ブランチのままでありうる。だから**画像も `git show` で取り出す。**
#
# ## 二重投稿をしない
#
#   1. 開始前に「投稿済みエントリ」を数える。1 件でもあれば何もしない
#   2. ロックを置く
#   3. 出した後にもう一度数え、**2 件以上なら異常として報告する**
#
# **キューの件数ガードは、人が X 上で手で投稿したものを検知できない。**
# 2026-08-30 に実際に利用者が手で投稿している。**報告を見て人が確かめること。**
#
# ## Chrome がログアウトしていたら出さない
#
# cookie が永続化できておらず、再起動＝即ログアウト。その状態で `thread_chain` を
# 走らせると **[1/2] だけ出て [2/2] が落ちる。** CDP が健全でなければ**積むだけ**にして
# 投稿はしない（エントリはキューに残るので、あとから出せる）。
#
# **LLM を呼ばない（費用 $0）。ハンドルは伏せる。トークンは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-morning-thread.md"
LOCK="$W/data/.t048-morning-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
ENSURE="$W/scripts/ensure-chrome.sh"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20260905-morning-500-2026"
URL="https://daily-hack.fieldbeside.com/posts/morning-500-2026/"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

T1='ワンコインで食べれる超絶コスパ朝食をまとめたわよ。

・マクドナルド 180円 ソーセージマフィン
・なか卯 300円 ごはん・みそ汁つきの定食
・松屋 350円 玉子かけごはん＋小鉢2つ
・コメダ ドリンク代だけでパンと玉子

しかも牛丼チェーンは朝4:00から開いてる。
値段は全部そのチェーンの公式で確かめたやつよ。'

T2='「モーニングって何時までだっけ」で毎回 検索するのが面倒だったから、
チェーンごとの いちばん安い朝食と提供時間を1本の表にまとめたわよ。

'"$URL"

# キューの中で、この記事に紐づく「出たもの」を数える
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

{
echo "# モーニング告知スレッドを X へ出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> 本文と画像 4 枚は **2026-09-05 にチャットで実物を見たうえで承認済み**。"
echo "> \`kind:\"thread\"\` / \`id\` は \`blog-promo-\` 始まり / 画像は \`image_path\` にカンマ区切り /"
echo "> スレッドは \`thread_chain[]\` を \`run-publish.sh\` で出す——契約どおりに積む。"

echo
echo "## 0. もう出ていないか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みエントリ: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then
  echo
  echo "- **\`post_queue.json\` が読めない（\`$QJSON\`）。何もしない。**"
  exit 1
fi
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo
  echo "- → **既に出ている。何もしない。**"
  exit 0
fi
if [ -f "$LOCK" ]; then
  echo
  echo "- **ロックがある（$(cat "$LOCK" 2>/dev/null)）。二重に走らせない。**"
  exit 0
fi
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"
echo "- ロックを置いた"

echo
echo "## 1. 画像 4 枚を \`origin/main\` から取り出す"
echo
echo "作業ツリーは main とは限らないので、**\`git show\` で取り出す。**"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""
MISSING=0
echo '```'
for f in 1-summary.jpg 2-matsuya.jpg 3-komeda.jpg 4-sukiya.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f" 2>/dev/null \
     && [ -s "$IMGDIR/$f" ]; then
    sz=$(wc -c < "$IMGDIR/$f" | tr -d ' ')
    if [ "$sz" -lt 20000 ]; then
      printf '  **小さすぎる** %-16s %s bytes\n' "$f" "$sz"; MISSING=1
    else
      printf '  取得        %-16s %s bytes\n' "$f" "$sz"
      IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"
    fi
  else
    printf '  **取れない** %s（origin/main に無い）\n' "$f"; MISSING=1
    rm -f "$IMGDIR/$f"
  fi
done
echo '```'
if [ "$MISSING" = "1" ]; then
  echo
  echo "- **画像が揃っていない。積まないし、出さない。**"
  echo "- 画像なしで出すことは、この記事の告知では成立しない（表が中身そのもの）。"
  rm -f "$LOCK"
  exit 1
fi
echo
echo "- \`image_path\`: 4 枚（**カンマ区切り**）"

echo
echo "## 2. キューに積む（契約どおりの形）"
echo
if [ ! -f "$Q" ]; then
  echo "- **\`queue-manager.js\` が無い（\`$Q\`）。何もしない。**"
  rm -f "$LOCK"; exit 1
fi
ENQ_OUT="$("$NODE_BIN" -e '
const [id,t1,t2,csv,url]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1,
  image_path: csv,
  target_url: url,
  auto_publish: true,
  scheduled_at: new Date(Date.now()-60000).toISOString(),
  thread_chain: [
    { text:t1, role:"hook", image_path:csv },
    { text:t2, role:"cta",  url:url }
  ]
}));
' "$ID" "$T1" "$T2" "$IMGS" "$URL" | "$NODE_BIN" "$Q" enqueue 2>&1)"
echo '```json'
printf '%s\n' "$ENQ_OUT" | head -20 | hide | mask
echo '```'
echo
echo "- \`id\`: \`$ID\`（\`blog-promo-\` 始まり）"
echo "- \`kind\`: \`thread\` / \`thread_chain\`: **2 本**"

echo
echo "## 3. Chrome / CDP は健全か"
echo
echo "**ログアウト状態で \`thread_chain\` を走らせると [1/2] だけ出て [2/2] が落ちる。**"
echo
cdp_ok() { curl -s --max-time 5 http://127.0.0.1:9222/json/version >/dev/null 2>&1; }
CDP="NG"
if cdp_ok; then CDP="OK"
elif [ -x "$ENSURE" ]; then
  echo '```'
  "$ENSURE" 2>&1 | tail -6 | cut -c1-160 | hide | mask
  echo '```'
  cdp_ok && CDP="OK"
fi
echo
echo "- CDP: **$CDP**"

if [ "$CDP" != "OK" ]; then
  echo
  echo "- → **CDP が健全でないので投稿しない。** エントリはキューに残してある。"
  echo "- Chrome にログインし直したうえで、次のタスクで \`run-publish.sh $ID\` を叩けば出る。"
  echo
  echo "**まだ出していない。**"
  exit 0
fi

echo
echo "## 4. 出す（\`run-publish.sh $ID\`）"
echo
if [ ! -x "$RUNPUB" ]; then
  echo "- **\`run-publish.sh\` が無い／実行できない（\`$RUNPUB\`）。**"
  echo "- 積むところまでで止める。**出していない。**"
  ls -la "$W/scripts" 2>/dev/null | grep -iE 'publish|post' | cut -c1-140
  exit 1
fi
echo '```'
"$RUNPUB" "$ID" 2>&1 | tail -40 | cut -c1-170 | hide | mask
echo '```'

echo
echo "## 5. 出た件数を数え直す"
echo
AFTER="$(posted_count)"
echo "- 投稿済みエントリ: **${AFTER} 件**（開始前 ${BEFORE} 件）"
if [ "${AFTER:-0}" -gt 1 ] 2>/dev/null; then
  echo
  echo "- **2 件以上ある。二重投稿の疑い。人が確かめること。**"
elif [ "${AFTER:-0}" = "1" ]; then
  echo
  echo "- **1 件。想定どおり。**"
else
  echo
  echo "- **0 件のまま。出ていない。** 上の \`run-publish.sh\` の出力を読むこと。"
fi

echo
echo "### キューの当該エントリ"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=q.queue||q||[];
  const e=rows.find(x=>x&&x.id===process.argv[2]);
  if(!e){ console.log("（該当エントリが無い）"); }
  else console.log(JSON.stringify({
    id:e.id, kind:e.kind, status:e.status,
    x_tweet_id:e.x_tweet_id||e.tweet_id||null,
    images:String(e.image_path||"").split(",").length,
    chain:(e.thread_chain||[]).length,
    posted_at:e.posted_at||null, error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1 | hide | mask
echo '```'

echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0）。** 出たかどうかは 5 章の件数と \`x_tweet_id\` で判断すること。"
echo "**X 上の手動投稿はキューからは見えない。** 実物のタイムラインも確かめること。"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '想定どおり' "$OUT" 2>/dev/null; then
  echo "**モーニング告知スレッドを出した（1 件）** / $(basename "$OUT")"
elif grep -q 'CDP が健全でないので投稿しない' "$OUT" 2>/dev/null; then
  echo "積むところまで。**CDP が落ちていたので出していない** / $(basename "$OUT")"
else
  echo "出せていない。レポートを読むこと / $(basename "$OUT")"
fi
