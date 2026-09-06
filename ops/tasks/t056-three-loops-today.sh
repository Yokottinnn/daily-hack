#!/bin/bash
# **フォロー・アンフォロー・返信の「今日の実数」を出す。費用 $0。**
#
# ## なぜ要るか
#
# 2026-09-06 に「フォロー・アンフォロー・返信はちゃんと動いてる？」と聞かれた。
# 手元にあるのは **9/5 18:05 の数字**しかない。その後にフィルタを緩めている
# （`ratio` を外した）ので、**今の数字を知らないまま「動いています」と言えない。**
#
# CLAUDE.md にこう書いてある。
#
#   > **ログが動いても「ジョブが復活した」証拠にならない。**
#   > 逆も同じで、**ロードされていても「動いている」証拠にならない。**
#
# 判定に使えるのは「**いつ・何件 フォローしたか／外したか／返したか**」だけ。
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. **フォローの日別実績**（今日を含む直近 7 日）と、今日 弾いた理由の内訳
#   2. **アンフォローの実績**（`reply-followers.json` の状態内訳と、予約の入り具合）
#   3. **返信の実績**（`comment-warmup` は未ロードのはず。**それを数字で確かめる**）
#   4. フォロワー数の推移
#   5. 3 系統のログの最終更新時刻（**止まっているのか、回って 0 件なのか**）
#
# ## やらないこと
#
# **フォローしない。アンフォローしない。返信しない。投稿しない。**
# **ジョブを触らない（load も unload も kickstart もしない）。書き換えない。**
# **LLM を呼ばない。**
#
# **ハンドルは伏せる。トークンは値を出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/three-loops-today.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"
TODAY="$(date '+%Y-%m-%d')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() {
  sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
         -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' \
         -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g'
}
clean() { hide | secrets; }

{
echo "# フォロー・アンフォロー・返信の今日（$(date '+%Y-%m-%d %H:%M') JST・費用 \$0）"
echo
echo "> **ロードされていても「動いている」証拠にならない。**"
echo "> 判定に使えるのは「いつ・何件 やったか」だけ。**何も触らずに数える。**"

echo
echo "## 0. 3 系統のジョブはロードされているか"
echo
echo '```'
for j in competitor-follower-follow hashtag-follow \
         reply-followback-check auto-detect-and-unfollow-inactive badge-followback \
         comment-warmup incoming-reply-watcher quick-reply-watcher; do
  lbl="ai.openclaw.$j"
  line="$(launchctl list 2>/dev/null | grep -F "$lbl" || true)"
  if [ -z "$line" ]; then
    printf '  **未ロード** %-38s\n' "$j"
  else
    printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-38s PID=%-8s 最後のrc=%s\n", j, $1, $2}'
  fi
done
echo '```'
echo
echo "**最後の rc が 0 以外なら失敗している。** \`-\` は「まだ一度も走っていない」。"

echo
echo "## 1. フォローの日別実績（直近 7 日）"
echo
echo '```'
for f in "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log; do
  [ -f "$f" ] || { echo "  （$(basename "$f") が無い）"; continue; }
  echo "  [$(basename "$f")] 最終更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  grep -hoE '\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[^]]*\] === end: [0-9]+/[0-9]+ OK ===' "$f" 2>/dev/null \
    | tail -14 | sed 's/^/    /'
  echo ""
done
echo '```'
echo
echo "**\`N/M OK\` の N が実際にフォローした数。** 0 が続いていれば供給が詰まっている。"

echo
echo "### 今日 弾いた理由の内訳"
echo
echo '```'
for f in "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log; do
  [ -f "$f" ] || continue
  echo "  [$(basename "$f")]"
  grep -h "$TODAY" "$f" 2>/dev/null | grep -oE '❌[^"]{0,40}' \
    | sed 's/[[:space:]]*$//' | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
  echo ""
done
echo '```'

echo
echo "### 今日 通ったもの"
echo
echo '```'
for f in "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log; do
  [ -f "$f" ] || continue
  n="$(grep -h "$TODAY" "$f" 2>/dev/null | grep -cE '✅|followed' || echo 0)"
  printf '  %-34s %s 件\n' "$(basename "$f")" "$n"
done
echo '```'

echo
echo "## 2. アンフォローの実績"
echo
echo "本体は **\`reply-followback-check.js\`**（24 時間後にフォロバを判定し、"
echo "無ければ 7〜14 日後にアンフォローを予約する）。**状態の内訳がそのまま実績になる。**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
if(!fs.existsSync(p)){ console.log("  reply-followers.json が無い"); process.exit(0); }
let s; try{ s=JSON.parse(fs.readFileSync(p,"utf8")); }catch(e){ console.log("  読めない: "+e.message); process.exit(0); }
const rows=Object.entries(s);
console.log("  総数: "+rows.length+" 件");
const by={}; let sched=0, past=0;
const now=Date.now();
for(const [h,e] of rows){
  const st=(e&&e.followback_status)||"(なし)";
  by[st]=(by[st]||0)+1;
  if(e&&e.scheduled_unfollow_at){
    sched++;
    if(new Date(e.scheduled_unfollow_at).getTime()<=now) past++;
  }
}
Object.entries(by).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>console.log("    "+k.padEnd(12)+v+" 件"));
console.log("  アンフォロー予約あり: "+sched+" 件（うち期限到来: "+past+" 件）");
if(past>0) console.log("  **期限が来ているのに残っている＝外す側が動いていない疑い**");
// 直近にフォローした日
const days={};
for(const [h,e] of rows){ const d=String(e&&e.followed_at||"").slice(0,10); if(/^\d{4}-/.test(d)) days[d]=(days[d]||0)+1; }
console.log("  followed_at の日別（直近 7 日）:");
Object.entries(days).sort((a,b)=>b[0].localeCompare(a[0])).slice(0,7)
  .forEach(([k,v])=>console.log("    "+k+"  "+v+" 件"));
' "$W/data/reply-followers.json" 2>&1 | clean
echo '```'

echo
echo "### アンフォロー系ログの最終更新"
echo
echo '```'
for n in auto-detect-and-unfollow-inactive reply-followback-check badge-followback \
         unfollow-cleanup-evening unfollow-daily revenge-unfollow; do
  f="$W/logs/$n.log"
  if [ -f "$f" ]; then
    printf '  %-38s %s  (%s 行)\n' "$n" \
      "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)" "$(wc -l < "$f" | tr -d ' ')"
  else
    printf '  %-38s （ログ無し）\n' "$n"
  fi
done
echo '```'
echo
echo "**数日 更新が無いものは、回っていない。**"

echo
echo "## 3. 返信の実績"
echo
echo '```'
for n in comment-warmup comment-orchestrator incoming-reply-watcher quick-reply-watcher; do
  f="$W/logs/$n.log"
  if [ -f "$f" ]; then
    printf '  %-30s 最終更新 %s\n' "$n" "$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)"
  else
    printf '  %-30s （ログ無し）\n' "$n"
  fi
done
echo '```'
echo
echo "### キューに積まれた返信の状態"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
if(!fs.existsSync(p)){ console.log("  post_queue.json が無い"); process.exit(0); }
let q; try{ q=JSON.parse(fs.readFileSync(p,"utf8")); }catch(e){ console.log("  読めない"); process.exit(0); }
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply"));
console.log("  comment / reply のエントリ: "+rows.length+" 件");
const by={}, days={};
for(const e of rows){
  by[e.status||"(なし)"]=(by[e.status||"(なし)"]||0)+1;
  const d=String(e.posted_at||e.created_at||"").slice(0,10);
  if(/^\d{4}-/.test(d)) days[d]=(days[d]||0)+1;
}
Object.entries(by).sort((a,b)=>b[1]-a[1]).forEach(([k,v])=>console.log("    "+k.padEnd(18)+v+" 件"));
console.log("  日別（直近 7 日）:");
const ds=Object.entries(days).sort((a,b)=>b[0].localeCompare(a[0])).slice(0,7);
if(!ds.length) console.log("    （日付つきの記録が無い）");
ds.forEach(([k,v])=>console.log("    "+k+"  "+v+" 件"));
' "$W/data/post_queue.json" 2>&1 | clean
echo '```'

echo
echo "## 4. フォロワー数の推移"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const dir=process.argv[1];
let files=[];
try{ files=fs.readdirSync(dir).filter(f=>/follower.*(snapshot|history|count)/i.test(f)); }catch(e){}
if(!files.length){ console.log("  （フォロワー数の記録が見つからない）"); }
for(const f of files){
  let raw=""; try{ raw=fs.readFileSync(path.join(dir,f),"utf8"); }catch(e){ continue; }
  let rows=[];
  if(f.endsWith(".jsonl")) rows=raw.split("\n").filter(Boolean).map(l=>{try{return JSON.parse(l)}catch(e){return null}}).filter(Boolean);
  else { let d=null; try{ d=JSON.parse(raw); }catch(e){ continue; } rows=Array.isArray(d)?d:Object.values(d||{}); }
  const pts=[];
  for(const e of rows){
    if(!e||typeof e!=="object") continue;
    const dk=Object.keys(e).find(k=>/^(date|at|taken_at|captured_at|created_at|ts|timestamp)$/i.test(k));
    const nk=Object.keys(e).find(k=>/^(followers|followers_count|follower_count|count)$/i.test(k));
    if(!dk||!nk) continue;
    const day=String(e[dk]).slice(0,10), n=Number(e[nk]);
    if(/^\d{4}-\d{2}-\d{2}$/.test(day)&&Number.isFinite(n)) pts.push([day,n]);
  }
  if(!pts.length) continue;
  pts.sort((a,b)=>a[0].localeCompare(b[0]));
  console.log("  ["+f+"]");
  let prev=null;
  for(const [d,n] of pts.slice(-10)){
    console.log("    "+d+"  "+String(n).padStart(6)+(prev===null?"":(n-prev>=0?"  +"+(n-prev):"  "+(n-prev))));
    prev=n;
  }
}
' "$W/data" 2>&1 | clean
echo '```'

echo
echo "---"
echo
echo "**何も触っていない。フォローも アンフォローも 返信も 投稿もしていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**3 系統の今日の実数を出した（変更なし・\$0）** / $(basename "$OUT")"
