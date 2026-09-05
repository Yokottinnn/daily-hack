#!/bin/bash
# **アンフォローとフォロバ計測を戻す。費用 $0。**
#
# ## なぜ要るのか
#
# 利用者の前提: 「**フォローされなかったらすぐにアンフォローする前提であれば良い**」
#
# だがその前提が**今は成立していない。** `t036` の実測でアンフォロー系は全部 停止:
#
#   停止  unfollow-daily / unfollow-evening
#   停止  unfollow-cleanup-morning / unfollow-cleanup-evening
#   停止  auto-detect-and-unfollow-inactive / revenge-unfollow
#   停止  reply-followback-check   ← **フォロバ判定そのもの**
#   停止  follow-watchdog
#
# ratio を外してフォローだけ増やすと、**X のフォロー上限に当たってフォロー自体が止まる。**
#
# ## もう 1 つ: コールドフォローのフォロバ率を 1 度も測っていない
#
#   reply-followers.json  286 件・フォロバ 100%   ← これは「返信した相手」で別物
#   followed.json           2 件                 ← コールドフォローの記録がほぼ空
#
# `reply-followback-check` が止まっているので記録が付いていない。
# **ratio を 0.15 にするか 0 にするかを、データ無しで議論している。**
#
# ## やること
#
#   1. 各ジョブの plist（**実行間隔**）と、スクリプトの**上限の定数**を出す（$0・読むだけ）
#   2. 8 本を `launchctl bootstrap` で**ロードする**
#   3. **計測用の `reply-followback-check` だけ kickstart する**
#   4. ロード状態と最後の終了コードを出す
#
# ## アンフォローは kickstart しない
#
# **手で一斉起動すると、まとまった数が一度に外れる。** それ自体がスパム的な挙動になり、
# 急ぐほど制限を食らって遅くなる。**定時で回れば十分。**
#
# 何をやる設定になっているかは 1 で出すので、次の定時で何が起きるかは事前に分かる。
#
# **投稿しない。フォローもアンフォローもこのタスクではしない。LLM も呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-unfollow.md"
UID_N="$(id -u)"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }
hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }

JOBS="ai.openclaw.reply-followback-check
ai.openclaw.follow-watchdog
ai.openclaw.unfollow-daily
ai.openclaw.unfollow-evening
ai.openclaw.unfollow-cleanup-morning
ai.openclaw.unfollow-cleanup-evening
ai.openclaw.auto-detect-and-unfollow-inactive
ai.openclaw.revenge-unfollow"

{
echo "# アンフォローとフォロバ計測を戻す（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> 利用者の前提「フォローされなかったらすぐアンフォロー」が**成立していなかった。**"
echo "> アンフォロー系は 8 本すべて停止中だった。**ratio を外すならここが要る。**"
echo "> **アンフォローは kickstart しない**（一斉に外れるとそれ自体がスパム的）。"
echo "> 計測用の \`reply-followback-check\` だけ即実行する。"

echo
echo "## 1. 何をやる設定になっているか（読むだけ）"
for j in $JOBS; do
  P="$LA/$j.plist"
  echo
  echo "### \`${j#ai.openclaw.}\`"
  if [ ! -f "$P" ]; then echo; echo "- **plist が無い**"; continue; fi
  # 実行間隔
  iv="$(/usr/libexec/PlistBuddy -c "Print :StartInterval" "$P" 2>/dev/null || true)"
  if [ -n "$iv" ]; then
    echo "- 間隔: ${iv} 秒（$((iv/60)) 分）"
  else
    tm="$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval" "$P" 2>/dev/null | grep -oE '(Hour|Minute) = [0-9]+' | paste -sd' ' - || true)"
    echo "- 時刻指定: ${tm:-（不明）}"
  fi
  # 環境変数（上限）
  env_out="$(/usr/libexec/PlistBuddy -c "Print :EnvironmentVariables" "$P" 2>/dev/null | grep -vE '^\s*(Dict|\}|PATH)' | tr -d ' ' | paste -sd' ' - || true)"
  [ -n "$env_out" ] && echo "- 環境変数: \`$(printf '%s' "$env_out" | mask)\`"
  # 叩いているスクリプトの上限定数
  S="$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments" "$P" 2>/dev/null | grep -oE '/[^ ]+\.(js|cjs|sh)' | head -1)"
  if [ -n "$S" ] && [ -f "$S" ]; then
    echo "- スクリプト: \`$(basename "$S")\`"
    echo '```javascript'
    grep -nE '(CAP|LIMIT|MAX|MIN|DAYS|HOURS|GRACE|THRESHOLD)[A-Z_]*\s*=|process\.env\.[A-Z_]+' "$S" 2>/dev/null \
      | head -12 | cut -c1-160 | mask
    echo '```'
  else
    echo "- スクリプトを特定できない"
  fi
done

echo
echo "## 2. ロードする"
echo
echo '```'
for j in $JOBS; do
  P="$LA/$j.plist"
  if [ ! -f "$P" ]; then printf '%-42s %s\n' "${j#ai.openclaw.}" "plist なし"; continue; fi
  if launchctl list 2>/dev/null | grep -qF "$j"; then
    printf '%-42s %s\n' "${j#ai.openclaw.}" "既にロード済み"
  elif launchctl bootstrap "gui/$UID_N" "$P" 2>/dev/null; then
    printf '%-42s %s\n' "${j#ai.openclaw.}" "ロードした"
  else
    printf '%-42s %s\n' "${j#ai.openclaw.}" "**bootstrap に失敗**"
  fi
done
echo '```'

echo
echo "## 3. 計測だけ即実行（\`reply-followback-check\`）"
echo
echo "**アンフォローは起動しない。** これはフォロバの有無を記録するだけ。"
echo
echo '```'
launchctl kickstart -k "gui/$UID_N/ai.openclaw.reply-followback-check" >/dev/null 2>&1 \
  && echo "reply-followback-check: kickstart した" \
  || echo "reply-followback-check: **kickstart に失敗**"
echo '```'
echo
sleep 45
for f in "$W"/logs/*followback*.log "$W"/logs/*follow-watchdog*.log; do
  [ -f "$f" ] || continue
  echo "### \`$(basename "$f")\` — 最終更新 **$(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)**"
  echo
  echo '```'
  tail -12 "$f" 2>/dev/null | cut -c1-170 | hide | mask
  echo '```'
  echo
done

echo
echo "## 4. ロード状態と最後の終了コード"
echo
echo '```'
printf '%-42s %-8s %s\n' "ラベル" "PID" "rc"
for j in $JOBS ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow ai.openclaw.badge-followback; do
  line="$(launchctl list 2>/dev/null | grep -F "$j" || true)"
  if [ -z "$line" ]; then printf '%-42s %s\n' "${j#ai.openclaw.}" "**未ロード**"
  else printf '%s\n' "$line" | awk -v j="${j#ai.openclaw.}" '{printf "%-42s %-8s %s\n", j, $1, $2}'; fi
done
echo '```'

echo
echo "## 5. フォロー／アンフォローの当日実績"
echo
echo '```'
TODAY="$(date +%Y-%m-%d)"
for f in "$W"/data/reply-followers.json "$W"/data/followed.json \
         "$W"/data/unfollow-cleanup-state.json "$W"/data/badge-followback-state.json; do
  [ -f "$f" ] || continue
  echo "$(basename "$f"): 今日 $(grep -o "\"$TODAY" "$f" 2>/dev/null | wc -l | tr -d ' ') 件 / 更新 $(stat -f '%Sm' -t '%m-%d %H:%M' "$f" 2>/dev/null)"
done
echo '```'

echo
echo "---"
echo
echo "**アンフォローは 1 件も実行していない**（ロードしただけ。次の定時から回る）。"
echo "**投稿していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**アンフォローと計測を戻した（\$0）** / $(basename "$OUT")"
