#!/bin/bash
# **同じ相手に何回返信しているかを数え、相手ごとの間隔を決めている箇所を読む。読むだけ。費用 $0。**
#
# ## 指示（2026-10-11）
#
#   > このアカウントに返信すぎなので控えてほしい（https://x.com/money_yossy）
#   > 投稿数が多い場合に毎回毎回返してたら不自然だから、同じ相手へのリプライは1日1回迄にして
#   > 何回も同じようの返信するのであれば、他のアカウントに分散させてフォロワー増える機会を効率的に作ってほしい
#
# comment-orchestrator は選ぶときに `comment-state.js can-comment <相手>` を呼んでいる（x66）。
# **その中で相手ごとに何時間あけているかが、まだ読めていない。** 直す前に実物を読む（最上位ルール 20）。
#
#   ① comment-state.js の全文（相手ごとの間隔・1 日の上限がどこにあるか）
#   ② comment-state.json の設定（targets 以外の数値。targets は件数だけ）
#   ③ キュー（post_queue.json）の返信を「相手 × 日」で数える。直近 7 日（JST）
#      - money_yossy は名指しで全件（日時・どのジョブか・本文の先頭）
#      - ほかの相手は**伏せて**、1 日 2 回以上の相手が何人いるかだけ
#   ④ 返信を出しているスクリプトの一覧（target_handle を積む／auto-reply.js を呼ぶもの）と、
#      それぞれが can-comment を通っているか
#   ⑤ 返信を出すジョブ（launchd）の載り具合
#
# **書き換えない。投稿しない。LLM を呼ばない。ブラウザを触らない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/reply-per-target.md"
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(xox[abp]-)[A-Za-z0-9-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
# 自分と、指示で名指しされた相手以外のハンドルは伏せる
hide() { perl -pe 's/@(?!(?:heng_ji31590|money_yossy)\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# 同じ相手への返信の回数と、相手ごとの間隔（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"

echo
echo "## ① comment-state.js の全文"
echo
if [ -f "$S/comment-state.js" ]; then
  echo "\`\`\`js"
  printf '// %s 行 / 最終更新 %s\n' "$(wc -l < "$S/comment-state.js" | tr -d ' ')" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$S/comment-state.js")"
  cat "$S/comment-state.js" | secrets | hide
  echo "\`\`\`"
else
  echo "**無い: $S/comment-state.js**"
fi

echo
echo "## ② comment-state.json の設定（targets は件数だけ）"
echo
echo '```'
node -e '
const fs=require("fs");const p=process.argv[1];
try{const j=JSON.parse(fs.readFileSync(p,"utf8"));
const show=(o,pre)=>{for(const [k,v] of Object.entries(o)){
  if(Array.isArray(v)) console.log(pre+k+": 配列 "+v.length+" 件"+(v.length&&typeof v[0]!=="object"?"（先頭の型 "+typeof v[0]+"）":""));
  else if(v&&typeof v==="object") { const n=Object.keys(v).length; if(n>12) console.log(pre+k+": オブジェクト "+n+" キー"); else { console.log(pre+k+":"); show(v,pre+"  "); } }
  else console.log(pre+k+": "+JSON.stringify(v));
}};show(j,"  ");
const t=j.targets||[]; console.log("  targets に money_yossy: "+(JSON.stringify(t).includes("money_yossy")?"在る":"無い"));
}catch(e){console.log("  読めない: "+e.message)}' "$D/comment-state.json" 2>&1 | secrets | hide
echo '```'

echo
echo "## ③ 返信を「相手 × 日」で数える（キュー・直近 7 日・JST）"
echo
node -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")).queue||[];
const since=Date.now()-7*864e5;
const jst=(t)=>new Date(t+9*3600e3).toISOString();
const when=(e)=>{for(const k of ["posted_at","created_at","enqueued_at","updated_at"]){const t=Date.parse(e[k]||"");if(t)return t;}
  const m=String(e.id||"").match(/(20\d{6})-(\d{4})/); if(m) return Date.parse(m[1].slice(0,4)+"-"+m[1].slice(4,6)+"-"+m[1].slice(6)+"T"+m[2].slice(0,2)+":"+m[2].slice(2)+":00+09:00"); return 0;};
const handle=(e)=>String(e.target_handle||e.reply_to_handle||e.in_reply_to_handle||(String(e.target_url||e.reply_to_url||"").match(/x\.com\/([A-Za-z0-9_]+)\/status/)||[])[1]||"").replace(/^@/,"");
const posted=(e)=>!!(e.x_tweet_id||e.tweet_id||e.status==="posted");
const job=(e)=>String(e.id||"?").replace(/-?\d{8}.*$/,"")||"?";
const rows=q.filter(e=>handle(e)&&when(e)>=since);
console.log("対象: 相手が分かる返信 "+rows.length+" 件（うち投稿済み "+rows.filter(posted).length+" 件）／キュー全体 "+q.length+" 件\n");
// money_yossy は全件
const my=rows.filter(e=>handle(e).toLowerCase()==="money_yossy").sort((a,b)=>when(a)-when(b));
console.log("### money_yossy への返信 "+my.length+" 件（投稿済み "+my.filter(posted).length+" 件）\n");
console.log("| JST | ジョブ | 投稿済み | 本文の先頭 |\n| --- | --- | --- | --- |");
for(const e of my) console.log("| "+jst(when(e)).slice(5,16).replace("T"," ")+" | "+job(e)+" | "+(posted(e)?"はい":"いいえ（"+(e.status||"?")+"）")+" | "+String(e.text||"").replace(/\s+/g," ").slice(0,40)+" |");
// 相手 × 日
const per={};for(const e of rows.filter(posted)){const k=handle(e).toLowerCase()+"|"+jst(when(e)).slice(0,10);(per[k]=per[k]||[]).push(e);}
const multi=Object.entries(per).filter(([k,v])=>v.length>=2);
console.log("\n### 投稿済みで、同じ相手に 1 日 2 回以上返した組（相手 × 日）: "+multi.length+" 組\n");
const byJob={};for(const [k,v] of multi) for(const e of v) byJob[job(e)]=(byJob[job(e)]||0)+1;
console.log("ジョブ別（その組に含まれる返信の数）: "+JSON.stringify(byJob)+"\n");
console.log("| 相手 | 日 | 回数 | ジョブ |\n| --- | --- | --- | --- |");
for(const [k,v] of multi.sort((a,b)=>b[1].length-a[1].length).slice(0,20)){const [h,d]=k.split("|");
  console.log("| "+(h==="money_yossy"?h:h.slice(0,2)+"…("+h.length+"字)")+" | "+d+" | "+v.length+" | "+[...new Set(v.map(job))].join(",")+" |");}
// 7 日で回数の多い相手
const tot={};for(const e of rows.filter(posted)){const h=handle(e).toLowerCase();tot[h]=(tot[h]||0)+1;}
const top=Object.entries(tot).sort((a,b)=>b[1]-a[1]);
console.log("\n### 7 日の合計で多い相手（上位 10・伏せ）／相手の数 "+top.length+" 人\n");
for(const [h,n] of top.slice(0,10)) console.log("- "+(h==="money_yossy"?h:h.slice(0,2)+"…("+h.length+"字)")+" "+n+" 回");
' "$D/post_queue.json" 2>&1 | secrets

echo
echo "## ④ 返信を出しているスクリプトと、can-comment を通っているか"
echo
echo '```'
for f in $(grep -lE "target_handle|auto-reply\.js|kind: *'comment'|kind: *\"comment\"|kind:'reply'|kind: *\"reply\"" "$S"/*.js "$S"/*.cjs "$S"/*.sh 2>/dev/null); do
  b=$(basename "$f")
  c=$(grep -c "can-comment\|canComment" "$f" 2>/dev/null | head -1)
  printf '  %-34s can-comment を呼ぶ行 %s\n' "$b" "${c:-0}"
done
echo '```'
echo
echo "auto-reply.js の頭（どこから呼ばれ、何を確かめてから出すか）"
echo
echo '```js'
[ -f "$S/auto-reply.js" ] && sed -n '1,60p' "$S/auto-reply.js" | secrets | hide || echo "無い"
echo '```'

echo
echo "## ⑤ 返信を出すジョブの載り具合（launchctl print）"
echo
echo '```'
for L in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher ai.openclaw.quick-reply-watcher ai.openclaw.auto-thread-chainifier; do
  if launchctl print "gui/$(id -u)/$L" >/dev/null 2>&1; then
    printf '  %-40s 載っている / %s\n' "$L" "$(launchctl print "gui/$(id -u)/$L" 2>/dev/null | grep -E 'runs =|last exit code' | tr -s ' ' | tr '\n' ' ')"
  else
    printf '  %-40s 載っていない\n' "$L"
  fi
done
echo '```'

echo
echo "**書き換えていない。投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1
echo "同じ相手への返信の回数を数えた / $(basename "$OUT")"
