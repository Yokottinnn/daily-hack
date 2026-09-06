#!/bin/bash
# **返信が実際に X へ出るまで、実績のある経路を繰り返す。費用 最大 約 $0.036。**
#
# ## 指摘
#
#   > 返信の実投稿がされていないのはNGだよ。実行しろって言ったよね
#
# そのとおり。配線も起動も済ませたが **X には 1 件も出ていない。**
#
# ## なぜ 0 件だったか
#
# `comment-warmup` は 1 回に **2 件しか見ない**。9/6 21:23 の回は候補 2 件が
# 両方とも PR 投稿と商品告知で skip になった。**候補の当たり外れがそのまま結果になる。**
#
# ## 直し方（**新しい投稿経路を作らない**）
#
# 前の版は `post-comment.js` を直接 叩こうとしていた。**だが引数の形は私の推測**で、
# 外せば「エラーも出ずに 0 件」になる。**推測で叩かない。**
#
# **`comment-orchestrator.sh` をそのまま繰り返す。** これは 9/1・9/2 に
# 実際に投稿を成功させている経路で、enqueue も投稿も検証済み。
# 1 回で 2 件 見るので、**4 回 回せば 8 件の候補に当たる。**
#
# ## 止まる条件
#
#   * **投稿が 1 件でも出たら、そこで止める**
#   * 4 回 走らせても出なければ止める（**LLM 最大 8 回・約 $0.024**）
#   * 冒頭で今日すでに出ていれば**何もしない**
#
# **投稿されたら本文と `tweet_id` を出す。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/force-reply-until-posted.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
QJSON="$W/data/post_queue.json"
ORCH="$S/comment-orchestrator.sh"
MAX_RUNS=4

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

posted_count() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# 返信が実際に X へ出るまでやる（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 利用者の指摘: **「返信の実投稿がされていないのは NG。実行しろって言ったよね」**"
echo
echo "**新しい投稿経路を作らない。** 前の版は \`post-comment.js\` を直接 叩こうと"
echo "していたが、**引数の形は私の推測**だった。外せば「エラーも出ずに 0 件」になる。"
echo
echo "**\`comment-orchestrator.sh\` をそのまま繰り返す。** 9/1・9/2 に実際に投稿を"
echo "成功させている経路。1 回で 2 件 見るので、**${MAX_RUNS} 回で 8 件の候補に当たる。**"
echo
echo "**投稿が 1 件でも出たら、そこで止める。** 最大 LLM 8 回（約 \$0.024）。"

echo
echo "## 0. いま何件 出ているか"
echo
BEFORE="$(posted_count)"
echo "- 投稿済みの comment/reply（累計）: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo; echo "- **キューが読めない。何もしない。**"; exit 1; fi

TODAY_BEFORE="$("$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const t=new Date(Date.now()+9*3600*1000).toISOString().slice(0,10);
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)
    &&String(e.posted_at||e.created_at||"").slice(0,10)===t).length);
}catch(e){ console.log(0); }
' "$QJSON")"
echo "- そのうち**今日（JST）出たもの**: **${TODAY_BEFORE} 件**"
if [ "${TODAY_BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo; echo "- → **今日は既に出ている。何もしない。**"; exit 0
fi

echo
echo "## 1. 配線と Chrome"
echo
echo '```'
grep -nE 'asuka-reply|asuka-fill' "$ORCH" 2>/dev/null | clean
echo '```'
if ! grep -q 'asuka-reply.cjs' "$ORCH" 2>/dev/null; then
  echo; echo "- **全文生成に配線されていない。走らせない。**"; exit 1
fi
echo '```'
"$S/ensure-chrome.sh" >/dev/null 2>&1 && echo "  ensure-chrome: OK" || echo "  ensure-chrome: NG"
echo '```'

echo
echo "## 2. 出るまで繰り返す（最大 ${MAX_RUNS} 回）"
echo
for i in $(seq 1 $MAX_RUNS); do
  echo "### ${i} 回目"
  echo
  echo '```'
  ( cd "$W" && MAX_PICKS_PER_FIRE=2 bash "$ORCH" ) 2>&1 | tail -22 | clean
  echo "(rc=$?)"
  echo '```'
  NOW="$(posted_count)"
  echo
  echo "- 投稿済み累計: **${NOW} 件**（開始前 ${BEFORE} 件）"
  if [ "${NOW:-0}" -gt "${BEFORE:-0}" ] 2>/dev/null; then
    echo
    echo "- **出た。ここで止める。**"
    break
  fi
  echo "- まだ出ていない。次の候補へ"
  echo
done

echo
echo "## 3. 実際に出た返信"
echo
AFTER="$(posted_count)"
echo "- 投稿済み累計: **${AFTER} 件**（開始前 ${BEFORE} 件）／**今回 出た数: $(( AFTER - BEFORE )) 件**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
  const last=rows.slice(-3);
  if(!last.length){ console.log("  投稿済みのエントリが無い"); }
  last.forEach(e=>{
    console.log("  status="+(e.status||"?")+" / "+(e.posted_at||e.created_at||"日時なし"));
    console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
    console.log("  → https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
    console.log("");
  });
}catch(e){ console.log("  読めない: "+e.message); }
' "$QJSON" 2>&1 | clean
echo '```'

echo
echo "---"
echo
if [ "${AFTER:-0}" -gt "${BEFORE:-0}" ] 2>/dev/null; then
  echo "**返信が X へ出た。**"
else
  echo "**まだ出ていない。** 各回のログに skip の理由が出ている。"
  echo "候補の質の問題なら、**検知の取得元を見直す必要がある。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '返信が X へ出た' "$OUT" 2>/dev/null; then
  echo "**返信が実際に X へ出た** / $(basename "$OUT")"
elif grep -q '今日は既に出ている' "$OUT" 2>/dev/null; then
  echo "今日は既に出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**まだ出せていない。各回の skip 理由をレポートに出した** / $(basename "$OUT")"
fi
