#!/bin/bash
# **出口の検査が実際に効いているかを、発火後のログで確かめる。**
#
# 035 で comment-orchestrator.sh に差し込んだ（2026-08-29 00:51 JST）。
# **差し込んだ＝効いている、ではない。** 直前の発火は 22:03 で差し込み前だった。
#
# ## 見るもの
#
#   1. ログに tone-gate の行が出ているか（出ていなければ効いていない）
#   2. 通過 / 送るが記録する / 送らない の内訳
#   3. **過去の投稿を通したらどうなるか**（較正の確認）
#      post_queue の comment エントリを検査にかけ、いま block になる文が
#      どれだけあるかを数える。**多すぎれば厳しすぎ、0 なら緩すぎ**
#   4. block に当たった過去の投稿の x_tweet_id（消す判断の材料）
#
# ## 較正の考え方
#
# 弾きすぎると返信が 0 件になり、緩すぎると意味がない。
# **1 日 8 件のうち 1〜2 件 落ちるくらいが妥当**という見立て。
# 実測がそこから大きく外れていたら、rules を直す根拠にする。
#
# **読むだけ。何も書き換えない。LLM を呼ばない（費用 $0）。**
# **ハンドルは伏せる。** 返信文は X 上で公開済みなので伏せない。
# **plutil -extract は使わない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/verify-tone-gate.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide_handle() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# 出口の検査は効いているか（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **差し込んだ＝効いている、ではない。** 発火後のログで確かめる。"

echo
echo "## 1. 組み込みの状態"
echo
S="$W/scripts/comment-orchestrator.sh"
grep -q 'tone-gate' "$S" 2>/dev/null && echo "- 出口（tone-gate）: **組み込み済み**" || echo "- 出口（tone-gate）: **未**"
grep -q 'ng-filter-candidates' "$S" 2>/dev/null && echo "- 入口（ng-filter）: **組み込み済み**" || echo "- 入口（ng-filter）: **未**"
for f in scripts/tone-gate.cjs scripts/reply-tone-check.cjs data/reply-tone-rules.json; do
  [ -f "$W/$f" ] && echo "- $f: 有り（$(wc -c < "$W/$f" | tr -d ' ') B）" || echo "- $f: **無い**"
done
echo "- テンプレート数: $("$NODE_BIN" -e "
try{const t=JSON.parse(require('fs').readFileSync('$W/data/comment-templates.json','utf8'));
const a=Array.isArray(t)?t:(t.list||t.templates||[]);
console.log(a.length+' 件（T03/T06 が無ければ 35）');
const ids=a.map(x=>String(x.id));
console.log('  T03: '+(ids.includes('T03')?'**残っている**':'除去済み')+' / T06: '+(ids.includes('T06')?'**残っている**':'除去済み'));
}catch(e){console.log('読めない')}" 2>&1)"

echo
echo "## 2. 発火後のログに出ているか"
echo
L="$W/logs/comment-warmup.log"
if [ ! -f "$L" ]; then
  echo "**ログが無い。**"
else
  echo "- ログ最終更新: $(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  n="$(grep -c 'tone-gate' "$L" 2>/dev/null || true)"
  echo "- tone-gate の行: **${n:-0} 行**"
  if [ "${n:-0}" = "0" ]; then
    echo
    echo "**まだ 1 度も通っていない。** 差し込み後の発火が来ていないか、差し込みが効いていない。"
    echo
    echo "直近の発火（=== で始まる行）:"
    grep -nE '^\[.*\] ===|orchestrator done' "$L" 2>/dev/null | tail -6 | mask | cut -c1-140 | sed 's/^/    /'
  else
    echo
    echo "内訳:"
    printf '      通過:           %s 行\n' "$(grep -c 'tone-gate: 通過' "$L" 2>/dev/null || echo 0)"
    printf '      送るが記録する: %s 行\n' "$(grep -c 'tone-gate: 送るが記録する' "$L" 2>/dev/null || echo 0)"
    printf '      送らない:       %s 行\n' "$(grep -c 'tone-gate: \*\*送らない\*\*' "$L" 2>/dev/null || echo 0)"
    printf '      素通し:         %s 行\n' "$(grep -c 'tone-gate: .*素通し' "$L" 2>/dev/null || echo 0)"
    echo
    echo "直近の tone-gate 行（20 件）:"
    grep 'tone-gate' "$L" 2>/dev/null | tail -20 | hide_handle | mask | cut -c1-150 | sed 's/^/    /'
  fi
fi

echo
echo "## 3. 較正 — 過去の投稿を通したらどうなるか"
echo
echo "**弾きすぎると返信が 0 件になり、緩すぎると意味がない。**"
echo "1 日 8 件のうち 1〜2 件 落ちるくらいが妥当という見立て。実測を出す。"
echo
"$NODE_BIN" -e "
const fs=require('fs'), path=require('path');
const W='$W';
let checkTone, rules;
try{
  ({checkTone}=require(path.join(W,'scripts','reply-tone-check.cjs')));
  rules=JSON.parse(fs.readFileSync(path.join(W,'data','reply-tone-rules.json'),'utf8'));
}catch(e){ console.log('判定を読めない: '+e.message); process.exit(0); }
let q;
try{ q=JSON.parse(fs.readFileSync(path.join(W,'data','post_queue.json'),'utf8')); }
catch(e){ console.log('post_queue.json が読めない'); process.exit(0); }
const arr=(q.queue||[]).filter(e=>e.id&&String(e.id).startsWith('comment-')&&e.text);
const recent=arr.slice(-200);
let nb=0, nw=0, np=0;
const byKind={};
const blocked=[];
for(const e of recent){
  let v; try{ v=checkTone(e.text, rules); }catch(err){ continue; }
  for(const r of v.reasons) byKind[r.level+':'+r.kind]=(byKind[r.level+':'+r.kind]||0)+1;
  if(v.block){ nb++; blocked.push({e,v}); } else if(v.warn) nw++; else np++;
}
console.log('- 検査した件数: '+recent.length+' 件（post_queue の直近 comment）');
console.log('- **送らない（block）: '+nb+' 件（'+(nb/recent.length*100).toFixed(1)+'%）**');
console.log('- 送るが記録（warn）: '+nw+' 件（'+(nw/recent.length*100).toFixed(1)+'%）');
console.log('- 通過: '+np+' 件（'+(np/recent.length*100).toFixed(1)+'%）');
console.log('');
console.log('- 1 日 8 件に換算すると block は約 '+(nb/recent.length*8).toFixed(1)+' 件/日');
console.log('');
console.log('理由別の内訳:');
for(const [k,n] of Object.entries(byKind).sort((a,b)=>b[1]-a[1]))
  console.log('      '+k.padEnd(22)+' '+n);
console.log('');
console.log('## 4. block に当たった過去の投稿（**X 上に残っている可能性がある**）');
console.log('');
if(!blocked.length){ console.log('- 無し'); }
else {
  console.log('消す判断のために id を出す。**本文は X 上で公開済みなので伏せない。**');
  console.log('');
  for(const {e,v} of blocked.slice(-25)){
    const why=v.reasons.filter(r=>r.level==='block').map(r=>r.kind+'='+String(r.hit).slice(0,20)).join(' ');
    console.log('---');
    console.log('  理由: '+why);
    console.log('  投稿: '+(e.x_tweet_id||'(未投稿)')+'  '+(e.posted_at||e.created_at||''));
    console.log('  本文: '+String(e.text).replace(/\n/g,' ').slice(0,120));
  }
}
" 2>&1 | hide_handle | head -80

echo
echo "## 5. 判断"
echo
echo "- block が **0 件** → 緩すぎる。ルールを足す"
echo "- block が **1 日 3 件以上** → 厳しすぎる。返信量が落ちる。warn へ移す"
echo "- block が **1 日 0.5〜2 件** → 妥当。このまま様子を見る"
echo
echo "**上限と実績を混同しない。** 上は換算値であって、実機の発火実績ではない。"
} > "$OUT" 2>&1

n="$(grep -oE 'tone-gate の行: \*\*[0-9]+ 行' "$OUT" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
echo "tone-gate のログ ${n:-0} 行 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
