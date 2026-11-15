#!/bin/bash
# x500（2026-11-15・$0）: 1 日の上限を外し、「人の 1 日の動き方」で散らす。押す係（順番待ち）を本番にする。
# 利用者「ランダムに一律に実行しないというルールを絶対に守った上で、1日の上限は無くして欲しい。…
#         絶対にスパムやAIだと思われないようにするための対策を徹底的にもっと工夫して取ってほしい。」
#  ① ops/lib/x-action-pacer.cjs を置き直す（1 日の上限なし・日ごとに変わる起きている時間・休憩・調子・まとまり・偏った間隔・優先つきの順番待ち）
#  ② ジョブごとの件数の頭打ち（x480 で 2 件にしたもの）を、暴走よけの値に戻す。実際の速さは ① が決める
#  ③ 押す係の試し運転（com.dailyhack.x-action-dispatcher・DRY_RUN）を止める（順番待ちは ① に入った）
# LLM を呼ばない。走っている最中のジョブは触らない（次の周回でやり直す）。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
W="$HOME/.openclaw/workspace"; LIB="$W/lib"; LA="$HOME/Library/LaunchAgents"
PB=/usr/libexec/PlistBuddy; UIDN="$(id -u)"; STAMP="$(date +%Y%m%d-%H%M%S)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x500-pacer-no-daily-cap-human-rhythm.md"
setenv() { local P="$1" K="$2" V="$3"
  "$PB" -c "Print :EnvironmentVariables" "$P" >/dev/null 2>&1 || "$PB" -c "Add :EnvironmentVariables dict" "$P"
  if "$PB" -c "Print :EnvironmentVariables:$K" "$P" >/dev/null 2>&1; then "$PB" -c "Set :EnvironmentVariables:$K $V" "$P"; else "$PB" -c "Add :EnvironmentVariables:$K string $V" "$P"; fi; }
{
echo "# 1 日の上限を外し、人の動き方で散らす（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo; echo "## ① 間隔の決まりを置き直す"; echo '```'
git -C "$REPO" fetch -q origin main 2>/dev/null
TMP="$LIB/.x500-x-action-pacer.cjs"; PLACED=0
if git -C "$REPO" show "origin/main:ops/lib/x-action-pacer.cjs" > "$TMP" 2>/dev/null && [ -s "$TMP" ] && "$NODE_BIN" --check "$TMP" 2>/dev/null && grep -q 'function dayPlan' "$TMP"; then
  [ -f "$LIB/x-action-pacer.cjs" ] && cp -p "$LIB/x-action-pacer.cjs" "$LIB/x-action-pacer.cjs.bak.$STAMP"
  mv "$TMP" "$LIB/x-action-pacer.cjs"; PLACED=1
  echo "置いた: $LIB/x-action-pacer.cjs（$(wc -c < "$LIB/x-action-pacer.cjs" | tr -d ' ') bytes・元は .bak.$STAMP）"
  "$NODE_BIN" "$LIB/x-action-pacer.cjs" status 2>&1
else
  rm -f "$TMP"; echo "**取れない／壊れている。置かない（いまのまま）**"
fi
echo '```'
if [ "$PLACED" != 1 ]; then echo "**① が置けなかったので ② ③ はしない**（頭打ちだけ外すと速くなりすぎる）"; exit 0; fi

echo; echo "## ② ジョブごとの頭打ちを暴走よけの値に"
for spec in "badge-followback FOLLOWBACK_MAX_PER_RUN=25" "competitor-follower-follow COMPETITOR_FOLLOW_DAILY_CAP=20" "hashtag-follow HASHTAG_FOLLOW_DAILY_CAP=20" "comment-warmup REPLY_FOLLOW_DAILY_CAP=30" "follow-balance MAX_UNFOLLOW=20" "mutual-prune MAX_UNFOLLOW=8"; do
  name="${spec%% *}"; kvs="${spec#* }"; LABEL="ai.openclaw.$name"; P="$LA/$LABEL.plist"
  echo; echo "### $name"; echo '```'
  if [ ! -f "$P" ]; then echo "plist が無い: $P"; echo '```'; continue; fi
  ST="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null | awk -F'= ' '/^\tstate =/{print $2; exit}')"
  if [ "$ST" = "running" ]; then echo "**いま走っている。触らない**（次の周回でやり直す）"; echo '```'; continue; fi
  cp -p "$P" "$P.bak-x500"
  IFS=, read -ra KV <<< "$kvs"
  for kv in "${KV[@]}"; do echo "変える前 ${kv%%=*}: $("$PB" -c "Print :EnvironmentVariables:${kv%%=*}" "$P" 2>/dev/null || echo 未設定)"; setenv "$P" "${kv%%=*}" "${kv#*=}"; done
  if ! plutil -lint "$P" >/dev/null 2>&1; then cp -p "$P.bak-x500" "$P"; echo "**plutil が通らない。元に戻した**"; echo '```'; continue; fi
  launchctl bootout "gui/$UIDN/$LABEL" 2>/dev/null
  BS="$(launchctl bootstrap "gui/$UIDN" "$P" 2>&1)"; echo "bootstrap rc=$? $(printf '%s' "$BS" | cut -c1-80)"
  PR="$(launchctl print "gui/$UIDN/$LABEL" 2>/dev/null)"
  if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← launchd が持っている値:"; printf '%s\n' "$PR" | grep -aE 'MAX_PER_RUN|DAILY_CAP|MIN_UNFOLLOW|MAX_UNFOLLOW' | sed 's/^[[:space:]]*/  /' | head -4; fi
  echo '```'
done

echo; echo "## ③ 押す係の試し運転を止める"; echo '```'
L="com.dailyhack.x-action-dispatcher"; P="$LA/$L.plist"
launchctl bootout "gui/$UIDN/$L" 2>/dev/null; echo "bootout rc=$?"
[ -f "$P" ] && mv "$P" "$P.disabled" && echo "plist を .disabled にした"
if launchctl print "gui/$UIDN/$L" >/dev/null 2>&1; then echo "**まだ載っている**"; else echo "載っていない（止まった）"; fi
echo "試し運転の記録の行数: $(wc -l < "$W/data/x-action-dispatcher-dry.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"
echo '```'
echo; echo "**LLM 不使用（\$0）。**"
} > "$OUT" 2>&1
grep -E '置いた|載っている ←|走っている|載っていない|取れない|止まった' "$OUT" | head -8 | cut -c1-140
exit 0
