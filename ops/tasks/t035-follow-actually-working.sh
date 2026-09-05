#!/bin/bash
# **フォロー 2 件が「ロードされている」だけでなく、実際に動いているかを確かめる。費用 $0。**
#
# ## なぜ要るのか
#
# `heartbeat.json` に載るのは `launchctl list` の結果、つまり**登録されているか**だけ。
# **登録されていても動いていないことがある。** 実際に `t016` で
# フォロー系のログが **8/9 で止まっている**のを見つけていながら、
# 確認タスク（t021）をブランチから落としたまま作り直していなかった。
#
# CLAUDE.md にも書いてある。
#
#   > **ログが動いても「ジョブが復活した」証拠にならない。**
#
# 逆も同じで、**ロードされていても「動いている」証拠にならない。**
# 判定に使えるのは「**いつ・誰を・何人 フォローしたか**」の実績だけ。
#
# ## 出すもの（すべて無料・LLM を呼ばない）
#
#   1. 2 つのジョブの plist（**実行間隔と、実際に叩いているスクリプト**）
#   2. `launchctl list` の生の行（**最後の終了コード**。0 以外なら失敗している）
#   3. 各ログの**最終更新時刻と末尾**（止まっているのか、回って何もしていないのか）
#   4. **フォロー実績**（`reply-followers.json` などの状態ファイルから日付ごとに数える）
#   5. 次回の実行予定
#
# 3 と 4 を突き合わせれば、**「回っているが 0 件」なのか「そもそも回っていない」**かが分かる。
#
# ## やらないこと
#
# **フォローしない。投稿しない。ジョブを触らない（load も unload もしない）。**
# **書き換えない。LLM を呼ばない。**
#
# **API キーは値を出さない。ハンドルは伏せる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-actually-working.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
LA="$HOME/Library/LaunchAgents"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

JOBS="ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow"

{
echo "# フォローは本当に動いているか（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> \`heartbeat.json\` に載るのは**登録されているか**だけ。"
echo "> **登録されていても動いていないことがある。** \`t016\` でログが 8/9 で"
echo "> 止まっているのを見つけながら、確認タスクを落としたまま作り直していなかった。"
echo "> **フォローしない。投稿しない。ジョブを触らない。LLM も呼ばない。**"

echo
echo "## 1. \`launchctl list\`（**最後の終了コード**）"
echo
echo "0 以外なら失敗している。\`-\` は「まだ一度も走っていない」。"
echo
echo '```'
printf '%-46s %-10s %s\n' "ラベル" "PID" "最後のrc"
for j in $JOBS; do
  line="$(launchctl list 2>/dev/null | grep -F "$j" || true)"
  if [ -z "$line" ]; then
    printf '%-46s %s\n' "$j" "**未ロード**"
  else
    printf '%s\n' "$line" | awk -v j="$j" '{printf "%-46s %-10s %s\n", j, $1, $2}'
  fi
done
echo '```'

echo
echo "## 2. plist（**間隔と、叩いているもの**）"
for j in $JOBS; do
  echo
  echo "### \`$j\`"
  P="$LA/$j.plist"
  if [ ! -f "$P" ]; then echo; echo "- **plist が無い**（$P）"; continue; fi
  echo
  echo "- 更新: $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)"
  echo
  echo '```xml'
  grep -A2 -E 'StartInterval|StartCalendarInterval|ProgramArguments|Minute|Hour|StandardOutPath|Label' "$P" 2>/dev/null \
    | grep -vE '^--$' | head -30 | cut -c1-160 | hide | mask
  echo '```'
done

echo
echo "## 3. ログ（**止まっているのか、回って 0 件なのか**）"
echo
for f in "$W"/logs/*follow*.log "$W"/logs/*Follow*.log; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\`"
  echo
  echo "- 最終更新: **$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null)** / $(wc -l < "$f" | tr -d ' ') 行"
  echo
  echo '```'
  tail -12 "$f" 2>/dev/null | cut -c1-170 | hide | mask
  echo '```'
  echo
done

echo
echo "## 4. フォロー実績（**日付ごとに数える**）"
echo
echo "ログが動いていても、**実際にフォローしていなければ意味がない。**"
echo
echo '```'
"$NODE_BIN" -e '
const fs=require("fs"), path=require("path");
const dir=process.argv[1];
let files=[];
try{ files=fs.readdirSync(dir).filter(f=>/follow|following|followed/i.test(f)&&f.endsWith(".json")); }catch(e){}
if(!files.length){ console.log("（follow 系の状態ファイルが無い）"); }
for(const f of files){
  let d=null;
  try{ d=JSON.parse(fs.readFileSync(path.join(dir,f),"utf8")); }catch(e){ console.log(f+": 読めない"); continue; }
  const st=fs.statSync(path.join(dir,f));
  const rows = Array.isArray(d) ? d : Object.values(d||{});
  const byDay={};
  let total=0;
  for(const e of rows){
    if(!e||typeof e!=="object") continue;
    const k=Object.keys(e).find(k=>/^(followed_at|created_at|at|date|time)$/i.test(k));
    if(!k) continue;
    const day=String(e[k]).slice(0,10);
    if(!/^\d{4}-\d{2}-\d{2}$/.test(day)) continue;
    byDay[day]=(byDay[day]||0)+1; total++;
  }
  console.log("["+f+"] 件数 "+rows.length+" / 日付つき "+total+" / 更新 "+st.mtime.toISOString().slice(0,16).replace("T"," "));
  Object.entries(byDay).sort((a,b)=>b[0].localeCompare(a[0])).slice(0,10)
    .forEach(([k,v])=>console.log("    "+k+"  "+v+" 件"));
  if(!total) console.log("    （日付つきの記録が無い）");
  console.log("");
}
' "$W/data" 2>&1 | hide | mask
echo '```'

echo
echo "## 5. 次回の実行予定"
echo
echo '```'
for j in $JOBS; do
  P="$LA/$j.plist"
  iv="$(grep -A1 'StartInterval' "$P" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  if [ -n "$iv" ]; then
    echo "$j: ${iv} 秒ごと（$((iv/60)) 分）"
  else
    echo "$j: 時刻指定（下の Minute/Hour を参照）"
    grep -A1 -E '<key>(Minute|Hour)</key>' "$P" 2>/dev/null | grep -oE '<integer>[0-9]+' | tr -d '<integer>' | tr '\n' ' '
    echo
  fi
done
echo '```'

echo
echo "---"
echo
echo "**フォローしていない。投稿していない。ジョブも触っていない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
if grep -q '最後の終了コード' "$OUT" 2>/dev/null; then echo "**フォローの実態を出した（変更なし・\$0）** / $(basename "$OUT")"
else echo "調べきれなかった / $(basename "$OUT")"; fi
