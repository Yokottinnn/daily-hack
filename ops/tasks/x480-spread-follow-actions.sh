#!/bin/bash
# x480（2026-11-14・$0）: スパムのラベル対策の第 1 段。利用者がダイアログで選んだ「1 回の起動で 1〜2 件まで」「始まる時刻と間隔をランダム」を入れる。
#  ① 間隔の決まり（x-action-pacer.cjs）を置き直す: フォローと解除を合わせて 30 分 4 回、間隔は 3〜12 分のランダム
#  ② 起動のばらつき（x-jitter.sh）を置き、フォロー・解除のジョブの起動の先頭に足す（0〜25 分待ってから始める）
#  ③ follow-handle.js: 押す直前に waitTake("follow")（記録する）。いままでフォローが台帳に記録されず、間隔と 1 日の上限が効いていなかった（x478）。先頭の until（待つだけ）はそのまま
#  ④ badge-followback.js: 押す前に waitTake("follow") を入れる（いままで間隔の決まりを通らず 5〜15 秒おきに押していた）
#  ⑤ 1 回あたりの上限を 2 件に（plist の環境変数）。badge-followback の 0:50 の起動を 21:50 に移す
# どのファイルも元を .bak-x480 に残し、node --check / plutil -lint が通らなければ元に戻す。走っている最中のジョブは触らない。LLM を呼ばない。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
W="$HOME/.openclaw/workspace"; LIB="$W/lib"; S="$W/scripts"; LA="$HOME/Library/LaunchAgents"
PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x480-spread-follow-actions.md"
JIT="$LIB/x-jitter.sh"
running() { [ "$(launchctl print "gui/$UIDN/$1" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')" = "running" ]; }
setenv() { local P="$1" K="$2" V="$3"
  if "$PB" -c "Print :EnvironmentVariables" "$P" >/dev/null 2>&1; then :; else "$PB" -c "Add :EnvironmentVariables dict" "$P"; fi
  if "$PB" -c "Print :EnvironmentVariables:$K" "$P" >/dev/null 2>&1; then "$PB" -c "Set :EnvironmentVariables:$K $V" "$P"; else "$PB" -c "Add :EnvironmentVariables:$K string $V" "$P"; fi; }
{
echo "# 自動のフォロー・解除を散らす（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
git -C "$REPO" fetch -q origin main 2>/dev/null
echo; echo "## ① ② 間隔の決まりと起動のばらつきを置く"; echo '```'
for f in x-action-pacer.cjs x-jitter.sh; do
  T="$LIB/.x480-$f"
  if git -C "$REPO" show "origin/main:ops/lib/$f" > "$T" 2>/dev/null && [ -s "$T" ]; then
    okc=1; case "$f" in *.cjs) "$NODE_BIN" --check "$T" 2>/dev/null || okc=0 ;; *.sh) bash -n "$T" 2>/dev/null || okc=0 ;; esac
    if [ "$okc" = 1 ]; then [ -f "$LIB/$f" ] && cp -p "$LIB/$f" "$LIB/$f.bak-x480"; mv "$T" "$LIB/$f"; chmod +x "$LIB/$f"; echo "置いた: $f"; else rm -f "$T"; echo "**壊れている: $f（置かない）**"; fi
  else rm -f "$T"; echo "**取れない: $f**"; fi
done
grep -q 'COMBINED' "$LIB/x-action-pacer.cjs" && echo "pacer: フォロー＋解除の合算とランダムな間隔 → 入っている"
"$NODE_BIN" "$LIB/x-action-pacer.cjs" status 2>&1
echo '```'
echo; echo "## ③ follow-handle.js の押す直前で『記録して待つ』"; echo '```'
F="$S/follow-handle.js"
ANCH="const btn = await page.waitForSelector('[data-testid\$=\"-follow\"]'"
if grep -q 'x480: 押す直前に' "$F" 2>/dev/null; then echo "もう入っている"
elif [ "$(grep -cF "const btn = await page.waitForSelector('[data-testid\$=\"-follow\"]'" "$F" | head -1)" = "1" ]; then
  cp -p "$F" "$F.bak-x480"
  X480_F="$F" X480_P="$LIB/x-action-pacer.cjs" "$NODE_BIN" -e '
const fs=require("fs");const f=process.env.X480_F;let s=fs.readFileSync(f,"utf8");
const anch="const btn = await page.waitForSelector(\x27[data-testid$=\"-follow\"]\x27";
const snip="/* x480: 押す直前に間隔の決まりを通す（記録する）。絞り込みで落ちた相手は数えない。空かなければ押さずに終わる */ { const _pr = await require("+JSON.stringify(process.env.X480_P)+").waitTake(\"follow\", 150 * 1000); if (!_pr.ok) { console.log(JSON.stringify({ ok: false, status: \"paced\", reason: _pr.reason })); process.exit(0); } }\n    ";
s=s.replace(anch, snip+anch);fs.writeFileSync(f,s)'
  if "$NODE_BIN" --check "$F" 2>/dev/null && grep -q 'x480: 押す直前に' "$F"; then echo "入れた: $(grep -n 'x480: 押す直前に' "$F" | cut -c1-80)"; else cp -p "$F.bak-x480" "$F"; echo "**入れられない／構文が壊れた → 元に戻した**"; fi
else echo "**押す箇所が 1 つに決まらない。触らない**"; fi
echo '```'
echo; echo "## ④ badge-followback.js の押す前に間隔待ち"; echo '```'
F="$S/badge-followback.js"
if grep -q 'x480: 押す前に' "$F" 2>/dev/null; then echo "もう入っている"
elif [ "$(grep -c 'if (await clickFollow(page)) {' "$F" | head -1)" = "1" ]; then
  cp -p "$F" "$F.bak-x480"
  X480_F="$F" X480_P="$LIB/x-action-pacer.cjs" "$NODE_BIN" -e '
const fs=require("fs");const f=process.env.X480_F;let s=fs.readFileSync(f,"utf8");
const snip="/* x480: 押す前に間隔の決まりを通す（記録する）。空かなければこの回はここで止める */ { const _pr = await require("+JSON.stringify(process.env.X480_P)+").waitTake(\"follow\", 20 * 60 * 1000); if (!_pr.ok) { log(\"間隔待ちで止める: \" + _pr.reason); break; } }\n        ";
s=s.replace("if (await clickFollow(page)) {", snip+"if (await clickFollow(page)) {");fs.writeFileSync(f,s)'
  if "$NODE_BIN" --check "$F" 2>/dev/null; then echo "入れた: $(grep -n 'x480: 押す前に' "$F" | cut -c1-120)"; else cp -p "$F.bak-x480" "$F"; echo "**構文が壊れた → 元に戻した**"; fi
else echo "**押す箇所が 1 つに決まらない。触らない**"; fi
echo '```'
echo; echo "## ⑤ 1 回あたりの上限・起動のばらつき（plist）"
for spec in "badge-followback FOLLOWBACK_MAX_PER_RUN=2" "competitor-follower-follow COMPETITOR_FOLLOW_DAILY_CAP=2" "hashtag-follow HASHTAG_FOLLOW_DAILY_CAP=2" "comment-warmup REPLY_FOLLOW_DAILY_CAP=6" "follow-balance MIN_UNFOLLOW=2,MAX_UNFOLLOW=2" "mutual-prune MAX_UNFOLLOW=2,GRACE_DAYS=3"; do
  L="ai.openclaw.${spec%% *}"; KV="${spec#* }"; P="$LA/$L.plist"
  echo; echo "### $L"; echo '```'
  if [ ! -f "$P" ]; then echo "plist なし"; echo '```'; continue; fi
  if running "$L"; then echo "**いま走っている。触らない**（あとでやり直す）"; echo '```'; continue; fi
  cp -p "$P" "$P.bak-x480"
  for kv in $(echo "$KV" | tr ',' ' '); do setenv "$P" "${kv%%=*}" "${kv#*=}"; done
  if ! "$PB" -c "Print :ProgramArguments" "$P" 2>/dev/null | grep -q 'x-jitter.sh'; then
    "$PB" -c "Add :ProgramArguments:0 string 1500" "$P"; "$PB" -c "Add :ProgramArguments:0 string $JIT" "$P"; "$PB" -c "Add :ProgramArguments:0 string /bin/bash" "$P"
  fi
  if [ "$L" = "ai.openclaw.badge-followback" ]; then
    i=0; while "$PB" -c "Print :StartCalendarInterval:$i:Hour" "$P" >/dev/null 2>&1; do
      [ "$("$PB" -c "Print :StartCalendarInterval:$i:Hour" "$P")" = "0" ] && "$PB" -c "Set :StartCalendarInterval:$i:Hour 21" "$P" && echo "0:50 → 21:50 に移した"
      i=$((i+1)); done
  fi
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x480" "$P"; echo "**plutil が通らない → 元に戻した**"; echo '```'; continue; fi
  launchctl bootout "gui/$UIDN/$L" 2>/dev/null; BS="$(launchctl bootstrap "gui/$UIDN" "$P" 2>&1)"; echo "bootstrap rc=$? $(printf '%s' "$BS" | cut -c1-80)"
  PR="$(launchctl print "gui/$UIDN/$L" 2>/dev/null)"
  if [ -z "$PR" ]; then echo "**載っていない → 元の plist で載せ直す**"; cp -p "$P.bak-x480" "$P"; launchctl bootstrap "gui/$UIDN" "$P" 2>&1 | head -1
  else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR" | grep -aE 'x-jitter|MAX_PER_RUN|DAILY_CAP|MIN_UNFOLLOW|MAX_UNFOLLOW|GRACE_DAYS' | sed 's/^[[:space:]]*/  /' | head -8; fi
  echo '```'
done
} > "$OUT" 2>&1
grep -E '置いた|変えた|入れた|載っている|戻した|走っている' "$OUT" | head -6 | cut -c1-120
exit 0
