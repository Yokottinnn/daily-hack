#!/bin/bash
# x528（2026-11-21・読むだけ・$0）: フォロワー対策の下調べ（利用者がダイアログで「返してくれる相手に寄せる」「相互の解除を元に戻す」「外し返しが多いのかも教えて」を選んだ）。
#  ① フォローのジョブ（競合のフォロワー・ハッシュタグ・follow-handle）が、相手のフォロワー数でふるい分けできる環境変数を持っているか（process.env の行だけ出す）
#  ② plist にいま入っている FOLLOW_* の値
#  ③ 外し返しを数える材料: mutual-prune・follow-balance が外した記録と、フォロワーの一覧の記録がどこにあるか（ファイル名・件数・キーだけ。ハンドルは出さない）
# 何も押さない・何も変えない。LLM 不使用。
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; D="$W/data"; LA="$HOME/Library/LaunchAgents"; PB=/usr/libexec/PlistBuddy
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x528-read-follow-filters-and-unfollow-back.md"
clean() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s/(xox[abp]-|sk-ant-|sk-)[A-Za-z0-9_-]{6,}/<伏せ>/g; s/(auth_token=|ct0=)[A-Za-z0-9]+/$1<伏せ>/g'; }
{
echo "# フォロワー対策の下調べ（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① フォローのジョブが読む環境変数"
for f in competitor-follower-follow.js hashtag-follow.js follow-handle.js badge-followback.js comment-warmup.js mutual-prune.js follow-balance.js; do
  echo; echo "### $f"; echo '```'
  if [ -f "$S/$f" ]; then grep -nE 'process\.env\.[A-Z_]+' "$S/$f" | grep -oE 'process\.env\.[A-Z_]+[^;]{0,90}' | sort -u | head -40 | clean
    echo "-- followers を比べている行"; grep -nE 'followers?(Count|_count)?\s*(<|>|<=|>=)|(<|>|<=|>=)\s*followers' "$S/$f" | head -12 | cut -c1-180 | clean
  else echo "無い"; fi
  echo '```'
done
echo; echo "## ② plist に入っている FOLLOW_*・MUTUAL_*・GRACE"
for n in competitor-follower-follow hashtag-follow comment-warmup badge-followback mutual-prune follow-balance; do
  P="$LA/ai.openclaw.$n.plist"; [ -f "$P" ] || continue
  echo; echo "### $n"; echo '```'; "$PB" -c "Print :EnvironmentVariables" "$P" 2>/dev/null | grep -E 'FOLLOW|MUTUAL|GRACE|MAX_|MIN_|CAP' | sed 's/^ *//' ; echo '```'
done
echo; echo "## ③ 外した記録・フォロワーの記録（ファイル名・大きさ・更新日・件数・キー）"
echo '```'
ls -la "$D" 2>/dev/null | grep -iE 'unfollow|mutual|prune|balance|follower|following|followback|follow-' | awk '{print $5, $6, $7, $8, $9}'
echo '```'
echo '```'
for f in "$D"/*; do
  b="$(basename "$f")"; case "$b" in *unfollow*|*mutual*|*prune*|*balance*|*follower*|*following*|*followback*) ;; *) continue;; esac
  case "$b" in *.json) "$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];let j;try{j=JSON.parse(fs.readFileSync(p,"utf8"))}catch(e){console.log(require("path").basename(p)+": 読めない "+e.message.slice(0,60));process.exit(0)}
const desc=v=>Array.isArray(v)?("配列 "+v.length+" 件"+(v[0]&&typeof v[0]==="object"?" キー: "+Object.keys(v[0]).slice(0,14).join(","):"")):(v&&typeof v==="object"?("オブジェクト "+Object.keys(v).length+" キー"+(Object.keys(v).length?" 例のキーの形: "+(typeof v[Object.keys(v)[0]]==="object"?Object.keys(v[Object.keys(v)[0]]||{}).slice(0,12).join(","):typeof v[Object.keys(v)[0]]):"")):typeof v);
console.log(require("path").basename(p)+": "+desc(j));
if(j&&typeof j==="object"&&!Array.isArray(j))for(const k of Object.keys(j).slice(0,8))if(!/^@|^[0-9]{5,}$/.test(k))console.log("   ."+k+": "+desc(j[k]));' "$f" ;;
  *.jsonl|*.log) echo "$b: $(wc -l < "$f" | tr -d ' ') 行 ／ 最後の行のキー: $(tail -1 "$f" | "$NODE_BIN" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(Object.keys(JSON.parse(s)).join(","))}catch(e){console.log("JSON でない")}})')" ;;
  esac
done 2>&1 | clean | head -80
echo '```'
echo; echo "## ④ ログ: mutual-prune が外した件数（日ごと・直近 14 日）"
echo '```'
for lf in "$W/logs/mutual-prune.log" "$W/logs/mutual-prune-out.log"; do [ -f "$lf" ] && { echo "--- $(basename "$lf")"; grep -aoE '^\[?20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$lf" | tr -d '[' | sort | uniq -c | tail -14; grep -aiE 'unfollow|外した' "$lf" | tail -3 | cut -c1-160 | clean; }; done
echo '```'
echo; echo "**読むだけ。LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -cE '^### ' "$OUT"
exit 0
