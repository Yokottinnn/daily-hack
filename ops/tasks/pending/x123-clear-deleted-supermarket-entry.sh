#!/bin/bash
# **消された格安スーパーの投稿を、キューから「無かったこと」にする。費用 $0。**
#
# ## なぜ待たせているか（pending/ に在る理由）
#
# **利用者が画像を直したいので投稿を消した。** 直った画像で出し直すが、
# **その前にキューを片付けないと、出し直すタスクが「既に出ている」と判断して何もしない。**
#
# 画像の修正がまだ終わっていないので、**このタスクも出し直しと同じ時に上げる。**
# 先に上げてしまうと、キューだけ消えて投稿が無い状態になり、
# **「出ていないのに出したつもり」の隙間ができる。**
#
# ## 何が残っているか
#
#   id         : blog-promo-20260921-tokyo-discount-supermarket-2026
#   status     : posted
#   x_tweet_id : 2101944276943044941   ← **X 上では消えている**
#   chain[1]   : 2101944356974571908   ← **同上**
#
# `x112` の二重投稿ガードは **slug で「投稿済み」を数えている**ので、
# このエントリが残っている限り、出し直しは `既に出ている` で止まる。
#
# ## どう片付けるか（**消さない。印を変える**）
#
# **エントリごと消さない。** 消すと「いつ出して、いつ消えたか」が辿れなくなる。
#
#   status     : posted → deleted_by_user
#   x_tweet_id : 消す（**死んだ ID を残すと一次情報として誤読される**・最上位ルール 11）
#   deleted_at : いつ片付けたか
#   note       : なぜ消えたか
#
# **出し直しは別の id で積む**（`…-tokyo-discount-supermarket-2026-v2`）。
# 同じ id を使い回すと、履歴が上書きされて 1 回目が消える。
#
# ## やらないこと
#
# **投稿しない。画像を作らない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
QJSON="$W/data/post_queue.json"
OUT="${OPS_REPORT_DIR:-/tmp}/clear-deleted-supermarket-entry.md"
LOCK="$W/data/.x112-super-post.lock"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
ID="blog-promo-20260921-tokyo-discount-supermarket-2026"

{
echo "# 消された告知をキューから片付ける（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **利用者が画像を直したいので投稿を消した。** 出し直す前にキューを片付ける。"
echo "> 残っていると、出し直しが \`既に出ている\` で止まる。"
echo ">"
echo "> **エントリごとは消さない。** 消すと「いつ出して、いつ消えたか」が辿れなくなる。"
echo "> **\`x_tweet_id\` だけは消す** — 死んだ ID を残すと一次情報として誤読される。"

echo
echo "## 1. 片付ける前の状態"
echo
echo '```json'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const e=(q.queue||[]).find(x=>x&&x.id===process.argv[2]);
  if(!e){ console.log("  該当エントリが無い（もう片付いている）"); process.exit(0); }
  console.log(JSON.stringify({
    id:e.id, status:e.status, x_tweet_id:e.x_tweet_id||null,
    posted_at:e.posted_at||null,
    chain:(e.thread_chain||[]).map((c,i)=>({n:i+1, tweet_id:c.x_tweet_id||null}))
  },null,1));
}catch(err){ console.log("  キューが読めない: "+err.message); }
' "$QJSON" "$ID" 2>&1
echo '```'

echo
echo "## 2. 印を変える"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const [qp,id]=process.argv.slice(1);
let q;
try{ q=JSON.parse(fs.readFileSync(qp,"utf8")); }
catch(e){ console.log("  キューが読めない。何もしない: "+e.message); process.exit(1); }
const e=(q.queue||[]).find(x=>x&&x.id===id);
if(!e){ console.log("  該当エントリが無い。何もしない"); process.exit(0); }
if(e.status!=="posted"){ console.log("  status が posted ではない（"+e.status+"）。何もしない"); process.exit(0); }

e.status="deleted_by_user";
e.deleted_at=new Date().toISOString();
e.note="利用者が画像を直すため X 上で削除。出し直しは -v2 の id で積む";
// **死んだ ID は消す。** 残すと一次情報として誤読される（最上位ルール 11）
e.deleted_x_tweet_id=e.x_tweet_id||null;
delete e.x_tweet_id;
for(const c of (e.thread_chain||[])){
  if(c.x_tweet_id){ c.deleted_x_tweet_id=c.x_tweet_id; delete c.x_tweet_id; }
}

fs.writeFileSync(qp+".tmp", JSON.stringify(q,null,2));
// **書いたものを自分で読み直す。** 壊れた JSON を置いて気づかないのを防ぐ
try{ JSON.parse(fs.readFileSync(qp+".tmp","utf8")); }
catch(err){ console.log("  **書いた JSON が壊れている。差し替えない**"); process.exit(1); }
fs.renameSync(qp+".tmp", qp);
console.log("  status を deleted_by_user にした");
console.log("  x_tweet_id を deleted_x_tweet_id へ退避した（本体からは消した）");
' "$QJSON" "$ID" 2>&1
echo '```'

echo
echo "## 3. ロックも外す"
echo
echo '```'
if [ -f "$LOCK" ]; then
  rm -f "$LOCK" && echo "  ロックを外した（$LOCK）"
else
  echo "  ロックは無い"
fi
echo '```'
echo
echo "**ロックが残っていると、出し直しが「二重に走らせない」で止まる。**"

echo
echo "## 4. 片付いたか（**別の口で確かめる**）"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=q.queue||[];
  const still=rows.filter(e=>{
    if(!e||typeof e!=="object") return false;
    const t=(e.id||"")+" "+(e.text||"")+" "+(e.target_url||"");
    return t.includes("tokyo-discount-supermarket-2026")
        && (e.status==="posted"||e.x_tweet_id||e.tweet_id);
  });
  console.log("  「投稿済み」と数えられる件数: "+still.length+" 件");
  if(still.length===0) console.log("  **0 件。出し直せる状態**");
  else { console.log("  **まだ残っている。出し直しは止まる**");
         still.forEach(e=>console.log("    "+e.id+" / "+e.status)); }
}catch(err){ console.log("  キューが読めない: "+err.message); }
' "$QJSON" 2>&1
echo '```'
echo
echo "**この数え方は \`x112\` の二重投稿ガードと同じ。** 同じ口で確かめている。"

echo
echo "## 5. 費用"
echo
echo "**キューの JSON を 1 か所 書き換えるだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

echo "消された告知を片付けた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
