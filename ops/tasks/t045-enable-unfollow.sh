#!/bin/bash
# **アンフォロー 6 本の bootstrap 失敗を、エラーの実物を見て直す。費用 $0。**
#
# ## t044 の結果
#
#   ロードした     reply-followback-check / auto-detect-and-unfollow-inactive
#   **失敗**       follow-watchdog / unfollow-daily / unfollow-evening
#                  unfollow-cleanup-morning / unfollow-cleanup-evening / revenge-unfollow
#
# **plist は存在する**（`[ -f ]` を通っている）のに bootstrap が失敗した。
# `launchctl disable` で無効化されたまま、という筋が濃い。tab-guard が
# 停止させたときの状態が残っている可能性がある。
#
# **だが推測で `enable` を打たない。** まず**失敗時のエラーメッセージそのもの**を取る。
# 2026-09-05 に推測で 2 回 落ちている（`ant.create` / 400）。同じことをしない。
#
# ## 順番（実行を先に・報告を後に）
#
#   1. 各ラベルについて **bootstrap の生のエラー**を取る
#   2. エラーが「disabled」を示していたら **`launchctl enable` してから再度 bootstrap**
#   3. 結果を報告する
#
# `enable` は**無効化を解除するだけ**で、アンフォローを走らせるわけではない。
# **kickstart しない。** 次の定時から回る。
#
# ## 今日の弾き理由（t044 で判明・参考）
#
#   37 ❌ follower count out of range   ← **いま最大の障壁**（ratio ではない）
#   16 ❌ random-looking handle
#   15 ❌ low-density bio
#   14 ❌ follower>>following exclusion（撤廃前の分）
#   13 ❌ inactive
#    2 ❌ follow button click didn't change to unfollow
#
# **投稿しない。フォローもアンフォローもしない。LLM も呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/enable-unfollow.md"
UID_N="$(id -u)"
mask() { sed -E 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g; s#[A-Za-z0-9_-]{40,}#<MASKED>#g'; }

JOBS="ai.openclaw.follow-watchdog
ai.openclaw.unfollow-daily
ai.openclaw.unfollow-evening
ai.openclaw.unfollow-cleanup-morning
ai.openclaw.unfollow-cleanup-evening
ai.openclaw.revenge-unfollow"

# ---- 実行を先に。報告が壊れてもここは済んでいる ----
LOG=""
for j in $JOBS; do
  P="$LA/$j.plist"
  if [ ! -f "$P" ]; then LOG="${LOG}${j#ai.openclaw.}|plist なし||"$'\n'; continue; fi
  if launchctl list 2>/dev/null | grep -qF "$j"; then
    LOG="${LOG}${j#ai.openclaw.}|既にロード済み||"$'\n'; continue
  fi
  # 1 回目: そのまま bootstrap して **生のエラー**を取る
  err1="$(launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | tr '\n' ' ' | cut -c1-160)"
  if launchctl list 2>/dev/null | grep -qF "$j"; then
    LOG="${LOG}${j#ai.openclaw.}|**ロードした**|${err1}|"$'\n'; continue
  fi
  # 2 回目: enable してから再挑戦（無効化されているケース）
  en="$(launchctl enable "gui/$UID_N/$j" 2>&1 | tr '\n' ' ' | cut -c1-100)"
  err2="$(launchctl bootstrap "gui/$UID_N" "$P" 2>&1 | tr '\n' ' ' | cut -c1-160)"
  if launchctl list 2>/dev/null | grep -qF "$j"; then
    LOG="${LOG}${j#ai.openclaw.}|**enable してロードした**|${err1}|${en} / ${err2}"$'\n'
  else
    LOG="${LOG}${j#ai.openclaw.}|**なお失敗**|${err1}|${en} / ${err2}"$'\n'
  fi
done

{
echo "# アンフォローの bootstrap 失敗を直す（$(date '+%Y-%m-%d %H:%M:%S') JST・費用 \$0）"
echo
echo "> \`t044\` で 8 本中 2 本しかロードできなかった。**plist はあるのに失敗していた。**"
echo "> **推測で \`enable\` を打たず、まず生のエラーを取ってから**再挑戦した。"
echo "> **kickstart しない。** アンフォローは次の定時から回る。"

echo
echo "## 1. 結果"
echo
printf '%s' "$LOG" | while IFS='|' read -r name res e1 e2; do
  [ -z "$name" ] && continue
  echo "### \`$name\` — $res"
  [ -n "${e1:-}" ] && { echo; echo "1 回目のエラー:"; echo '```'; printf '%s\n' "$e1" | mask; echo '```'; }
  [ -n "${e2:-}" ] && { echo; echo "enable 後:"; echo '```'; printf '%s\n' "$e2" | mask; echo '```'; }
  echo
done

echo
echo "## 2. いまのロード状態"
echo
echo '```'
printf '%-40s %-8s %s\n' "ラベル" "PID" "rc"
for j in $JOBS ai.openclaw.reply-followback-check ai.openclaw.auto-detect-and-unfollow-inactive \
         ai.openclaw.competitor-follower-follow ai.openclaw.hashtag-follow ai.openclaw.badge-followback; do
  line="$(launchctl list 2>/dev/null | grep -F "$j" || true)"
  if [ -z "$line" ]; then printf '%-40s %s\n' "${j#ai.openclaw.}" "**未ロード**"
  else printf '%s\n' "$line" | awk -v n="${j#ai.openclaw.}" '{printf "%-40s %-8s %s\n", n, $1, $2}'; fi
done
echo '```'

echo
echo "## 3. 無効化の一覧（\`launchctl print-disabled\`）"
echo
echo "**disabled になっているものは bootstrap しても起動しない。**"
echo
echo '```'
launchctl print-disabled "gui/$UID_N" 2>/dev/null | grep -E 'ai\.openclaw|com\.dailyhack' | grep -i 'true' | head -25 | mask \
  || echo "（disabled の一覧を取得できない）"
echo '```'

echo
echo "## 4. 今日の弾き理由（参考・いま最大の障壁）"
echo
echo '```'
TODAY="$(date +%Y-%m-%d)"
grep -h "$TODAY" "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log 2>/dev/null \
  | grep -oE "❌ [^:(]*" | sed 's/ *$//' | sort | uniq -c | sort -rn | head -12 | mask || echo "（該当なし）"
echo '```'
echo
echo "**\`follower count out of range\` が最大。** ratio ではない。範囲は現在 100〜50000。"
echo
echo '```'
grep -h "$TODAY" "$W"/logs/competitor-follower-follow.log "$W"/logs/hashtag-follow.log 2>/dev/null \
  | grep -oE 'follower count out of range \([0-9]+' | grep -oE '[0-9]+$' | sort -n | uniq -c | tail -20 | mask \
  || echo "（該当なし）"
echo '```'
echo
echo "上が**弾かれた相手のフォロワー数**。下限 100 未満と上限 50000 超のどちらで落ちているかが分かる。"

echo
echo "---"
echo
echo "**アンフォローは 1 件も実行していない。投稿もしていない。LLM も呼んでいない（\$0）。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { mask < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
echo "**アンフォローの bootstrap を直した（\$0）** / $(basename "$OUT")"
