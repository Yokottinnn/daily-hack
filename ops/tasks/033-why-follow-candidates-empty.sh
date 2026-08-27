#!/bin/bash
# **フォロー候補がゼロになる原因を突き止める。**
#
# 029 の実測でこうなっていた。
#
#   competitor-follower-follow:  === end: 0/5 OK ===   ← cap 5 のうち 実績 0 件
#   hashtag-follow:              picks: 0 authors      ← cap 90 のうち 実績 0 件
#
# **上限ではなく候補の供給が詰まっている。** cap を 10 に上げても 0/10 になる。
# 「cap を上げればペースが上がる」と報告したのは誤りだった。
#
# ## 仮説（どれが正しいかは実機のログで決める。推測で断定しない）
#
#   A. 弾く条件が厳しすぎる（`❌ low-density bio` で全部落ちている）
#   B. 探しに行く先が枯れている（同じ競合アカウントを舐め尽くした）
#   C. 既フォロー・解除済みの重複除外で候補が消えている
#      followed.json は 157 件中 unfollowed=129。**解除した相手を再び候補にしないなら
#      プールは減り続ける。** 補充が無ければいずれ 0 になる
#   D. 取得そのものが失敗している（DOM 変化・ログイン切れ・CDP）
#
# ## 見るもの
#
#   1. 1 回の実行で「何件見て、何件を、どの理由で弾いたか」
#   2. 弾く条件のコード（low-density bio の実体）
#   3. 探索元のリスト（件数と最終更新。**ハンドルは出さない**）
#   4. 重複除外がどこまで効いているか
#
# **読むだけ。何も書き換えない。LLM を呼ばない（費用 $0）。**
# **plutil -extract は使わない。** **ハンドル名は出さない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
OUT="${OPS_REPORT_DIR:-/tmp}/follow-bottleneck.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
hide_handle() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }

{
echo "# フォロー候補がゼロになる原因（$(date '+%Y-%m-%d %H:%M') JST）"
echo
echo "> **上限ではなく供給が詰まっている。** cap を上げても 0/10 になるだけ。"
echo "> どの仮説が当たりかを、実機のログとコードで決める。**推測で断定しない。**"

echo
echo "## 1. 直近 1 回の実行を丸ごと読む"
echo
for name in competitor-follower-follow hashtag-follow; do
  L="$W/logs/$name.log"
  echo "### $name"
  if [ ! -f "$L" ]; then echo "- ログ無し"; echo; continue; fi
  echo "- 最終更新: $(date -r "$L" '+%m-%d %H:%M' 2>/dev/null)"
  echo
  echo '```'
  # 最後の "=== start" 以降を全部出す。1 回分の全景が要る
  awk '/=== *start/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$L" 2>/dev/null \
    | hide_handle | mask | cut -c1-160 | tail -60
  echo '```'
  echo
  echo "- 弾いた理由の内訳（直近 200 行）:"
  tail -200 "$L" 2>/dev/null | grep -oE '❌ [^(（]{3,40}' | sort | uniq -c | sort -rn \
    | head -12 | sed 's/^/      /'
  echo
done

echo
echo "## 2. 弾く条件のコード"
echo
for f in competitor-follower-follow.js hashtag-follow.js; do
  p="$W/scripts/$f"
  echo "### $f"
  if [ ! -f "$p" ]; then echo "- 無し"; echo; continue; fi
  echo "- 行数: $(wc -l < "$p" | tr -d ' ')"
  echo
  echo '```javascript'
  grep -nE 'low-density|density|❌|skip|reject|bio|MIN_|MAX_|threshold|filter\(|continue' "$p" 2>/dev/null \
    | hide_handle | mask | cut -c1-150 | head -30
  echo '```'
  echo
done

echo
echo "## 3. 探索元は枯れていないか"
echo
"$NODE_BIN" -e "
const fs=require('fs'),path=require('path');
const W='$W';
function stat(p){try{return fs.statSync(path.join(W,p))}catch(e){return null}}
function j(p){try{return JSON.parse(fs.readFileSync(path.join(W,p),'utf8'))}catch(e){return null}}
function n(x){ if(Array.isArray(x))return x.length;
  if(x&&typeof x==='object'){const a=Object.values(x).find(v=>Array.isArray(v));return a?a.length:Object.keys(x).length;}
  return '?'; }
// **ハンドルは一切出さない。件数と更新時刻だけ**
for(const p of ['data/competitor-accounts.json','data/competitors.json','data/follow-targets.json',
                'data/hashtags.json','data/hashtag-targets.json','data/followed.json',
                'data/follow-queue.json','data/scanned-accounts.json','data/quick-reply-targets.json']){
  const s=stat(p); if(!s) continue;
  const d=j(p);
  console.log('- '+p+': '+n(d)+' 件 / 更新 '+new Date(s.mtime).toISOString().slice(0,16).replace('T',' '));
}
// 除外プールの大きさ
const f=j('data/followed.json');
if(f){
  const arr=Array.isArray(f)?f:(f.followed||[]);
  const by={};
  for(const r of arr){const s=(r&&r.status)||'(なし)';by[s]=(by[s]||0)+1;}
  console.log('');
  console.log('- followed.json の状態別: '+Object.entries(by).map(([k,v])=>k+'='+v).join(' / '));
  console.log('  → **解除済みを再候補にしないなら、この数だけプールが減っている**');
  // 最後にフォローできた日
  const ts=arr.map(r=>r&&r.followed_at).filter(Boolean).sort();
  if(ts.length) console.log('  最後にフォローできた日時: '+String(ts[ts.length-1]).slice(0,16));
}
" 2>&1 | hide_handle | head -25

echo
echo "## 4. 重複除外はどこで効いているか"
echo
for f in competitor-follower-follow.js hashtag-follow.js; do
  p="$W/scripts/$f"
  [ -f "$p" ] || continue
  echo "### $f"
  echo '```javascript'
  grep -nE 'followed\.json|already|seen|has\(|includes\(|unfollowed|dedup|Set\(' "$p" 2>/dev/null \
    | hide_handle | mask | cut -c1-150 | head -15
  echo '```'
  echo
done

echo
echo "## 5. 取得そのものは成功しているか"
echo
echo "候補が 0 なのは「弾いた」のか「そもそも取れていない」のか。**ここを混同しない。**"
echo
for name in competitor-follower-follow hashtag-follow; do
  L="$W/logs/$name.log"
  [ -f "$L" ] || continue
  echo "- $name の取得件数らしき行（直近 20）:"
  grep -oE '(scanned|found|fetched|candidates|picks|authors|targets)[: ]+[0-9]+|[0-9]+ (candidates|authors|targets|accounts)' \
    "$L" 2>/dev/null | tail -20 | sed 's/^/      /'
  echo "- エラー行（直近 10）:"
  grep -iE 'error|fail|ECONNREFUSED|timeout|not logged|denied' "$L" 2>/dev/null \
    | tail -10 | hide_handle | mask | cut -c1-140 | sed 's/^/      /'
  echo
done

echo
echo "## 6. どの仮説だったか"
echo
echo "上を読んで、次のどれかに丸を付けること。**複数でも良いが、根拠の行を必ず添える。**"
echo
echo "    A. 弾く条件が厳しすぎる（取れているのに全部落ちる）"
echo "    B. 探索元が枯れている（そもそも新しい候補が出てこない）"
echo "    C. 重複除外でプールが尽きた（解除済み 129 件が戻らない）"
echo "    D. 取得が失敗している（DOM・ログイン・CDP）"
} > "$OUT" 2>&1

echo "フォロー候補の詰まりを調べた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
