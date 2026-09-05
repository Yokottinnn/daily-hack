#!/bin/bash
# **アンフォローとフォロバ計測を戻す（t043 のやり直し）。費用 $0。**
#
# ## t043 が落ちた
#
#   line 77: File: unbound variable
#
# plist を読む部分（**報告用**）で落ち、その下にあった **bootstrap まで届かなかった。**
# つまり**アンフォローは 1 本もロードされていない。**
#
# **設計ミス。報告を先に書き、実行を後ろに置いていた。**
# 報告のバグで実行が止まるのは順番が逆。**今回は実行を先に置く。**
#
# ## t042 の結果（こちらは成功）
#
#   ratio で弾いた件数: 0        ← 完全に外れた
#   今日のフォロー実績: 8 件      （今朝 1 → 5 → 8）
#   competitor 09:54:18 ✅
#
# 新しく見えた問題:
#
#   2 ❌ follow button click didn't change to unfollow
#
# これはフィルタではなく**フォロー操作そのものの失敗**。X のレート制限か UI 変化。
# 件数を増やすほど効くので、内訳に出す。
#
# ## 順番
#
#   1. **まず 8 本をロードする**（ここが本題）
#   2. 計測用の `reply-followback-check` だけ kickstart
#   3. そのあとで状態を報告する（**報告が壊れても 1 と 2 は済んでいる**）
#
# **アンフォローは kickstart しない。** 一斉に外れるとそれ自体がスパム的な挙動になる。
#
# **投稿しない。LLM も呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/restore-unfollow-v2.md"
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

# ============================================================
# 1. まず実行する。**報告より先。** ここが落ちなければ目的は達する
# ============================================================
RESULT=""
for j in $JOBS; do
  P="$LA/$j.plist"
  if [ ! -f "$P" ]; then
    RESULT="${RESULT}${j#ai.openclaw.}|plist なし"$'\n'
    continue
  fi
  if launchctl list 2>/dev/null | grep -qF "$j"; then
    RESULT="${RESULT}${j#ai.openclaw.}|既にロード済み"$'\n'
  elif launchctl bootstrap "gui/$UID_N" "$P" >/dev/null 2>&1; then
    RESULT="${RESULT}${j#ai.openclaw.}|**ロードした**"$'\n'
  else
    RESULT="${RESULT}${j#ai.openclaw.}|bootstrap に失敗"$'\n'
  fi
done

# 計測だけ即実行（アンフォローは起動しない）
KICK="失敗"
launchctl kickstart -k "gui/$UID_N/ai.openclaw.reply-followback-check" >/dev/null 2>&1 && KICK="kickstart した"

# ============================================================
# 2. ここから報告。**落ちても上は済んでいる**
# ============================================================
{
echo "# アンフォローと計測を戻した（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> \`t043\` は plist を読む部分（**報告用**）で落ち、その下の bootstrap まで届かなかった。"
echo "> **報告を先に書き、実行を後ろに置いていた設計ミス。** 今回は実行を先に置いた。"
echo "> **アンフォローは kickstart していない**（一斉に外れるとそれ自体がスパム的）。"

echo
echo "## 1. ロード結果（**実行済み**）"
echo
echo '```'
printf '%s' "$RESULT" | while IFS='|' read -r a b; do
  [ -n "$a" ] && printf '%-40s %s\n' "$a" "$b"
done
echo '```'
echo
echo "- \`reply-followback-check\`: **${KICK}**"

echo
echo "## 2. いまのロード状態と最後の終了コード"
echo
echo '```'
printf '%-40s %-8s %s\n' "ラベル" "PID" "rc"
for j in $JOBS ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow ai.openclaw.badge-followback; do
  line="$(launchctl list 2>/dev/null | grep -F "$j" || true)"
  if [ -z "$line" ]; then
    printf '%-40s %s\n' "${j#ai.openclaw.}" "**未ロード**"
  else
    printf '%s\n' "$line" | awk -v n="${j#ai.openclaw.}" '{printf "%-40s %-8s %s\n", n, $1, $2}'
  fi
done
echo '```'

echo
echo "## 3. 実行間隔（次にいつ回るか）"
echo
echo '```'
for j in $JOBS; do
  P="$LA/$j.plist"
  [ -f "$P" ] || { printf '%-40s %s\n' "${j#ai.openclaw.}" "plist なし"; continue; }
  sched="$(plutil -extract StartCalendarInterval json -o - "$P" 2>/dev/null | tr -d '\n' | cut -c1-90 || true)"
  [ -z "${sched:-}" ] && sched="$(plutil -extract StartInterval raw -o - "$P" 2>/dev/null || true)"
  printf '%-40s %s\n' "${j#ai.openclaw.}" "${sched:-（不明）}"
done
echo '```'

echo
echo "## 4. アンフォローの上限（次の定時で何が起きるか）"
echo
echo '```'
for j in $JOBS; do
  P="$LA/$j.plist"
  [ -f "$P" ] || continue
  S="$(plutil -extract ProgramArguments json -o - "$P" 2>/dev/null | grep -oE '/[^" ]+\.(js|cjs|sh)' | head -1 || true)"
  [ -n "${S:-}" ] && [ -f "$S" ] || continue
  echo "── $(basename "$S")"
  grep -nE '(CAP|LIMIT|MAX|MIN|DAYS|GRACE)[A-Z_]*[ ]*=|process\.env\.[A-Z_]+' "$S" 2>/dev/null \
    | head -8 | cut -c1-150 | sed 's/^/    /' | mask || echo "    （定数が見つからない）"
done
echo '```'

echo
echo "## 5. 当日の実績"
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
echo "## 6. フォロー操作そのものの失敗（\`t042\` で新たに出た）"
echo
echo "\`follow button click didn't change to unfollow\` はフィルタではなく**操作の失敗**。"
echo "X のレート制限か UI 変化の可能性がある。**件数を増やすほど効いてくる。**"
echo
echo '```'
grep -h "$TODAY" "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log 2>/dev/null \
  | grep -oE "❌ [^:(]*" | sed 's/ *$//' | sort | uniq -c | sort -rn | head -12 | mask || echo "（該当なし）"
echo '```'

echo
echo "---"
echo
echo "**アンフォローは 1 件も実行していない**（ロードしただけ。次の定時から回る）。"
echo "**投稿していない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { hide < "$OUT" | mask > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**アンフォローと計測を戻した（\$0）** / $(basename "$OUT")"
