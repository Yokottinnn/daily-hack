#!/bin/bash
# **text-safety の上限 280 を青バッジの 25,000 に直し、承認済みの感謝祭の告知をいま出す（x322）。費用 $0。**
POST_APPROVAL_QUOTE="内容はこれで大丈夫。本日18日の午前中か昼ごろの読まれやすい時間で投稿して"
POST_APPROVAL_AT="2026-10-18 00:1x JST（ダイアログへの回答）"
#
# ## 何が起きたか（x319〜x321）
#
#   12:00 の 1 回だけのジョブは起動したが、post-via-playwright.js が lib/text-safety.js の
#   validatePostText（maxWeighted の既定 280）で [1/2]（重み 2,375）を弾いた（too_long_weighted）。
#   青バッジ（2026-10-12）で X 側の上限は 25,000 になったのに、投稿の経路の検査だけ 280 のままだった。
#
# ## やること
#
#   ① text-safety.js を退避し、`opts.maxWeighted ?? 280` を `?? (Number(process.env.X_MAX_WEIGHTED) || 25000)` に直す
#      **1 か所だけ一致したときだけ**書き換える。一致しなければ投稿せずに止まる
#   ② 直したあと、キューの [1/2] [2/2] が decodeBase64Safe を通ることを確かめる。通らなければ止まる
#   ③ まだ出ていないこと（キューの x_tweet_id が空）を確かめてから、run-publish.sh で出す
#   ④ 結果をキューへ書き戻す（x314 で置いた .publish-prime-writeback.js）
#   **文面・画像は x314 で積んだまま。1 文字も変えない**（ロックのハッシュで照合済み）。画面は撮らない。
# **LLM を呼ばない（$0／回・$0／日・$0／月）。ハンドルと秘密は伏せる。**
set -uo pipefail
W="$HOME/.openclaw/workspace"
S="$W/scripts"
ID="blog-promo-20261018-prime-vs-rakuten"
Q="$W/data/post_queue.json"
OUT="${OPS_REPORT_DIR:-/tmp}/fix-weight-and-post-prime.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LOCK="$W/data/.x322.lock"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# text-safety の上限を直して、感謝祭の告知を出す（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
if [ -f "$LOCK" ]; then echo "- **ロックがある（$(cat "$LOCK")）。二重に走らせない。**"; exit 0; fi
date -u +%Y-%m-%dT%H:%M:%SZ > "$LOCK"

echo "## 0. まだ出ていないか"
echo
POSTED="$("$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=(Array.isArray(q)?q:(q.queue||[])).find(x=>x&&x.id===process.argv[2]);console.log(r?((r.x_tweet_id||r.status==="posted")?"posted":"not"):"none")' "$Q" "$ID" 2>/dev/null)"
echo "- キューの状態: **$POSTED**"
if [ "$POSTED" != "not" ]; then echo "- **出ている、またはエントリが無い。何もしない。**"; exit 0; fi

echo
echo "## 1. text-safety.js の上限を直す"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");const f=process.argv[1];const s=fs.readFileSync(f,"utf8");
const old="const maxWeighted = opts.maxWeighted ?? 280;";
const n=s.split(old).length-1;
if(n!==1){console.log("  一致 "+n+" か所。書き換えない");process.exit(2);}
fs.writeFileSync(f+".bak-x322",s);
fs.writeFileSync(f,s.replace(old,"const maxWeighted = opts.maxWeighted ?? (Number(process.env.X_MAX_WEIGHTED) || 25000); // 2026-10-18 x322: 青バッジで上限 25,000"));
console.log("  書き換えた（退避: text-safety.js.bak-x322）");' "$S/lib/text-safety.js" 2>&1
RC=$?
grep -n 'const maxWeighted' "$S/lib/text-safety.js" | sed 's/^/  /'
echo '```'
if [ "$RC" != "0" ]; then echo "- **直せなかった。投稿しない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 2. 直したあと、キューの本文が検査を通るか"
echo
echo '```'
cd "$S" && "$NODE_BIN" -e '
const fs=require("fs");const {decodeBase64Safe,weightedLength}=require("./lib/text-safety");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const e=(Array.isArray(q)?q:(q.queue||[])).find(x=>x&&x.id===process.argv[2]);
let ok=true;(e.thread_chain||[]).forEach((c,i)=>{const r=decodeBase64Safe(Buffer.from(c.text,"utf8").toString("base64"));if(!r.ok)ok=false;
 console.log("  ["+(i+1)+"/2] 重み "+weightedLength(c.text)+" / ok="+r.ok+" "+(r.ok?"":JSON.stringify(r).slice(0,200)));});
process.exit(ok?0:3);' "$Q" "$ID" 2>&1
RC=$?
echo '```'
if [ "$RC" != "0" ]; then echo "- **まだ通らない。投稿しない。**"; rm -f "$LOCK"; exit 1; fi

echo
echo "## 3. 出す"
echo
PUB="$(cd "$W" && /bin/bash "$S/run-publish.sh" "$ID" 2>&1)"; PRC=$?
printf '%s\n' "$PUB" >> "$W/logs/publish-prime-oneshot.log"
echo '```'
printf '%s\n' "$PUB" | tail -25 | cut -c1-600 | clean
echo "(rc=$PRC)"
echo '```'

echo
echo "## 4. キューへ書き戻す"
echo
echo '```'
printf '%s' "$PUB" | "$NODE_BIN" "$S/.publish-prime-writeback.js" "$Q" "$ID" 2>&1 | clean
"$NODE_BIN" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const e=(Array.isArray(q)?q:(q.queue||[])).find(x=>x&&x.id===process.argv[2]);
console.log("  status="+e.status+" x_tweet_id="+(e.x_tweet_id||"無い"));(e.thread_chain||[]).forEach((c,i)=>console.log("  ["+(i+1)+"/2] x_tweet_id="+(c.x_tweet_id||"無い")));' "$Q" "$ID" 2>&1
echo '```'
echo
echo "**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。実物の確認は次のタスクで読む。**LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q 'x_tweet_id=[0-9]' "$OUT"; then echo "**感謝祭の告知を出した** / $(basename "$OUT")"
else echo "**出せていない。全文をレポートに残した** / $(basename "$OUT")"; fi
