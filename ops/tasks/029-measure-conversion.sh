#!/bin/bash
# **ペースを上げる手を、実測の上に立てる。**
#
# 現状（8/27）
#   211 人 / 目標 300 人 / 残り 34 日 → 必要 +2.62 人/日
#   実測ペース +1.25 人/日 → このままだと 9/30 に約 254 人（46 人 不足）
#   上積みが +1.37 人/日 要る
#
# ## 数字を推測で作らない
#
# 「cap を上げれば何人増えるか」を出すには、**1 フォローあたり何人が
# フォローバックするか**が要る。それを知らずに「cap を 2 倍」と言っても
# 増加後の人数が出せない。ここでその変換率を実測する。
#
#   1. 各フォロージョブが 1 日に実際に何件フォローしているか
#   2. フォローした相手のうち何割が返してくるか（badge-followback の記録）
#   3. 現在の cap と発火回数、上限まで使い切っているか
#   4. 返信 1 件あたり何人フォロワーが増えているか
#
# **上限（cap）と実績を混同しない。** 両方出して、どちらがどちらか明示する。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
# **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/conversion.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"

{
echo "# フォロワー増加の変換率（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **上限と実績を混同しない。** 両方出して、どちらがどちらか明示する。"

echo
echo "## 1. 各ジョブの実績と上限"
echo
for row in "competitor-follower-follow:COMPETITOR_FOLLOW_DAILY_CAP:④ 能動フォロー（競合）" \
           "hashtag-follow:HASHTAG_FOLLOW_DAILY_CAP:④ 能動フォロー（タグ）" \
           "badge-followback::② フォロー返し" \
           "comment-warmup:MAX_PICKS_PER_FIRE:返信"; do
  name="${row%%:*}"; rest="${row#*:}"
  envk="${rest%%:*}"; role="${rest#*:}"
  L="$W/logs/$name.log"
  echo "### $role — $name"

  # plist の環境変数（読み取り専用の -p だけを使う）
  P="$HOME/Library/LaunchAgents/ai.openclaw.$name.plist"
  if [ -n "$envk" ] && [ -f "$P" ]; then
    v="$(plutil -p "$P" 2>/dev/null | grep -A1 "\"$envk\"" | grep -oE '"[0-9]+"' | tr -d '"' | head -1)"
    [ -z "$v" ] && v="$(plutil -p "$P" 2>/dev/null | grep "\"$envk\"" | grep -oE '=> "?[0-9]+' | grep -oE '[0-9]+' | head -1)"
    echo "- 上限（$envk）: ${v:-読めない}"
  fi
  # 発火回数
  if [ -f "$P" ]; then
    fires="$(plutil -p "$P" 2>/dev/null | grep -c '"Hour"' || true)"
    echo "- 1 日の発火回数: ${fires:-0} 回"
  fi

  if [ ! -f "$L" ]; then echo "- ログ: 無し"; echo; continue; fi
  echo "- ログ最終更新: $(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  echo "- 直近 7 日の 1 日あたり行数:"
  i=0
  while [ "$i" -lt 7 ]; do
    d="$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d')"
    printf '      %s  %s 行\n' "$d" "$(grep -c "$d" "$L" 2>/dev/null || echo 0)"
    i=$((i+1))
  done
  echo "- 直近 3 行（実際に何件打ったかが読める）:"
  tail -3 "$L" 2>/dev/null | mask | cut -c1-150 | sed 's/^/      /'
  echo
done

echo
echo "## 2. フォローバックの変換率"
echo
"$NODE_BIN" -e "
const fs=require('fs'),path=require('path');
const W='$W';
function j(p){try{return JSON.parse(fs.readFileSync(path.join(W,p),'utf8'))}catch(e){return null}}
const followed=j('data/followed.json');
if(followed){
  const arr=Array.isArray(followed)?followed:(followed.followed||Object.values(followed)[0]||[]);
  console.log('- followed.json: '+(Array.isArray(arr)?arr.length:'?')+' 件');
  if(Array.isArray(arr)&&arr.length&&typeof arr[0]==='object'){
    console.log('  レコードのキー: '+Object.keys(arr[0]).join(', '));
    // 状態別の集計（ハンドル名は出さない）
    const by={};
    for(const r of arr){const s=r.status||r.state||'(状態なし)';by[s]=(by[s]||0)+1;}
    console.log('  状態別: '+Object.entries(by).map(([k,v])=>k+'='+v).join(' / '));
    // フォローバック率
    const back=Object.entries(by).filter(([k])=>/back|mutual|followed_back/i.test(k)).reduce((a,[,v])=>a+v,0);
    if(back) console.log('  → フォローバック率: '+(back/arr.length*100).toFixed(1)+'%');
  }
} else console.log('- followed.json: 読めない');
const rf=j('data/reply-followers.json');
if(rf){const a=Array.isArray(rf)?rf:(rf.handles||rf.followers||Object.values(rf)[0]||[]);
  console.log('- reply-followers.json（返信きっかけ）: '+(Array.isArray(a)?a.length:'?')+' 件');}
" 2>&1 | head -15

echo
echo "## 3. フォロワー推移（実測）"
echo
"$NODE_BIN" -e "
const fs=require('fs');
const p='$W/logs/follower-snapshot.log';
try{
  const pairs={};
  for(const line of fs.readFileSync(p,'utf8').split('\n')){
    const md=line.match(/(\d{4}-\d{2}-\d{2})/), mc=line.match(/\"count_today\":(\d+)/);
    if(md&&mc) pairs[md[1]]=+mc[1];
  }
  const it=Object.entries(pairs).sort().slice(-14);
  let prev=null;
  for(const [d,c] of it){ console.log('    '+d+'  '+c+(prev===null?'':'  ('+(c-prev>=0?'+':'')+(c-prev)+')')); prev=c; }
  if(it.length>=2){
    const days=(new Date(it[it.length-1][0])-new Date(it[0][0]))/86400000||1;
    const pace=(it[it.length-1][1]-it[0][1])/days;
    const left=(new Date('2026-09-30')-new Date(it[it.length-1][0]))/86400000;
    console.log('');
    console.log('  実測ペース: '+(pace>=0?'+':'')+pace.toFixed(2)+' 人/日');
    console.log('  必要ペース: +'+((300-it[it.length-1][1])/left).toFixed(2)+' 人/日');
    console.log('  このままの 9/30 見込み: 約 '+Math.round(it[it.length-1][1]+pace*left)+' 人');
  }
}catch(e){console.log('    読めない: '+e.message)}
" 2>&1 | head -22

echo
echo "## 4. 引き上げ余地"
echo
echo "上限まで使い切っているなら cap を上げる意味がある。"
echo "使い切っていないなら、cap ではなく**候補が足りない**のが原因。"
echo
echo "competitor-follower-follow の直近の実行行（cap と実際の件数）:"
grep -oE 'cap=[0-9]+|followed [0-9]+|follow(ed)? ?: ?[0-9]+|skip[a-z]* [0-9]+' \
  "$W/logs/competitor-follower-follow.log" 2>/dev/null | tail -12 | sed 's/^/    /'
echo
echo "hashtag-follow の直近の実行行:"
grep -oE 'cap=[0-9]+|followed [0-9]+|follow(ed)? ?: ?[0-9]+|skip[a-z]* [0-9]+' \
  "$W/logs/hashtag-follow.log" 2>/dev/null | tail -12 | sed 's/^/    /'

echo
echo "## 5. NG 判定は効いているか"
echo
if grep -q 'ng-filter-candidates' "$W/scripts/comment-orchestrator.sh" 2>/dev/null; then
  echo "- 組み込み: **済み**"
  echo "- ログ中の ng-filter 行（直近 5 件）:"
  grep 'ng-filter' "$W/logs/comment-warmup.log" 2>/dev/null | tail -5 | mask | sed 's/^/      /'
  grep -q 'ng-filter' "$W/logs/comment-warmup.log" 2>/dev/null || echo "      （まだ発火していない）"
else
  echo "- 組み込み: **未**"
fi
} > "$OUT" 2>&1

echo "変換率を測定 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
