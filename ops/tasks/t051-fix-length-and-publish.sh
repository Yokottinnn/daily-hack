#!/bin/bash
# **文字数オーバーを直して出す。原因は X の 280 上限を 13 超えていたこと。**
#
# ## 原因（t050 で確定）
#
# `t050` がエラーの全文を残したことで、渡していた本文が読めた。
#
#   [1/2] の X 重み: **293**（全角2・半角1）  上限 **280** → **13 超過**
#
# `post-via-playwright.js:125` にこう書いてある。
#
#   out({ ok:false, step, error: "X refused to enable the post button — nothing was posted" })
#
# **投稿ボタンが有効にならず、中止されていた。**
# Chrome も CDP（18810）も画像も、すべて正常だった。**文面だけが原因。**
#
# ## 直し方（2026-09-05 に利用者が指定）
#
# 「しかも牛丼チェーンは朝4:00から開いてる。」を**削除する。**
# 朝 4:00 の話は 4 枚目の画像で伝わるため、本文から落としても情報は落ちない。
#
#   直したあとの重み: [1/2] **252** / [2/2] **194**（どちらも 280 以内）
#
# ## やること
#
#   1. **積み直さない。** キューの当該エントリの `text` と `thread_chain[0].text` を**書き換える**
#   2. **書き換える前に重みを数え、280 を超えていたら書かない**（同じ轍を踏まない）
#   3. 画像を `origin/main` から取り直す（べき等）
#   4. `run-publish.sh` を叩く
#   5. `thread_chain` 2 本それぞれが出たかを出す
#
# ## 二重投稿をしない
#
# 開始前に「投稿済み」を数え、1 件でもあれば何もしない。
# **2 本とも `posted: true` でなければ「出ました」と言わない。**
#
# **LLM を呼ばない（費用 $0）。ハンドルは伏せる。マスクは秘密だけに絞る。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-length-and-publish.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260905-morning-500-2026"
QJSON="$W/data/post_queue.json"
RUNPUB="$W/scripts/run-publish.sh"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
URL="https://daily-hack.fieldbeside.com/posts/morning-500-2026/"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

T1='ワンコインで食べれる超絶コスパ朝食をまとめたわよ。

・マクドナルド 180円 ソーセージマフィン
・なか卯 300円 ごはん・みそ汁つきの定食
・松屋 350円 玉子かけごはん＋小鉢2つ
・コメダ ドリンク代だけでパンと玉子

値段は全部そのチェーンの公式で確かめたやつよ。'

T2='「モーニングって何時までだっけ」で毎回 検索するのが面倒だったから、
チェーンごとの いちばん安い朝食と提供時間を1本の表にまとめたわよ。

'"$URL"

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
  const w=s=>{let n=0;for(const c of String(s||"")) n+=c.codePointAt(0)<0x80?1:2;return n;};
  console.log(JSON.stringify({
    id:e.id, status:e.status, x_tweet_id:e.x_tweet_id||e.tweet_id||null,
    weight:w(e.text),
    images:String(e.image_path||"").split(",").filter(Boolean).length,
    chain:(e.thread_chain||[]).map((c,i)=>({
      n:i+1, role:c.role||null, weight:w(c.text),
      tweet_id:c.x_tweet_id||c.tweet_id||null,
      posted:!!(c.x_tweet_id||c.tweet_id||c.posted_at)
    })),
    error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
}

{
echo "# 文字数オーバーを直して出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **原因は文面だけだった。** \`[1/2]\` の X 重みが **293**（上限 280）で、"
echo "> 投稿ボタンが有効にならず \`post-via-playwright.js\` が中止していた。"
echo "> Chrome も CDP（18810）も画像も正常。"

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
echo "## 1. 本文を書き換える（**280 を超えていたら書かない**）"
echo
echo "「しかも牛丼チェーンは朝4:00から開いてる。」を削除した（2026-09-05 に利用者が指定）。"
echo "朝 4:00 の話は **4 枚目の画像**で伝わるので、本文から落としても情報は落ちない。"
echo
echo '```'
UPD="$("$NODE_BIN" -e '
const fs=require("fs");
const [qp,id,t1,t2]=process.argv.slice(1);
const w=s=>{let n=0;for(const c of String(s||"")) n+=c.codePointAt(0)<0x80?1:2;return n;};
const w1=w(t1), w2=w(t2);
console.log("  [1/2] の重み: "+w1+" / 280");
console.log("  [2/2] の重み: "+w2+" / 280");
if(w1>280||w2>280){ console.log("  **280 を超えている。書き換えない。**"); process.exit(2); }
const q=JSON.parse(fs.readFileSync(qp,"utf8"));
const rows=q.queue||[];
const e=rows.find(x=>x&&x.id===id);
if(!e){ console.log("  **該当エントリが無い。**"); process.exit(3); }
const before=w(e.text);
e.text=t1;
if(Array.isArray(e.thread_chain)&&e.thread_chain.length>=2){
  e.thread_chain[0].text=t1;
  e.thread_chain[1].text=t2;
} else { console.log("  **thread_chain が 2 本ない。**"); process.exit(4); }
fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2));
fs.renameSync(qp+".tmp", qp);
console.log("  書き換えた: "+before+" → "+w1);
' "$QJSON" "$ID" "$T1" "$T2" 2>&1)"
RC=$?
printf '%s\n' "$UPD" | clean
echo '```'
if [ "$RC" != "0" ]; then
  echo
  echo "- **書き換えに失敗した（rc=$RC）。出さない。**"
  exit 1
fi

echo
echo "## 2. 画像を取り直す"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
echo '```'
for f in 1-summary.jpg 2-matsuya.jpg 3-komeda.jpg 4-sukiya.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f.new" 2>/dev/null \
     && [ "$(wc -c < "$IMGDIR/$f.new" | tr -d ' ')" -ge 20000 ]; then
    mv "$IMGDIR/$f.new" "$IMGDIR/$f"
    printf '  %-16s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
  else
    printf '  **取れない** %s\n' "$f"; rm -f "$IMGDIR/$f.new"
  fi
done
echo '```'

echo
echo "## 3. 出す"
echo
if [ ! -x "$RUNPUB" ]; then echo "- **\`run-publish.sh\` が実行できない。**"; exit 1; fi
echo '```'
"$RUNPUB" "$ID" 2>&1 | tail -120 | clean
echo "(rc=$?)"
echo '```'

echo
echo "## 4. [1/2] と [2/2] は両方 出たか"
echo
AFTER="$(posted_count)"
echo "- 投稿済みエントリ: **${AFTER} 件**（開始前 ${BEFORE} 件）"
echo
echo '```json'
entry_dump | clean
echo '```'
echo
echo "**2 本とも \`posted: true\` でなければ、出ていないか片肺。**"

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
  echo "**まだ出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
