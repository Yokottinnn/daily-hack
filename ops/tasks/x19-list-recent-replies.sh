#!/bin/bash
# **実際に出た返信のリンクを、直近 20 件 まとめて出す。費用 $0。読むだけ。**
#
# ## 聞かれたこと
#
#   > 返信の実際の投稿リンクを共有して
#
# ## 出典は 1 つだけ
#
# **キューの `x_tweet_id` / `tweet_id`**（最上位ルール 11）。
# ID があるということは、その ID で X に出ているということ。
#
# **使わないもの**: `heartbeat.json` の `posted_today`（ログの行数）／
# ログの grep 件数／過去のレポート。
#
# ## 出すもの
#
#   1. **直近 20 件の 日時・URL・本文**（新しい順）
#   2. 日別の件数（直近 14 日）
#   3. 累計
#
# **投稿しない。返信しない。ブラウザを触らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/recent-replies.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 実際に出た返信のリンク（直近 20 件）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 出典は **キューの \`x_tweet_id\` / \`tweet_id\` だけ**。"
echo "> ID があるということは、その ID で X に出ているということ。"
echo "> \`posted_today\`（ログの行数）もログの grep 件数も使っていない。"

echo
echo "## 直近 20 件（新しい順）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  **キューが読めない: "+e.message+"**"); process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
if(!rows.length){ console.log("  **投稿済みの返信が 1 件も無い。**"); process.exit(0); }
const when=e=>String(e.posted_at||e.created_at||"");
// UTC の ISO を JST 表記に直す（キューは Z 付きで入っている）
const jst=s=>{ const d=new Date(s); return isNaN(d)?s:
  new Date(d.getTime()+9*3600*1000).toISOString().replace("T"," ").slice(0,16)+" JST"; };
const last=rows.slice(-20).reverse();
last.forEach((e,i)=>{
  const tid=e.x_tweet_id||e.tweet_id;
  console.log("  "+String(i+1).padStart(2)+". "+jst(when(e))+"   status="+(e.status||"?"));
  console.log("      https://x.com/heng_ji31590/status/"+tid);
  console.log("      "+String(e.text||"(本文なし)").replace(/\n/g,"\n      "));
  console.log("");
});
' "$QJSON" 2>&1 | clean
echo '```'

echo
echo "## 日別の件数（直近 14 日）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }catch(e){ process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
const by={};
rows.forEach(e=>{
  const s=String(e.posted_at||e.created_at||""); const d=new Date(s);
  const k=isNaN(d)?s.slice(0,10):new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10);
  if(k) by[k]=(by[k]||0)+1;
});
console.log("  投稿済み 累計: "+rows.length+" 件");
console.log("");
console.log("  日付(JST)     件数");
Object.keys(by).sort().slice(-14).forEach(d=>console.log("  "+d+"   "+String(by[d]).padStart(3)+" 件"));
' "$QJSON" 2>&1 | clean
echo '```'
echo
echo "**目標は 16 件/日**（2026-09-06 に 8 → 16 へ増量）。上の表が実績。"

echo
echo "---"
echo
echo "**投稿していない。ブラウザも触っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
T="$(grep -m1 -oE '投稿済み 累計: [0-9]+ 件' "$OUT" 2>/dev/null || echo '件数不明')"
echo "**$(date '+%H:%M') 返信リンク 直近 20 件を出した（\$0）** / $T / $(basename "$OUT")"
