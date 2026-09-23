#!/bin/bash
# **「500円モーニング 2026」の告知スレッドを出す（2 回目の挑戦）。費用 $0。**
#
# ## 承認の状態
#
# **文面・画像とも実物を見たうえで承認済み**（2026-09-23「これで投稿する」）。
# 画像はレビューページ Version 20 とチャットの両方で確認をもらっている。
#
# ## 1 回目（`x134`）は**わざと止まった**
#
# `x134` は積む前に `exit 1` した。**正しい停止だった。**
#
#   run-publish.sh:122  node scripts/post-comment.js "${textB64}" "${prevUrl}"
#                       ↑ imagePath を渡していない
#   post-comment.js:20  const [textArg, targetUrl] = process.argv.slice(2);
#                       ↑ 受け口が 2 つ。setInputFiles も 0 箇所
#
# **投稿は 1 本も出ていない。** 削除・出し直しにはなっていない。
#
# ## `x136` が塞いだので、今度は出せる
#
# **ただし当たっていることを自分で確かめてから積む。**「マージしたから当たったはず」で
# 進めない（`rc=0` は証拠にならない・最上位ルール 13）。
#
# ## 画像は **[2/2] に 1 枚**
#
# 利用者がダイアログで選んだ形（`[1/2]` の「この全部に勝ったのが ↓↓」を残すため）。
#
# ## `id` は `x134` と変える
#
# **使い回すとキューの履歴が上書きされ、いつ何が起きたか辿れなくなる**
# （2026-09-21 の出し直しと同じ作法）。
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
#   * `kind` は **`"thread"`** ／ `id` は **`blog-promo-` 始まり**
#   * 画像は **`image_path` にカンマ区切り**（`images` ではない）
#   * スレッドは **`thread_chain[]` を `run-publish.sh <id>` で出す**
#   * **同日ガードは `run-publish.sh` なら通らない**（契約書 §4）
#
# **LLM を呼ばない（費用 $0）。ハンドルと秘密は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-morning-500-v2.md"
LOCK="$W/data/.x137-morning-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-morning-500"
SRCDIR="public/images/morning-500-2026/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
CMT="$W/scripts/post-comment.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20260923-morning-500-2026-v2"
URL="https://daily-hack.fieldbeside.com/posts/morning-500-2026/"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
# **秘密だけを潰す。** 無差別に消すとエラー本文ごと消える（2026-09-05 に実際にやった）
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# **承認済みの文面をそのまま置く。1 文字も変えない**（最上位ルール 18）。
# ハッシュは `scripts/image-review/posts.lock.json` の morning[0] / morning[1] と一致する
T1='朝マックのマフィン180円が最安、って思ってない？

それマフィン1個だけよ。飲み物もハッシュポテトも別。セットにすると450円〜。

同じ「ごはん・みそ汁つきの一食」で揃えると、順位はこう。

・松屋 350円
・吉野家 430円
・マクドナルド セット450円〜

この全部に勝ったのが ↓↓'

T2='なか卯の目玉焼き朝食、300円。

ごはん・みそ汁・目玉焼きつきで一食が完結するの。小盛300円、並盛でも320円よ。松屋より30円安い。

朝4:00から11:00まで。モバイルオーダーなら早朝の割増もかからない。

値段もつくものも、全部 公式ページで確かめたやつ。

'"$URL"

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=q.queue||q||[];
  console.log(rows.filter(e=>{
    if(!e||typeof e!=="object") return false;
    return (e.id||"")===process.argv[2]
        && (e.status==="posted"||e.x_tweet_id||e.tweet_id);
  }).length);
}catch(e){ console.log(-1); }
' "$QJSON" "$ID" 2>/dev/null || echo -1
}

entry_dump() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);
  if(!e){ console.log("（該当エントリが無い）"); process.exit(0); }
  const w=s=>{let n=0;for(const c of String(s||"")) n+=c.codePointAt(0)<0x80?1:2;return n;};
  console.log(JSON.stringify({
    id:e.id, status:e.status, x_tweet_id:e.x_tweet_id||e.tweet_id||null,
    weight:w(e.text),
    top_images:String(e.image_path||"").split(",").filter(Boolean).length,
    chain:(e.thread_chain||[]).map((c,i)=>({
      n:i+1, role:c.role||null, weight:w(c.text),
      images:String(c.image_path||"").split(",").filter(Boolean).length,
      tweet_id:c.x_tweet_id||c.tweet_id||null,
      posted:!!(c.x_tweet_id||c.tweet_id||c.posted_at)
    })), error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
}

{
echo "# 500円モーニングの告知を出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **画像は [2/2] に 1 枚。** これまでと形が違う（利用者が選んだ）。"
echo "> **文面は承認済みのものを 1 文字も変えていない**（最上位ルール 18）。"

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
if [ -f "$LOCK" ]; then
  echo; echo "- **ロックがある（$(cat "$LOCK" 2>/dev/null)）。二重に走らせない。**"; exit 0
fi

echo
echo "## 1. \`x136\` のパッチが当たっているか（**当たっていなければ積まない**）"
echo
echo "**「マージしたから当たったはず」で進めない**（\`rc=0\` は証拠にならない・最上位ルール 13）。"
echo "**実物のファイルを見て、4 つ揃っているかを確かめる。**"
echo
echo '```'
SUP=0
A=0; B=0; C=0; D=0
if [ -f "$CMT" ] && [ -f "$RUNPUB" ]; then
  # (1) 受け口が 3 つになっているか
  grep -q 'targetUrl, imageArg\] = process.argv' "$CMT" 2>/dev/null && A=1
  # (2) 添付の処理が入っているか
  grep -q 'setInputFiles' "$CMT" 2>/dev/null && B=1
  # (3) **付いたか確かめてから送る**ようになっているか（ここが肝）
  grep -q 'attachment did not appear' "$CMT" 2>/dev/null && C=1
  # (4) reply の呼び出しに画像が乗っているか
  grep 'post-comment.js' "$RUNPUB" 2>/dev/null | grep -q 'imagePath' && D=1
  printf '  (1) 引数が 3 つ            : %s\n' "$([ $A = 1 ] && echo OK || echo '**無い**')"
  printf '  (2) setInputFiles         : %s\n' "$([ $B = 1 ] && echo OK || echo '**無い**')"
  printf '  (3) 添付の確認つき        : %s\n' "$([ $C = 1 ] && echo OK || echo '**無い**')"
  printf '  (4) reply に画像を渡す    : %s\n' "$([ $D = 1 ] && echo OK || echo '**無い**')"
  echo
  echo "  --- run-publish.sh の reply 行 ---"
  grep -n 'post-comment.js' "$RUNPUB" 2>/dev/null | head -4 | clean
  [ $A = 1 ] && [ $B = 1 ] && [ $C = 1 ] && [ $D = 1 ] && SUP=1
else
  echo "  **ファイルが無い**"
fi
echo '```'
echo
if [ "$SUP" != "1" ]; then
  echo "- **パッチが当たっていない。積まないし、出さない。**"
  echo "- \`x136\` のレポート（\`patch-reply-image.md\`）を見て、当たらなかった理由を確かめること"
  exit 1
fi
echo "- **4 つとも揃っている。** 画像が付かなければ \`post-comment.js\` 側が \`ok:false\` で止める"

mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"
echo "- ロックを置いた"

echo
echo "## 2. X の重みを先に数える（**280 を超えていたら積まない**）"
echo
echo "**和文は 1 文字が 2。** URL は t.co で常に 23。"
echo
echo '```'
WOK="$("$NODE_BIN" -e '
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
const [t1,t2]=process.argv.slice(1);
const a=w(t1), b=w(t2);
console.log("  [1/2] "+a+" / 280（余裕 "+(280-a)+"）");
console.log("  [2/2] "+b+" / 280（余裕 "+(280-b)+"）");
if(a>280||b>280){ console.log("  **上限を超えている。積まない。**"); process.exit(2); }
' "$T1" "$T2" 2>&1)"; RC=$?
printf '%s\n' "$WOK" | clean
echo '```'
[ "$RC" != "0" ] && { echo; echo "- **重みが上限を超えている。出さない。**"; rm -f "$LOCK"; exit 1; }

echo
echo "## 3. 画像 1 枚を \`origin/main\` から取り出す"
echo
echo "**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。"
echo "**絵を直しても取り直さないと古い絵が出る。**"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""; MISSING=0
echo '```'
# **拡張子は保つ。** `.new` を付けると macOS の node が弾く場面がある（最上位ルール 14）
for f in cover-a.jpg; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null \
     && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 20000 ]; then
    mv "$TMP" "$IMGDIR/$f"
    printf '  取得  %-14s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"
  else
    printf '  **取れない** %s（origin/main に無い）\n' "$f"; MISSING=1
    rm -f "$TMP"
  fi
done
echo '```'
if [ "$MISSING" = "1" ]; then
  echo; echo "- **画像が無い。積まないし、出さない。**"; rm -f "$LOCK"; exit 1
fi
echo
echo "- **出所の行は焼き込んでいない**（最上位ルール 8）。ロゴは商標・識別目的"

echo
echo "## 4. キューに積む（**画像は chain[1] にだけ**）"
echo
if [ ! -f "$Q" ]; then echo "- **\`queue-manager.js\` が無い。**"; rm -f "$LOCK"; exit 1; fi
echo '```json'
"$NODE_BIN" -e '
const [id,t1,t2,csv,url]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1,
  // **最上位の image_path は空。** 1 本目は文字だけ（「↓↓」の仕掛けを残す）
  image_path: "", target_url: url,
  auto_publish: true,
  scheduled_at: new Date(Date.now()-60000).toISOString(),
  thread_chain: [
    { text:t1, role:"hook" },
    { text:t2, role:"cta", url:url, image_path:csv }
  ]
}));
' "$ID" "$T1" "$T2" "$IMGS" "$URL" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
echo '```'
echo
echo "- \`id\`: \`$ID\`／\`kind\`: \`thread\`／\`thread_chain\`: 2 本"
echo "- **画像は \`chain[1]\` にだけ 1 枚**（\`chain[0]\` は文字だけ）"

echo
echo "## 5. Chrome は健全か（**口は 18810**）"
echo
echo "**ポートが開いているだけでは健全ではない。** ハングした Chrome も"
echo "\`/json/version\` に 200 を返す。**ログアウト中に走らせると [1/2] だけ出て片肺になる。**"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 6. 出す（**\`cut\` で切らない**）"
echo
if [ ! -x "$RUNPUB" ]; then echo "- **\`run-publish.sh\` が実行できない。**"; exit 1; fi
PUB="$("$RUNPUB" "$ID" 2>&1)"; PRC=$?
echo '```'
printf '%s\n' "$PUB" | tail -60 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 7. 出たか。**出たならキューに書き戻す**"
echo
echo "\`run-publish.sh\` は成功しても書き戻さない。**放っておくと次が二重投稿する。**"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" -e '
const fs=require("fs");
let raw=""; process.stdin.on("data",d=>raw+=d).on("end",()=>{
  const [qp,id]=process.argv.slice(1);
  const line=raw.split(/\r?\n/).filter(l=>l.trim().startsWith("{")).pop();
  if(!line){ console.log("  出力に JSON が無い。書き戻さない。"); return; }
  let r; try{ r=JSON.parse(line); }catch(e){ console.log("  JSON が読めない: "+e.message); return; }
  if(!r.ok){ console.log("  ok:false。出ていないので書き戻さない。 step="+(r.step||"-")); return; }
  const t1=r.tweet_id||null;
  const rs=r.thread_results||[];
  const t2=(rs[1]&&(rs[1].reply_tweet_id||rs[1].tweet_id))||null;
  console.log("  [1/2] tweet_id = "+(t1||"取れていない"));
  console.log("  [2/2] tweet_id = "+(t2||"**取れていない＝片肺の疑い**"));
  if(!t1){ console.log("  1 本目の ID が無い。書き戻さない。"); return; }
  let q; try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }catch(e){ console.log("  キューが読めない"); return; }
  const e=(q.queue||[]).find(x=>x&&x.id===id);
  if(!e){ console.log("  エントリが無い"); return; }
  e.status="posted"; e.x_tweet_id=t1; e.posted_at=new Date().toISOString();
  if(Array.isArray(e.thread_chain)){
    if(e.thread_chain[0]) e.thread_chain[0].x_tweet_id=t1;
    if(e.thread_chain[1]&&t2) e.thread_chain[1].x_tweet_id=t2;
  }
  fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2));
  fs.renameSync(qp+".tmp", qp);
  console.log("  キューを posted に書き戻した");
});
' "$QJSON" "$ID" 2>&1 | clean
echo '```'

echo
echo "### 最終状態"
echo
AFTER="$(posted_count)"
echo "- 投稿済みエントリ: **${AFTER} 件**（開始前 ${BEFORE} 件）"
echo
echo '```json'
entry_dump | clean
echo '```'
echo
echo "**2 本とも \`posted: true\` でなければ、出ていないか片肺。黙って「出ました」と言わない。**"
echo "**一次情報は \`x_tweet_id\` と投稿 URL の実物だけ**（最上位ルール 11）。"
echo
echo "**[2/2] に画像が付いているかは、キューの数字では分からない。**"
echo "X 上の実物を見て確かめること。"

echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
echo "**X 上の手動投稿はキューからは見えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then
  echo "**500円モーニングの告知を出した。chain の 2 本と [2/2] の画像を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
elif grep -q 'reply への添付が確認できない' "$OUT" 2>/dev/null; then
  echo "**reply に画像が付く実装を確認できず、積まずに止めた** / $(basename "$OUT")"
else
  echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
