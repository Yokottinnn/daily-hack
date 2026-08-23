#!/bin/bash
# **返信を再開し、NG 判定の差し込み位置を確定させる。**
#
# Jordan の判断: **止めずに NG 判定を先に入れる。**
# 022 が既に 3 本を止めてしまったので、まず戻す。
#
# ## 022 で分かったこと
#
#   - **NG 語彙の仕組みは存在しない。** 除外は cooldown と日次上限だけ
#   - 返信の入口は comment-orchestrator.sh
#     「trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + gen + enqueue」
#   - 候補は _cmr.js が DOM から取る（tweetText / time / links）
#   - 既存の除外リストは refollow-blacklist / unfollow-whitelist だけで、
#     **返信相手を弾くリストは無い**
#
# ## このタスクがやること
#
#   1. 返信ジョブ 3 本を戻す（止めない方針のため）
#   2. NG ルールと判定モジュールを配置する
#   3. **差し込む場所の実物を取ってくる。** 推測でシェルを書き換えない
#
# **既存スクリプトの書き換えはしない。** 位置が確定してから次のタスクで入れる。
#
# **ハンドル名は出さない。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/resume-and-prep.md"
mask() { sed -E 's#[A-Za-z0-9/_+=-]*[0-9][A-Za-z0-9/_+=-]*[A-Za-z][A-Za-z0-9/_+=-]{22,}#<MASKED>#g'; }
loaded() { launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$1"; }

{
echo "# 返信の再開と、NG 判定の差し込み位置（$(date '+%Y-%m-%d %H:%M') JST）"

echo
echo "## 1. 返信ジョブを戻す"
echo
echo "> 022 が止めたが、Jordan の判断は「止めずに NG 判定を先に入れる」。"
for lbl in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher \
           ai.openclaw.auto-thread-chainifier; do
  if loaded "$lbl"; then
    echo "- $lbl: 既に稼働"
    continue
  fi
  P="$LA/$lbl.plist"
  if [ ! -f "$P" ]; then echo "- $lbl: **plist が無い**"; continue; fi
  launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1
  if loaded "$lbl"; then
    echo "- $lbl: **戻した**"
  else
    echo "- $lbl: **戻せない**"
    launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | mask | head -2 | sed 's/^/      /'
  fi
done

echo
echo "### 確認（launchctl の実体）"
for lbl in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher \
           ai.openclaw.auto-thread-chainifier; do
  printf '  %-42s %s\n' "$lbl" "$(loaded "$lbl" && echo 稼働 || echo '**停止のまま**')"
done

echo
echo "## 2. NG ルールと判定モジュールを配置"
echo
for pair in "ops/data/reply-ng-rules.json:$W/data/reply-ng-rules.json" \
            "ops/lib/reply-ng-check.cjs:$W/scripts/reply-ng-check.cjs"; do
  src="${pair%%:*}"; dst="${pair#*:}"
  if git -C "$REPO" show "origin/main:$src" > "$dst.tmp" 2>/dev/null && [ -s "$dst.tmp" ]; then
    mv "$dst.tmp" "$dst"
    echo "- $(basename "$dst"): 配置（$(wc -c < "$dst" | tr -d ' ') B）"
  else
    rm -f "$dst.tmp"
    echo "- $(basename "$dst"): **取り出せない**"
  fi
done

echo
echo "### 実機での自己テスト"
echo '```'
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
"$NODE_BIN" -e "
try{
const {isNg}=require('$W/scripts/reply-ng-check.cjs');
const R=require('$W/data/reply-ng-rules.json');
const cases=[
 ['売春の勧誘',{bio:'パパ活してます 条件のいい方DMで'},true],
 ['ポイ活の人（誤爆NG）',{bio:'ポイ活と節約 DM開放 詳細はプロフ'},false],
 ['LINE誘導',{bio:'よろしく',text:'https://lin.ee/x'},true],
 ['節約垢です 援助希望',{bio:'節約垢です 援助希望'},true],
 ['普通の節約垢',{bio:'家計簿 楽天経済圏',text:'ふるさと納税'},false],
];
let bad=0;
for(const [n,t,want] of cases){const v=isNg(t,R);const g=v.ng===want;if(!g)bad++;
console.log((g?'OK   ':'外れ ')+n+' → ng='+v.ng+' ('+v.reason+')');}
console.log(bad===0?'全'+cases.length+'ケース 期待どおり':bad+' 件 外れた');
}catch(e){console.log('読み込めない: '+e.message);}
" 2>&1 | head -10
echo '```'

echo
echo "## 3. 差し込む場所の実物"
echo
echo "> **推測でシェルを書き換えない。** ここで実物を見てから次のタスクで入れる。"

S="$W/scripts/comment-orchestrator.sh"
if [ -f "$S" ]; then
  echo
  echo "### comment-orchestrator.sh 全 $(wc -l < "$S" | tr -d ' ') 行 / 候補〜pick の部分（30〜85 行）"
  echo '```bash'
  sed -n '30,85p' "$S" | mask
  echo '```'
else
  echo "- comment-orchestrator.sh が無い"
fi

echo
echo "### comment-warmup が実際に叩くもの"
echo '```'
launchctl print "gui/$UID_N/ai.openclaw.comment-warmup" 2>/dev/null \
  | awk '/arguments = \{/,/\}/' | mask | head -8
echo '```'

for RS in "$W/scripts/run-comment-warmup.sh" "$W/scripts/comment-warmup.sh"; do
  [ -f "$RS" ] || continue
  echo
  echo "### $(basename "$RS")（$(wc -l < "$RS" | tr -d ' ') 行 全文）"
  echo '```bash'
  mask < "$RS" | head -60
  echo '```'
done

echo
echo "### 候補 JSON の形（キー名のみ・値は出さない）"
echo '```'
"$NODE_BIN" -e "
const fs=require('fs');
const p='$W/data/post_queue.json';
try{
  const q=JSON.parse(fs.readFileSync(p,'utf8'));
  const arr=q.queue||[];
  const c=arr.filter(e=>e.id&&String(e.id).startsWith('comment-')).slice(-1)[0];
  if(c) console.log('post_queue の comment エントリのキー: '+Object.keys(c).join(', '));
  else console.log('comment エントリが無い');
}catch(e){console.log('読めない: '+e.message);}
" 2>&1 | head -5
echo '```'
} > "$OUT" 2>&1

up=0
for lbl in ai.openclaw.comment-warmup ai.openclaw.incoming-reply-watcher \
           ai.openclaw.auto-thread-chainifier; do
  launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$lbl" && up=$((up+1))
done
echo "返信ジョブ ${up}/3 稼働 / NG判定を配置 / $(basename "$OUT")"
