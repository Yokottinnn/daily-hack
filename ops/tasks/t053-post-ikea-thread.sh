#!/bin/bash
# **IKEA豊洲の告知スレッド（[1/2] + [2/2]）を X へ出す。**
#
# 本文と画像 4 枚は **2026-09-06 にこのチャットで実物を見たうえで承認済み**
# （最上位ルール 4「画像確認なしの投稿は絶対に許可されない」を満たしている）。
#
# ## モーニングで踏んだ穴を全部 塞いである
#
#   1. **重みを先に数える。** `[1/2]` が 293 で上限 280 を超えていて、
#      投稿ボタンが有効にならず 40 分 失った。**280 を超えていたら積まない**
#   2. **画像は `origin/main` から `git show` で取り出す。**
#      ポーラーは作業ツリーを main に切り替えないので、ディスク上の絵は古いことがある
#   3. **CDP の口は 18810。** `9222` ではない（`ensure-chrome.sh:PORT`）。
#      ただし**ポートが開いているだけでは健全ではない**ので `cdp-health.js` で見る
#   4. **マスクは秘密だけに絞る。** 無差別なマスクと `cut` はエラー本文ごと潰す
#   5. **出したあとキューに書き戻す。** `run-publish.sh` は書き戻さないので、
#      放っておくと次のタスクが「まだ出ていない」と誤認して二重投稿する
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
#   * `kind` は **`"thread"`**（`blog-promo` は kind ではなくモードの名前）
#   * `id` は **`blog-promo-` 始まり**
#   * 画像は **`image_path` にカンマ区切り**（`images` ではない）
#   * スレッドは **`thread_chain[]` を `run-publish.sh <id>` で出す**
#   * `queue-manager.js approve` は**存在しない**ので呼ばない
#
# ## 二重投稿をしない
#
# 開始前に「投稿済み」を数え、1 件でもあれば何もしない。ロックを置く。
# **2 本とも出たかを `tweet_id` で確かめ、片肺ならそう報告する。**
#
# **LLM を呼ばない（費用 $0）。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-ikea-thread.md"
LOCK="$W/data/.t053-ikea-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-ikea-toyosu"
SRCDIR="public/images/ikea-toyosu-2026/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20260906-ikea-toyosu-2026"
URL="https://daily-hack.fieldbeside.com/posts/ikea-toyosu-2026/"

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

T1='先に言っとくわね。
IKEA豊洲のオープン記念キャンペーン、9/13で終わるわよ。

限定セールもバッグ（5,000円以上）も、そこまで。
10%オフクーポンだけは配布9月・利用10月。ここ間違えないで。

サメ（BLÅHAJ）は1,499円まで下がってた。
駅直結で21時まで。サメ抱えて有楽町線に乗んなさい。'

T2='「豊洲のIKEAって何が置いてあるの」で調べても、出てくるのはオープンのお知らせばっかり。
だからアタシが6ゾーンぶん全部 見たわよ。リビング・キッチン・収納・食品・キッズ・相談カウンター。

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
    return t.includes("ikea-toyosu-2026")
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
  const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);
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
    })), error:e.error||null
  },null,1));
}catch(err){ console.log("読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
}

{
echo "# IKEA豊洲の告知スレッドを X へ出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> 本文と画像 4 枚は **2026-09-06 にチャットで実物を見たうえで承認済み**。"
echo "> モーニングで踏んだ 5 つの穴（重み／画像の取り直し／CDP の口／マスク／書き戻し）は"
echo "> **全部 塞いである。**"

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
mkdir -p "$(dirname "$LOCK")"; date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"
echo "- ロックを置いた"

echo
echo "## 1. X の重みを先に数える（**280 を超えていたら積まない**）"
echo
echo "モーニングは 293 で落ちた。**和文は 1 文字が 2。**"
echo
echo '```'
WOK="$("$NODE_BIN" -e '
const w=s=>{let n=0;for(const c of s)n+=c.codePointAt(0)<0x80?1:2;return n};
const [t1,t2]=process.argv.slice(1);
const a=w(t1), b=w(t2);
console.log("  [1/2] "+a+" / 280");
console.log("  [2/2] "+b+" / 280");
if(a>280||b>280){ console.log("  **上限を超えている。積まない。**"); process.exit(2); }
' "$T1" "$T2" 2>&1)"; RC=$?
printf '%s\n' "$WOK" | clean
echo '```'
[ "$RC" != "0" ] && { echo; echo "- **重みが上限を超えている。出さない。**"; rm -f "$LOCK"; exit 1; }

echo
echo "## 2. 画像 4 枚を \`origin/main\` から取り出す"
echo
echo "**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""; MISSING=0
echo '```'
for f in 1-summary.jpg 2-access.jpg 3-campaign.jpg 4-blahaj.jpg; do
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$IMGDIR/$f.new" 2>/dev/null \
     && [ "$(wc -c < "$IMGDIR/$f.new" | tr -d ' ')" -ge 20000 ]; then
    mv "$IMGDIR/$f.new" "$IMGDIR/$f"
    printf '  取得  %-16s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"
  else
    printf '  **取れない** %s（origin/main に無い）\n' "$f"; MISSING=1
    rm -f "$IMGDIR/$f.new"
  fi
done
echo '```'
if [ "$MISSING" = "1" ]; then
  echo; echo "- **画像が揃っていない。積まないし、出さない。**"; rm -f "$LOCK"; exit 1
fi
echo
echo "- 順番: **まとめ → 立地 → キャンペーン → サメ**（2026-09-06 に指定）"

echo
echo "## 3. キューに積む（契約どおりの形）"
echo
if [ ! -f "$Q" ]; then echo "- **\`queue-manager.js\` が無い。**"; rm -f "$LOCK"; exit 1; fi
echo '```json'
"$NODE_BIN" -e '
const [id,t1,t2,csv,url]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1,
  image_path: csv, target_url: url,
  auto_publish: true,
  scheduled_at: new Date(Date.now()-60000).toISOString(),
  thread_chain: [
    { text:t1, role:"hook", image_path:csv },
    { text:t2, role:"cta",  url:url }
  ]
}));
' "$ID" "$T1" "$T2" "$IMGS" "$URL" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
echo '```'
echo
echo "- \`id\`: \`$ID\`（\`blog-promo-\` 始まり）／\`kind\`: \`thread\`／\`thread_chain\`: 2 本"

echo
echo "## 4. Chrome は健全か（**口は 18810**）"
echo
echo "**ポートが開いているだけでは健全ではない。** ハングした Chrome も"
echo "\`/json/version\` に 200 を返す（\`ensure-chrome.sh\` の但し書き・CDP timeout 18,087 件）。"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 5. 出す（**\`cut\` で切らない**）"
echo
if [ ! -x "$RUNPUB" ]; then echo "- **\`run-publish.sh\` が実行できない。**"; exit 1; fi
PUB="$("$RUNPUB" "$ID" 2>&1)"; PRC=$?
echo '```'
printf '%s\n' "$PUB" | tail -60 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 6. 出たか。**出たならキューに書き戻す**"
echo
echo "\`run-publish.sh\` は成功しても書き戻さない。**放っておくと次のタスクが二重投稿する。**"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" -e '
const fs=require("fs");
let raw=""; process.stdin.on("data",d=>raw+=d).on("end",()=>{
  const [qp,id]=process.argv.slice(1);
  // 最後の JSON 行を拾う
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

echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0）。** **X 上の手動投稿はキューからは見えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then
  echo "**IKEA豊洲の告知を出した。chain の 2 本を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
