#!/bin/bash
# **フォロワー 300 人のお礼を 1 本 投稿する（AI 動画の GIF つき）。費用 $0。**
#
# ## 承認の状態
#
# **文面・動画とも実物を見たうえで承認済み**（2026-10-03「いいね。動画と投稿コメントはこれでいいので投稿して。」）。
# 動画はレビューページ Version 43 とチャットの両方で見てもらっている。
# 文面のハッシュは `scripts/image-review/posts.lock.json` の follower-300[0] と一致する。
#
# ## 形
#
#   * **1 投稿だけ**（記事の告知ではないのでスレッドにしない）
#   * 添付は **GIF 1 枚**（public/images/follower-300/x/1-card-ai.gif・約 6MB。X の GIF 上限は 15MB）
#   * GIF を付けるのは初めてなので、**`post-via-playwright.js` の添付まわりを先に書き出してから**出す。
#     落ちたら出力の全文を残す（契約書 §4）
#
# ## 契約どおりに積む（`docs/x-publisher-contract.md`）
#
#   * `kind` は **`"thread"`** ／ `id` は **`blog-promo-` 始まり**
#   * 画像は **`image_path`**（`images` ではない）／ `thread_chain` は 1 本だけ
#   * `run-publish.sh <id>` で出す
#
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/post-follower-300.md"
LOCK="$W/data/.x214-follower-300.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
IMGDIR="$W/data/x-follower-300"
SRCDIR="public/images/follower-300/x"
Q="$W/scripts/queue-manager.js"
RUNPUB="$W/scripts/run-publish.sh"
HEALTH="$W/scripts/cdp-health.js"
PVP="$W/scripts/post-via-playwright.js"
QJSON="$W/data/post_queue.json"
ID="blog-promo-20261003-follower-300"

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
T1='【フォロワー300人突破】🎉

ふん、別にあんたたちのためにやってきたわけじゃないけど。

5/15は19人。10/3で304人。
損したくない人、こんなにいたのね😏

いいね・リポスト・リプ、全部見てるわよ。
…ありがと。一回しか言わないから。

次は500人。
あんたの損、毎日指摘してあげるわ💸'

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
echo "# フォロワー 300 人のお礼を投稿する（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **GIF 1 枚つきの 1 投稿。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。"

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
echo "## 1. 添付まわり（GIF は初めてなので先に見る）"
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
const a=w(process.argv[1]);
console.log("  [1/1] "+a+" / 280（余裕 "+(280-a)+"）");
if(a>280){ console.log("  **上限を超えている。積まない。**"); process.exit(2); }
' "$T1" 2>&1)"; RC=$?
printf '%s\n' "$WOK" | clean
echo '```'
[ "$RC" != "0" ] && { echo; echo "- **重みが上限を超えている。出さない。**"; rm -f "$LOCK"; exit 1; }

echo
echo "## 3. GIF を \`origin/main\` から取り出す"
echo
mkdir -p "$IMGDIR"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
IMGS=""; MISSING=0
echo '```'
for f in 1-card-ai.gif; do
  TMP="$IMGDIR/.dl-$f"
  if git -C "$REPO" show "origin/main:$SRCDIR/$f" > "$TMP" 2>/dev/null \
     && [ "$(wc -c < "$TMP" | tr -d ' ')" -ge 1000000 ]; then
    mv "$TMP" "$IMGDIR/$f"
    SZ="$(wc -c < "$IMGDIR/$f" | tr -d ' ')"
    printf '  取得  %-16s %s bytes（先頭 %s）\n' "$f" "$SZ" "$(head -c 6 "$IMGDIR/$f")"
    [ "$SZ" -gt 15000000 ] && { echo "  **15MB を超えている**"; MISSING=1; }
    IMGS="$IMGDIR/$f"
  else
    printf '  **取れない** %s\n' "$f"; MISSING=1; rm -f "$TMP"
  fi
done
echo '```'
if [ "$MISSING" = "1" ]; then echo; echo "- **GIF が無い・大きすぎる。出さない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 4. キューに積む"
echo
if [ ! -f "$Q" ]; then echo "- **\`queue-manager.js\` が無い。**"; rm -f "$LOCK"; exit 1; fi
echo '```json'
"$NODE_BIN" -e '
const [id,t1,csv]=process.argv.slice(1);
console.log(JSON.stringify({
  id, kind:"thread", text:t1, image_path: csv,
  auto_publish: true,
  scheduled_at: new Date(Date.now()-60000).toISOString(),
  thread_chain: [ { text:t1, role:"hook", image_path:csv } ]
}));
' "$ID" "$T1" "$IMGS" | "$NODE_BIN" "$Q" enqueue 2>&1 | head -10 | clean
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
  console.log("  tweet_id = "+(t1||"取れていない"));
  if(!t1){ console.log("  ID が無い。書き戻さない。"); return; }
  let q; try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }catch(e){ console.log("  キューが読めない"); return; }
  const e=(q.queue||[]).find(x=>x&&x.id===id);
  if(!e){ console.log("  エントリが無い"); return; }
  e.status="posted"; e.x_tweet_id=t1; e.posted_at=new Date().toISOString();
  if(Array.isArray(e.thread_chain)&&e.thread_chain[0]) e.thread_chain[0].x_tweet_id=t1;
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
echo "**一次情報は \`x_tweet_id\` と投稿 URL の実物だけ**（最上位ルール 11）。GIF が付いているかは X 上の実物で確かめる。"
echo
echo "---"
echo
echo "**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q 'キューを posted に書き戻した' "$OUT" 2>/dev/null; then
  echo "**300 フォロワーのお礼を出した。X 上の実物で GIF を確認すること** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"
fi
