#!/bin/bash
# **JAL マイル2倍キャンペーンの 2 投稿スレッドを出す（[1/2] 画像 4 枚・[2/2] 記事 URL）。費用 $0。**
#
# ## 承認の状態
#
# **文面 2 本・画像 4 枚とも実物を見たうえで承認済み**（2026-10-04「内容OKなので投稿していいよ」）。
# 画像はチャット（SendUserFile）とレビューページ Version 45 の両方で見てもらっている。
# 文面のハッシュは `scripts/image-review/posts.lock.json` の jal-2x[0] / jal-2x[1] と一致する。
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
#   * `kind` は **`"thread"`** ／ `id` は **`blog-promo-` 始まり**
#   * 画像は **`image_path`**（カンマ区切り 4 枚・[1/2] だけ）
#   * スレッドは `thread_chain[]` を `run-publish.sh <id>` で 1 回で出す
#   * `parse-main-result` で落ちても**再送しない**（x244 の確認タスクで出たかを見る）
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-jal-2x.md"
LOCK="$W/data/.x243-jal-2x.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-jal-2x-2026-10"
SRCDIR="public/images/jal-2x-2026-10/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
PVP="$W/scripts/post-via-playwright.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261004-jal-2x"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E \
    -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
    -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
    -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
    -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

# **承認済みの文面をそのまま置く。1 文字も変えない**（最上位ルール 18）
T1='先に言っとくわね。
JAL Wellness & Travelの「マイル2倍キャンペーン」が来るわよ。

対象は10/12〜10/17に受け取る抽選券。達成の翌日〜翌々日に受け取れるから、歩くのは10/10〜10/16。10/10の分は10/12まで待ちなさい。

アタシは大体ひと月200マイル稼いでるわ。2倍の週は逃さないわよ。'

T2='正直、歩いてポイ活ってアツいのよ。
毎日歩く分が、そのままマイルやポイントになるんだから。

JALは月550円でマイル。無料のアプリでも毎日8,000歩で年365円。
どれを組み合わせるかは、アタシが20アプリ分析してまとめといたわ。

https://daily-hack.fieldbeside.com/posts/walk-poikatsu-2026/'

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
echo "# JAL マイル2倍キャンペーンのスレッドを投稿する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **[1/2] 画像 4 枚・[2/2] 記事 URL の 2 投稿。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。"

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

echo
echo "## 1. 添付まわり（確認用）"
echo
echo '```'
if [ -f "$PVP" ]; then
  grep -n -E 'input\[type="file"\]|setInputFiles|attachment did not appear|attachments|removeMedia|post button|tweetButton|waitFor.*(enabled|timeout)' "$PVP" | head -20 | cut -c1-200 | clean
else
  echo "  **post-via-playwright.js が無い**"
fi
echo '```'

echo
echo "## 2. X の重み（**280 を超えていたら積まない**）"
echo
echo '```'
WOK="$("$NODE_BIN" -e '
const w=s=>{let n=0;for(const c of s.replace(/https?:\/\/\S+/g,"#".repeat(23)))n+=c.codePointAt(0)<0x80?1:2;return n};
let bad=0;
process.argv.slice(1).forEach((t,i)=>{const a=w(t);console.log("  ["+(i+1)+"/2] "+a+" / 280（余裕 "+(280-a)+"）");if(a>280)bad=1;});
if(bad){ console.log("  **上限を超えている。積まない。**"); process.exit(2); }
' "$T1" "$T2" 2>&1)"; RC=$?
printf '%s\n' "$WOK" | clean
echo '```'
[ "$RC" != "0" ] && { echo; echo "- **重みが上限を超えている。出さない。**"; rm -f "$LOCK"; exit 1; }

echo
echo "## 3. 画像 4 枚を \`origin/main\` から取り出す"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""; MISSING=0; N=0
echo '```'
for f in 1-notice.jpg 2-monthly.jpg 3-history.jpg 4-service.jpg; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null \
     && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 20000 ]; then
    mv "$TMP" "$IMGDIR/$f"
    printf '  取得  %-16s %s bytes\n' "$f" "$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    IMGS="${IMGS:+$IMGS,}$IMGDIR/$f"; N=$((N + 1))
  else
    printf '  **取れない** %s\n' "$f"; MISSING=1; rm -f "$TMP"
  fi
done
printf '  対象 4 枚 / 取れた %s 枚\n' "$N"
echo '```'
if [ "$MISSING" = "1" ] || [ "$N" != "4" ]; then echo; echo "- **画像が 4 枚 揃わない。出さない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 4. キューに積む"
echo
if [ ! -f "$Q" ]; then echo "- **\`queue-manager.js\` が無い。**"; rm -f "$LOCK"; exit 1; fi
echo '```json'
"$NODE_BIN" -e '
const [id,t1,t2,csv]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1, image_path: csv,
  auto_publish: true,
  scheduled_at: new Date(Date.now()-60000).toISOString(),
  thread_chain: [ { text:t1, role:"hook", image_path:csv },
                  { text:t2, role:"cta", url:"https://daily-hack.fieldbeside.com/posts/walk-poikatsu-2026/" } ]
}));
' "$ID" "$T1" "$T2" "$IMGS" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
echo '```'

echo
echo "## 5. Chrome は健全か（**口は 18810**）"
echo
echo '```'
if [ -f "$HEALTH" ]; then "$NODE_BIN" "$HEALTH" 2>&1 | clean; echo "(rc=$?)"; else echo "（cdp-health.js が無い）"; fi
echo '```'

echo
echo "## 6. 出す（**\`cut\` で切らない**）"
echo
if [ ! -x "$RUNPUB" ]; then echo "- **\`run-publish.sh\` が実行できない。**"; rm -f "$LOCK"; exit 1; fi
PUB="$("$RUNPUB" "$ID" 2>&1)"; PRC=$?
echo '```'
printf '%s\n' "$PUB" | tail -60 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 7. 出たか。**出たならキューに書き戻す**"
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
  console.log("  [2/2] tweet_id = "+(t2||"**取れていない＝片肺の疑い**")+"（ID が返っても出ているとは限らない。x244 で実物を見る）");
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
echo "**一次情報は \`x_tweet_id\` と投稿 URL の実物だけ**（最上位ルール 11）。画像 4 枚と [2/2] が付いているかは x244 で X 上の実物を見て確かめる。"
echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then
  echo "**JAL マイル2倍のスレッドを出した。x244 で実物を確認する** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
