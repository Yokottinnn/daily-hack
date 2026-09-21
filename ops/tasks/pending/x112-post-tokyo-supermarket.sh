#!/bin/bash
# **都心の格安スーパーの告知スレッド（[1/2] + [2/2]）を X へ出す。**
#
# 本文と画像 4 枚は **2026-09-21 にレビューページとチャットで実物を見たうえで承認済み**
# （「うん、投稿内容は大丈夫」。最上位ルール 4「画像確認なしの投稿は絶対に許可されない」を満たす）。
# **出す時刻も利用者が選んだ**（「21日中に投稿してほしい」→ 17:00〜18:00 JST）。
#
# **文面は利用者がレビューページで自分で書き換えたものをそのまま使う。**
# `scripts/image-review/posts.json` の `super[0]` / `super[1]` と 1 文字も違えない。
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
#   * `kind` は **`"thread"`**（`blog-promo` は kind ではなくモードの名前）
#   * `id` は **`blog-promo-` 始まり**
#   * 画像は **`image_path` にカンマ区切り**（`images` ではない）
#   * スレッドは **`thread_chain[]` を `run-publish.sh <id>` で出す**
#
# ## 同日ガードは踏まない
#
# **今日（9/21 00:26 JST）に歩いてポイ活を出している。**
# `auto-x-publisher.js` は「blog-promo already posted today」で弾くが、
# **`run-publish.sh <id>` は id を名指しするのでガードを通らない**（契約書 §4）。
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
OUT="${OPS_REPORT_DIR:-/tmp}/post-tokyo-supermarket.md"
LOCK="$W/data/.x112-super-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-tokyo-supermarket"
SRCDIR="public/images/tokyo-discount-supermarket-2026/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20260921-tokyo-discount-supermarket-2026"
URL="https://daily-hack.fieldbeside.com/posts/tokyo-discount-supermarket-2026/"
SLUG="tokyo-discount-supermarket-2026"

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

T1='1店舗あたりの年商、オーケーが43.4億円でまいばすけっとが2.4億円。18倍の開きよ。

・まいばすけっとは1,262店中879店が東京都
・肉のハナマサは65店中46店が東京都
・2025年7月、西友はトライアルの子会社に

同じ「安い」でも、稼ぎ方が正反対なのよ。'

T2='「都心の安いスーパーどこ？」で出てくるのは、だいたい誰かの感想かチラシ。なぜ安いのかは誰も言わないのよ。

だからアタシが7社の決算資料を開いて、徹底的に分析したわよ。

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
    return t.includes(process.argv[2])
        && (e.status==="posted"||e.x_tweet_id||e.tweet_id);
  }).length);
}catch(e){ console.log(-1); }
' "$QJSON" "$SLUG" 2>/dev/null || echo -1
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
echo "# 都心の格安スーパーの告知スレッドを X へ出す（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 本文と画像 4 枚は **2026-09-21 にレビューページとチャットで実物を見たうえで承認済み**。"
echo "> **出す時刻も利用者が選んだ**（「21日中に投稿してほしい」→ 17:00〜18:00 JST）。"
echo "> **文面は利用者がレビューページで書き換えたものを 1 文字も変えずに使う。**"

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
echo "## 2. 画像 4 枚を \`origin/main\` から取り出す"
echo
echo "**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。"
echo "**絵を直しても取り直さないと古い絵が出る。**"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""; MISSING=0
echo '```'
# **拡張子は保つ。** `.new` を付けると macOS の node が弾く場面がある（最上位ルール 14）
for f in 1-summary.jpg 2-maibasket.jpg 3-hanamasa.jpg 4-tv.jpg; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null \
     && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 20000 ]; then
    mv "$TMP" "$IMGDIR/$f"
    printf '  取得  %-18s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"
  else
    printf '  **取れない** %s（origin/main に無い）\n' "$f"; MISSING=1
    rm -f "$TMP"
  fi
done
echo '```'
if [ "$MISSING" = "1" ]; then
  echo; echo "- **画像が揃っていない。積まないし、出さない。**"; rm -f "$LOCK"; exit 1
fi
echo
echo "- 順番: **表紙（7社ロゴ）→ まいばすけっと → 肉のハナマサ → TV 3社**"
echo "- **出所の行は焼き込んでいない**（2026-09-20 の指示・最上位ルール 8）。"
echo "  写真は CC0 と各社ロゴだけで組んであるので、表記を消しても違反にならない"

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
echo "\`/json/version\` に 200 を返す。**ログアウト中に走らせると [1/2] だけ出て片肺になる。**"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 5. 出す（**\`cut\` で切らない**）"
echo
echo "**\`run-publish.sh <id>\` を使う。** 今日はもう歩いてポイ活を出しているので、"
echo "\`auto-x-publisher.js\` なら同日ガードで弾かれる（契約書 §4）。"
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
echo "---"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
echo "**X 上の手動投稿はキューからは見えない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then
  echo "**格安スーパーの告知を出した。chain の 2 本を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
