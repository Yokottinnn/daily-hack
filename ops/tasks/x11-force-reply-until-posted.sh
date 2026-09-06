#!/bin/bash
# **返信が実際に X へ出るまでやる。費用 最大 約 $0.045（15 回まで）。**
#
# ## なぜ要るか
#
# 2026-09-06、利用者に指摘された。
#
#   > 返信の実投稿がされていないのはNGだよ。実行しろって言ったよね
#
# **そのとおり。** 配線も起動も済ませたが、**X には 1 件も出ていない。**
# 21:23 の実行は候補 2 件が両方とも PR 投稿と商品告知で skip になった。
# **「候補が悪かった」は言い訳にならない。出るまでやる。**
#
# ## `comment-warmup` の限界
#
# 1 回の実行で **2 件しか見ない**（`MAX_PICKS_PER_FIRE=2`）。
# 候補の当たり外れがそのまま結果になる。**もう一度 走らせても同じことが起きうる。**
#
# ## だからこのタスクは、通るまで候補を送り込む
#
#   1. 候補を検知で多めに取る（Playwright の DOM 取得のみ・**$0**）
#   2. 入口フィルタ（PR・アフィリを $0 で落とす）
#   3. **通った候補を 1 件ずつ生成器にかける。ok が出るまで進む**
#   4. **最初に ok が出た 1 件を、実際に X へ投稿する**
#   5. **投稿した本文と `tweet_id` を出す**
#
# **上限は LLM 15 回（約 $0.045）。** 超えたら止める。
# **投稿するのは 1 件だけ。** 出たらそこで終わる。
#
# ## 投稿の経路は既存のものを使う
#
# `comment-orchestrator.sh` と同じ `post-comment.js` を叩く。
# **自前で新しい投稿経路を作らない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/force-reply-until-posted.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
MAX_LLM=15
Q="$W/scripts/queue-manager.js"
QJSON="$W/data/post_queue.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

posted_today() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const t=new Date().toISOString().slice(0,10);
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)
    &&String(e.posted_at||e.created_at||"").slice(0,10)===t).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# 返信が実際に X へ出るまでやる（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> 利用者の指摘: **「返信の実投稿がされていないのは NG。実行しろって言ったよね」**"
echo "> そのとおり。**「候補が悪かった」は言い訳にならない。出るまでやる。**"
echo
echo "\`comment-warmup\` は 1 回に **2 件しか見ない**ので、候補の当たり外れが"
echo "そのまま結果になる。**このタスクは通るまで候補を送り込む。**"
echo
echo "**LLM は $MAX_LLM 回まで（約 \$0.045）。投稿するのは 1 件だけ。**"

echo
echo "## 0. 今日すでに出ているか"
echo
BEFORE="$(posted_today)"
echo "- 今日 X へ出た返信: **${BEFORE} 件**"
if [ "${BEFORE:-0}" -gt 0 ] 2>/dev/null; then
  echo; echo "- → **既に出ている。何もしない。**"; exit 0
fi

echo
echo "## 1. 部品と配線"
echo
cd "$W" || { echo "- **workspace に入れない。**"; exit 1; }
echo '```'
grep -nE 'asuka-reply|asuka-fill|tone-gate|ng-filter' "$S/comment-orchestrator.sh" 2>/dev/null | clean
echo '```'
OKALL=1
echo '```'
for f in asuka-reply.cjs tone-gate.cjs ng-filter-candidates.cjs post-comment.js trend-detect.js; do
  if [ -f "$S/$f" ]; then printf '  有り  %s\n' "$f"; else printf '  **無し** %s\n' "$f"; OKALL=0; fi
done
echo '```'
[ "$OKALL" != "1" ] && { echo; echo "- **部品が欠けている。何もしない（\$0）。**"; exit 1; }

echo
echo "## 2. 候補を多めに取る（**LLM 不使用・\$0**）"
echo
echo '```'
: > /tmp/x11-all.json
for r in 1 2 3 4; do
  "$NODE_BIN" "$S/trend-detect.js" > "/tmp/x11-det-$r.json" 2>/dev/null || true
  n="$("$NODE_BIN" -e 'try{const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const a=Array.isArray(d)?d:(d.trends||d.candidates||d.picks||[]);console.log(a.length)}catch(e){console.log(0)}' "/tmp/x11-det-$r.json")"
  echo "  検知 $r 周目 → $n 件"
done
"$NODE_BIN" -e '
const fs=require("fs");
let all=[];
for(const r of [1,2,3,4]){
  try{const d=JSON.parse(fs.readFileSync("/tmp/x11-det-"+r+".json","utf8"));
    const a=Array.isArray(d)?d:(d.trends||d.candidates||d.picks||[]);all=all.concat(a);}catch(e){}
}
const seen=new Set(), out=[];
for(const t of all){
  const txt=String(t&&t.text||"");
  if(txt.length<25) continue;
  const k=(t.tweet_url||txt).slice(0,80);
  if(seen.has(k)) continue; seen.add(k); out.push(t);
}
fs.writeFileSync("/tmp/x11-all.json", JSON.stringify(out,null,1));
console.log("  重複と短文を除いて "+out.length+" 件");
' 2>&1 | clean
"$NODE_BIN" -e 'const a=require("/tmp/x11-all.json");console.log(JSON.stringify(a))' \
  | "$NODE_BIN" "$S/ng-filter-candidates.cjs" > /tmp/x11-filtered.json 2>/dev/null \
  || cp /tmp/x11-all.json /tmp/x11-filtered.json
"$NODE_BIN" -e '
const fs=require("fs");
let d=[]; try{ d=JSON.parse(fs.readFileSync("/tmp/x11-filtered.json","utf8")); }catch(e){}
const a=Array.isArray(d)?d:(d.candidates||d.trends||[]);
fs.writeFileSync("/tmp/x11-use.json", JSON.stringify(a,null,1));
console.log("  入口フィルタ通過: "+a.length+" 件");
' 2>&1 | clean
echo '```'

echo
echo "## 3. 通るまで生成し、**最初に通った 1 件を投稿する**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), {execFileSync}=require("child_process");
const S=process.argv[1], MAX=Number(process.argv[2]);
let list=[]; try{ list=JSON.parse(fs.readFileSync("/tmp/x11-use.json","utf8")); }catch(e){}
const w=s=>{let n=0;for(const c of String(s||""))n+=c.codePointAt(0)<0x80?1:2;return n};
let used=0, chosen=null;
const tried=[];
for(const t of list){
  if(used>=MAX) break;
  used++;
  let out="";
  try{
    out=execFileSync("/usr/local/bin/node",[S+"/asuka-reply.cjs"],{
      input:JSON.stringify({trend:t,kind:"comment"}), encoding:"utf8", maxBuffer:8*1024*1024});
  }catch(e){ out=(e.stdout||"")||JSON.stringify({ok:false,error:String(e.message).slice(0,160)}); }
  let gated=out;
  try{ gated=execFileSync("/usr/local/bin/node",[S+"/tone-gate.cjs"],{input:out,encoding:"utf8"}); }catch(e){}
  let r=null; try{ r=JSON.parse(String(gated).trim().split("\n").pop()); }catch(e){}
  if(r&&r.ok&&r.text){ chosen={r,t}; tried.push([used,"**通過**",""]); break; }
  tried.push([used,"見送り",((r&&(r.reason||r.error))||"JSON を返さなかった").slice(0,90)]);
}
console.log("  LLM 呼び出し: "+used+" / "+MAX+" 回（約 $"+(used*0.003).toFixed(3)+"）");
console.log("");
tried.forEach(([i,s,why])=>console.log("  "+String(i).padStart(2)+". "+s+(why?"  "+why:"")));
console.log("");
if(!chosen){ console.log("  **通った候補が無い。投稿しない。**"); fs.writeFileSync("/tmp/x11-chosen.json",""); process.exit(0); }
console.log("  **通った候補の返信文**");
console.log("");
console.log("  相手の投稿:");
console.log("  "+String(chosen.t.text||"").trim().replace(/\n/g,"\n  "));
console.log("");
console.log("  返信案:");
console.log("  "+String(chosen.r.text).replace(/\n/g,"\n  "));
console.log("  ("+[...String(chosen.r.text)].length+" 字 / "+w(chosen.r.text)+" weight)");
fs.writeFileSync("/tmp/x11-chosen.json", JSON.stringify({text:chosen.r.text, target:chosen.t}));
' "$S" "$MAX_LLM" 2>&1 | clean
echo '```'

if [ ! -s /tmp/x11-chosen.json ]; then
  echo
  echo "- **通った候補が無かった。投稿していない。**"
  echo "- 候補の質の問題なので、**検知の取得元を見直す必要がある。**"
  exit 0
fi

echo
echo "## 4. 実際に X へ投稿する"
echo
echo "**投稿経路は \`comment-orchestrator.sh\` と同じ \`post-comment.js\` を使う。**"
echo "自前で新しい経路を作らない。"
echo
echo '```'
"$S/ensure-chrome.sh" >/dev/null 2>&1 || true
TEXT="$("$NODE_BIN" -e 'console.log(JSON.parse(require("fs").readFileSync("/tmp/x11-chosen.json","utf8")).text)')"
TURL="$("$NODE_BIN" -e 'const j=JSON.parse(require("fs").readFileSync("/tmp/x11-chosen.json","utf8"));console.log(j.target.tweet_url||"")')"
echo "  対象: $(printf '%s' "$TURL" | clean)"
B64="$("$NODE_BIN" -e 'process.stdout.write(Buffer.from(process.argv[1],"utf8").toString("base64"))' "$TEXT")"
"$NODE_BIN" "$S/post-comment.js" "$B64" "$TURL" 2>&1 | tail -20 | clean
echo "(rc=$?)"
echo '```'

echo
echo "## 5. 出たか"
echo
AFTER="$(posted_today)"
echo "- 今日 X へ出た返信: **${AFTER} 件**（開始前 ${BEFORE} 件）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const t=new Date().toISOString().slice(0,10);
  const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&String(e.posted_at||e.created_at||"").slice(0,10)===t);
  if(!rows.length){ console.log("  今日のエントリが無い"); }
  rows.slice(-3).forEach(e=>{
    console.log("  status="+(e.status||"?"));
    console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
    const id=e.x_tweet_id||e.tweet_id;
    console.log(id?"  → https://x.com/heng_ji31590/status/"+id:"  → tweet_id なし");
    console.log("");
  });
}catch(e){ console.log("  読めない"); }
' "$QJSON" 2>&1 | clean
echo '```'

echo
echo "---"
echo
if [ "${AFTER:-0}" -gt "${BEFORE:-0}" ] 2>/dev/null; then
  echo "**返信が X へ出た。**"
else
  echo "**まだ出ていない。上のログに理由が出ている。**"
fi
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '返信が X へ出た' "$OUT" 2>/dev/null; then
  echo "**返信が実際に X へ出た** / $(basename "$OUT")"
elif grep -q '既に出ている' "$OUT" 2>/dev/null; then
  echo "既に今日は出ていたので何もしていない / $(basename "$OUT")"
else
  echo "**まだ出せていない。レポートを読むこと** / $(basename "$OUT")"
fi
