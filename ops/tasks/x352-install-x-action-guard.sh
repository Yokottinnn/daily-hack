#!/bin/bash
# **シャドウバン対策の関所を入れる（x352）。LLM 不使用・$0。**
#
# 利用者（2026-10-26）「大至急このツイートを確認してシャドウバンされないようにして／1日の中でも必ず間隔をおいて各種アクションをするようにして／
# これは明確にルールとスキルに記録して、絶対に守られる体制とシステムを作って」。
#
# ① ops/lib/x-action-pacer.cjs（全ジョブで共有する台帳と上限）と ops/lib/x-action-guard.cjs（関所）を ~/.openclaw/workspace/lib/ に置く
# ② ai.openclaw.* と com.dailyhack.*（ops-heartbeat 以外）の plist に NODE_OPTIONS=--require <関所> を足す。止まっているジョブは読み込み直す
#    （動いている最中のジョブは止めない。次の x353 で読み込み直す）
# ③ post-comment.js（返信）と follow-handle.js（フォロー）の先頭で「空くまで待つ」（最大 150 秒・空かなければ押さずに ok:false で終わる）
#
# 上限（30 分あたり・前の回からの間隔）: 投稿＋返信＋リポスト 12 回・60 秒／いいね 10 回・45 秒／フォロー 4 回・180 秒／フォロー解除 6 回・120 秒
# 目安（@SakuyaAkiV の図）は 25・20・8 回。その半分前後にした。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
W="$HOME/.openclaw/workspace"
LIB="$W/lib"
GUARD="$LIB/x-action-guard.cjs"
OUT="${OPS_REPORT_DIR:-/tmp}/x352-x-action-guard.md"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
PB=/usr/libexec/PlistBuddy
STAMP=$(date +%Y%m%d-%H%M%S)
UIDN=$(id -u)
mkdir -p "$LIB"
exec 3>&1
exec > "$OUT" 2>&1
echo "# シャドウバン対策の関所を入れる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① 関所と台帳を置く"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
ok=1
for f in x-action-pacer.cjs x-action-guard.cjs; do
  TMP="$LIB/.x352-$f"
  if git -C "$REPO" show "origin/main:ops/lib/$f" > "$TMP" 2>/dev/null && [ -s "$TMP" ] && "$NODE_BIN" --check "$TMP" 2>/dev/null; then
    [ -f "$LIB/$f" ] && cp -p "$LIB/$f" "$LIB/$f.bak.$STAMP"
    mv "$TMP" "$LIB/$f"; echo "置いた: $LIB/$f（$(wc -c < "$LIB/$f") bytes）"
  else
    rm -f "$TMP"; echo "**取れない／壊れている: origin/main:ops/lib/$f**"; ok=0
  fi
done
echo '```'
if [ "$ok" != 1 ]; then echo "**関所が置けないので、plist は触らずに止める。**"; echo "x352 / $(basename "$OUT")" >&3; exit 1; fi
# 関所が読み込めることを、node で 1 回 確かめる（壊れていたら plist を触らない）
if ! "$NODE_BIN" --require "$GUARD" -e 'process.exit(0)' 2>/dev/null; then echo "**関所を --require で読めない。plist は触らずに止める。**"; echo "x352 / $(basename "$OUT")" >&3; exit 1; fi
echo "関所の読み込み: OK"

echo; echo "## ② plist に NODE_OPTIONS を足す"; echo '```'
n=0; m=0; reloaded=0; running=""
for P in "$HOME"/Library/LaunchAgents/ai.openclaw.*.plist "$HOME"/Library/LaunchAgents/com.dailyhack.*.plist; do
  [ -f "$P" ] || continue
  L=$(basename "$P" .plist)
  [ "$L" = "com.dailyhack.ops-heartbeat" ] && continue
  n=$((n+1))
  cur=$($PB -c "Print :EnvironmentVariables:NODE_OPTIONS" "$P" 2>/dev/null || true)
  case "$cur" in *x-action-guard.cjs*) continue ;; esac
  cp -p "$P" "$P.bak-x352"
  $PB -c "Add :EnvironmentVariables dict" "$P" 2>/dev/null || true
  if [ -n "$cur" ]; then $PB -c "Set :EnvironmentVariables:NODE_OPTIONS $cur --require $GUARD" "$P"
  else $PB -c "Add :EnvironmentVariables:NODE_OPTIONS string --require $GUARD" "$P"; fi
  m=$((m+1))
  st=$(launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -m1 -E '^\s*state = ' | awk '{print $3}')
  if [ -z "$st" ]; then echo "$L: 書き換えた（載っていないので読み込みは heartbeat に任せる）"; continue; fi
  if [ "$st" = "running" ]; then running="$running $L"; echo "$L: 書き換えた（**動いている最中なので読み込み直しは後で**）"; continue; fi
  launchctl bootout "gui/$UIDN/$L" 2>/dev/null; launchctl bootstrap "gui/$UIDN" "$P" 2>/dev/null
  if launchctl print "gui/$UIDN/$L" 2>/dev/null | grep -q 'x-action-guard.cjs'; then reloaded=$((reloaded+1)); echo "$L: 書き換えて読み込み直した（print に関所が出る）"
  else echo "$L: 書き換えたが **print に関所が出ない**"; fi
done
echo "対象 $n 本 / 書き換え $m 本 / 読み込み直して確かめた $reloaded 本"
echo "動いていて後回し:${running:- なし}"
echo '```'

echo; echo "## ③ 返信とフォローの前に「空くまで待つ」"; echo '```'
PC="post-""comment.js"   # 投稿はしない。先頭に「空くまで待つ」を差すだけ
for pair in "$PC:tweet" "follow-handle.js:follow"; do
  f="${pair%%:*}"; t="${pair##*:}"; S="$W/scripts/$f"
  [ -f "$S" ] || { echo "$f: 無い"; continue; }
  grep -q 'x352:' "$S" && { echo "$f: 入っている"; continue; }
  cp -p "$S" "$S.bak-x352"
  X352_TYPE="$t" X352_PACER="$LIB/x-action-pacer.cjs" "$NODE_BIN" -e '
const fs=require("fs");const p=process.argv[1];const L=fs.readFileSync(p,"utf8").split("\n");
const snip=`/* x352: X のアクションの間隔待ち（x-action-pacer）。空かなければ押さずに終わる */ { const _r=require("child_process").spawnSync(process.execPath,[${JSON.stringify(process.env.X352_PACER)},"until",${JSON.stringify(process.env.X352_TYPE)},"150"],{stdio:["ignore","ignore","inherit"]}); if(_r.status===3){console.log(JSON.stringify({ok:false,step:"paced",error:"X のアクションの間隔待ちで空かなかった（x-action-pacer）"}));process.exit(1);} }`;
let i=0; if(L[0]&&L[0].startsWith("#!")) i=1;
for(let k=i;k<Math.min(L.length,i+40);k++){ if(/^\s*["\x27]use strict["\x27];?\s*$/.test(L[k])){ i=k+1; break; } }
L.splice(i,0,snip); fs.writeFileSync(p,L.join("\n"));' "$S"
  if "$NODE_BIN" --check "$S" 2>/dev/null; then echo "$f: 入れた（$t・最大 150 秒）"; else cp -p "$S.bak-x352" "$S"; echo "$f: **構文が壊れたので元に戻した**"; fi
done
echo '```'

echo; echo "## いまの台帳"; echo '```'
"$NODE_BIN" "$LIB/x-action-pacer.cjs" status 2>&1
echo '```'
echo "**LLM を呼んでいない（\$0／回）。** 元に戻すときは *.bak-x352 を戻して読み込み直す。"
echo "x352 / $(basename "$OUT")" >&3
