#!/bin/bash
# **キューにある blog-promo を全部 並べて、何が出ていて何が出ていないかを一次情報で出す。**
#
# ## なぜ
#
# 2026-09-20 に「投稿したのってポイ活の方だけだよね？ 全くコメントしてないけどまさか勝手に？」
# と聞かれた。**こちらの手元にあるのは x110 のレポート 1 枚だけ**で、
# それは「walk-poikatsu-2026 に一致するもの」しか数えていない。
#
# **キュー全体を見ていない状態で「ほかは出ていません」と言うのは、一次情報ではない**
# （最上位ルール 11）。だから全部 並べる。
#
# ## 一次情報は 2 つだけ
#
#   * キューの `x_tweet_id` / `tweet_id`
#   * 投稿 URL の実物
#
# `posted_today` や ログの grep 件数、過去レポートは**一次情報ではない。**
#
# ## やらないこと
#
# **投稿しない。積まない。消さない。LLM を呼ばない（$0）。読むだけ。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
QJSON="$W/data/post_queue.json"
OUT="${OPS_REPORT_DIR:-/tmp}/audit-posted-promos.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

{
echo "# キューの blog-promo を全部 並べる（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 「ポイ活だけ出したんだよね？」に一次情報で答えるためのもの。"
echo "> **読むだけ。投稿も追加も削除もしない。**"

echo
echo "## 1. キューにある \`blog-promo-\` の全エントリ"
echo
echo '```'
if [ ! -f "$QJSON" ]; then
  echo "  **キューのファイルが無い: $QJSON**"
else
  "$NODE_BIN" -e '
const fs=require("fs");
let q;
try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }
catch(e){ console.log("  **キューが読めない: "+e.message+"**"); process.exit(0); }
const rows=(q.queue||q||[]).filter(e=>e&&typeof e==="object");
const promos=rows.filter(e=>String(e.id||"").startsWith("blog-promo-"));
console.log("  キュー全体: "+rows.length+" 件 / うち blog-promo: "+promos.length+" 件");
console.log("");
if(!promos.length){ console.log("  **blog-promo は 1 件も無い。**"); process.exit(0); }
console.log("  id                                              status          出たか");
console.log("  "+"-".repeat(78));
for(const e of promos){
  const tid=e.x_tweet_id||e.tweet_id||null;
  const chain=Array.isArray(e.thread_chain)?e.thread_chain:[];
  const got=chain.filter(c=>c&&(c.x_tweet_id||c.tweet_id)).length;
  const mark = tid ? ("出た "+(chain.length?got+"/"+chain.length+" 本":"")) : "**出ていない**";
  console.log("  "+String(e.id).padEnd(48)+String(e.status||"-").padEnd(16)+mark);
}
console.log("");
console.log("  === 出たものの tweet_id と URL（一次情報） ===");
let any=false;
for(const e of promos){
  const tid=e.x_tweet_id||e.tweet_id;
  if(!tid) continue;
  any=true;
  console.log("  "+e.id);
  console.log("    [1] "+tid+"  https://x.com/heng_ji31590/status/"+tid);
  (e.thread_chain||[]).forEach((c,i)=>{
    const t=c&&(c.x_tweet_id||c.tweet_id);
    if(i===0) return;
    console.log("    ["+(i+1)+"] "+(t? t+"  https://x.com/heng_ji31590/status/"+t : "**取れていない＝片肺の疑い**"));
  });
  console.log("    posted_at: "+(e.posted_at||"（無い）"));
}
if(!any) console.log("  **出たものは 1 件も無い。**");
' "$QJSON" 2>&1 | hide
fi
echo '```'

echo
echo "## 2. 今日 出たもの（日付で絞る）"
echo
echo '```'
if [ -f "$QJSON" ]; then
  "$NODE_BIN" -e '
const fs=require("fs");
let q; try{ q=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); }catch(e){ console.log("  読めない"); process.exit(0); }
const rows=(q.queue||q||[]).filter(e=>e&&typeof e==="object");
// **JST の「今日」で見る。** UTC で切ると 9 時間 ずれる
const now=new Date();
const jst=new Date(now.getTime()+9*3600*1000);
const key=jst.toISOString().slice(0,10);
const hit=rows.filter(e=>{
  const t=e.posted_at||e.updated_at||"";
  if(!t) return false;
  const d=new Date(t); if(isNaN(d)) return false;
  return new Date(d.getTime()+9*3600*1000).toISOString().slice(0,10)===key
      && (e.x_tweet_id||e.tweet_id);
});
console.log("  JST の今日（"+key+"）に出たもの: **"+hit.length+" 件**");
for(const e of hit){
  console.log("    "+String(e.id||"(id なし)")+"  kind="+(e.kind||"-")
    +"  tweet_id="+(e.x_tweet_id||e.tweet_id));
}
if(!hit.length) console.log("    （無し）");
' "$QJSON" 2>&1 | hide
fi
echo '```'
echo
echo "**\`kind\` が \`comment\` / \`reply\` のものは返信ループが出したもの**で、告知とは別物。"
echo "告知は \`kind: thread\` かつ \`id\` が \`blog-promo-\` 始まりのものだけ。"

echo
echo "## 3. 読み方"
echo
echo "- **\`x_tweet_id\` が無いものは出ていない。** \`status\` が何であっても関係ない"
echo "- **\`thread_chain\` の本数と、ID が取れた本数が合わなければ片肺**"
echo "- **X 上で人が手で投稿したものは、ここには出ない**"

echo
echo "## 4. 費用"
echo
echo "**ファイルを読んで並べるだけ。LLM を呼ばない。**"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 1 回あたり | **\$0** |"
echo "| 1 日あたり | **\$0** |"
echo "| 1 か月あたり | **\$0** |"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "blog-promo の棚卸し / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
