#!/bin/bash
# x455（2026-11-10・読むだけ・$0）: 利用者が「他にも無いか調べる」を選んだ。22:04 の返信が相手の借金にそのまま触れていた。
# 直近 3 日（11/8・11/10・今日まで）の comment-warmup の成功した返信を全部読み、借金・損・トラブルに踏み込んだものを数える。
# 他人のハンドルは伏せる。投稿・削除はしない。
set -uo pipefail
L="$HOME/.openclaw/workspace/logs"; OUT="${OPS_REPORT_DIR:-/tmp}/x455-read-risky-replies.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 借金・損・トラブルに踏み込んだ返信（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo '```'
grep -hE '^\{"ok":true,"entry_id":"comment-2026(1107|1108|1109|1110|1111)' "$L/comment-warmup.log" 2>/dev/null | "$NODE_BIN" -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const rows=s.split("\n").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch(e){return null}}).filter(Boolean);
if(rows[0])console.log("項目: "+Object.keys(rows[0]).join(","));
const pick=o=>{for(const k of ["reply_text","text","comment","reply","body"])if(typeof o[k]==="string")return o[k];return ""};
const tgt=o=>{for(const k of ["target_text","source_text","parent_text","target"])if(typeof o[k]==="string")return o[k];return ""};
const R=/借金|借入|ローン|赤字|損|失敗|滞納|破産|債務|貧乏|金欠|無職|失業|病気|入院|離婚|亡く|事故|詐欺|不正|被害|マイナス|やらかし/;
let n=0,hit=0;for(const o of rows){n++;const t=pick(o),g=tgt(o);if(R.test(t)||R.test(g)){hit++;console.log("- "+o.entry_id+" "+(o.x_tweet_id||"")+"\n  返信: "+t.replace(/@[A-Za-z0-9_]{2,15}/g,"@<伏せ>").replace(/\n/g," ").slice(0,140)+"\n  相手: "+g.replace(/@[A-Za-z0-9_]{2,15}/g,"@<伏せ>").replace(/\n/g," ").slice(0,100))}}
console.log("対象 "+n+" 件 / 当たった "+hit+" 件")});'
echo '```'
} > "$OUT" 2>&1
grep -E '対象 [0-9]+' "$OUT" | head -1
exit 0
