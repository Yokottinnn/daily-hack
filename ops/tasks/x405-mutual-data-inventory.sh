#!/bin/bash
# x405（2026-11-03・読むだけ・$0）: 利用者「外せる相互の数を先に数える／未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォローしていいよ」。
# 数える前に、Mac に残っている記録（相互の一覧・認証済みかどうか・反応・最後の投稿・フォロワー数）の形を見る。**何も書き換えない・押さない。**
# 他人のハンドルは出さない（件数と項目名だけ）。
set -uo pipefail
W="$HOME/.openclaw/workspace"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/x405-mutual-data-inventory.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 相互を数えるための記録の棚卸し（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
echo; echo "## data/ の候補ファイル（名前・大きさ・更新）"; echo '```'
ls -la "$D" 2>/dev/null | grep -iE 'follow|verified|badge|mutual|react|profile|whitelist|reply-followers|unfollow|lists' | awk '{print $5, $6, $7, $8, $9}' | head -40
echo '```'
echo; echo "## 中身の形（キーと 1 件目の項目名・件数。ハンドルは出さない）"; echo '```'
for f in follow-balance-lists.json reply-followers.json badge-followback.json badge-followback-state.json verified-followers.json mutual-prune-state.json mutual-prune-profiles.json follow-balance-state.json follow-reactions.json reactions.json follow-dates.json; do
  [ -f "$D/$f" ] || continue
  "$NODE_BIN" -e '
const f=process.argv[1];let j;try{j=JSON.parse(require("fs").readFileSync(f,"utf8"))}catch(e){console.log(f,"読めない");process.exit(0)}
const name=require("path").basename(f);
const shape=(v)=>Array.isArray(v)?("配列 "+v.length+" 件・1件目: "+(v[0]&&typeof v[0]==="object"?Object.keys(v[0]).join(","):typeof v[0])):(v&&typeof v==="object"?("物 "+Object.keys(v).length+" 個"):typeof v);
if(Array.isArray(j)){console.log(name,":",shape(j));}
else{const ks=Object.keys(j);console.log(name,": 物 キー "+ks.length+" 個");
 const looksHandles=ks.length>20;
 if(looksHandles){const v=j[ks[0]];console.log("  1件目の項目:",v&&typeof v==="object"?Object.keys(v).join(","):typeof v);}
 else for(const k of ks.slice(0,15))console.log("  ",k,"→",shape(j[k]));}
' "$D/$f" 2>&1
done
echo '```'
echo; echo "## 他のファイルで「verified」を持つもの"; echo '```'
grep -l '"verified"' "$D"/*.json 2>/dev/null | head -10 | xargs -n1 basename 2>/dev/null
echo '```'
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
