#!/bin/bash
# OpenClaw 最小セットのロード
#
#   bash scripts/openclaw-load-minimal.sh
#
# 画像添付と 👍 検知が通る最小限のジョブだけを launchd に戻す。
# X への自動投稿・フォロー操作のジョブは意図的に含めない。
#
# 前提（2026-08-11 に scripts/openclaw-audit-jobs.sh で確認済み）:
#   この5つに Anthropic / OpenAI の資格情報は無く、Console 課金を発生させない。
#
# 順序の強制:
#   MUST rule が欠けたまま本体を起動すると、確認せずに「完了しました」と
#   報告する状態で動き出す。それが 8/10 の虚偽報告の原因だったため、
#   ルールが戻っていなければロードせずに終了する。

set -uo pipefail

LA="$HOME/Library/LaunchAgents"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
# ルールの置き場所は memory/ ではなく workspace 直下の CLAUDE.md だった
# （2026-08-11 に実機で確認）。memory/ だけを見ていたため判定の土台が誤っていた。
RULE_FILES="$WORKSPACE/CLAUDE.md $WORKSPACE/memory"
KEY_RULE="feedback_verify_external_state_before_claiming"
JOBS="gateway node poll-approvals slack-watchdog import-manual-image"

uid="$(id -u)"

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mNG\033[0m   %s\n' "$1"; }

bold "0. MUST rule の確認（ここが通らなければロードしない）"

found_in=""
for target in $RULE_FILES; do
  [ -e "$target" ] || continue
  if grep -rql "$KEY_RULE" "$target" 2>/dev/null; then
    found_in="$target"
    break
  fi
done

if [ -n "$found_in" ]; then
  ok "$KEY_RULE は存在する（$found_in）"
else
  bad "$KEY_RULE が見つからない"
  for target in $RULE_FILES; do
    if [ -e "$target" ]; then
      echo "       探した: $target"
    else
      echo "       探した: $target（存在しない）"
    fi
  done
  echo ""
  echo "  この状態で本体を起動すると、外部の状態を確認せずに「完了しました」と"
  echo "  報告する挙動が再発する。先に復元すること。"
  echo ""
  echo "    bash scripts/openclaw-recover.sh"
  exit 1
fi

bold "1. ロード"

loaded=""
failed=""
for job in $JOBS; do
  label="ai.openclaw.$job"
  plist="$LA/$label.plist"

  if [ ! -f "$plist" ]; then
    bad "$label: plist が無い"
    failed="$failed $job"
    continue
  fi

  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "$label"; then
    ok "$label: 既にロード済み"
    loaded="$loaded $job"
    continue
  fi

  out="$(launchctl bootstrap "gui/$uid" "$plist" 2>&1)"
  if [ -z "$out" ]; then
    ok "$label: ロードした"
    loaded="$loaded $job"
  else
    bad "$label: $out"
    failed="$failed $job"
  fi
done

bold "2. 確認"

echo "  現在ロードされているもの:"
launchctl list 2>/dev/null | grep -iE 'openclaw|dailyhack' | sed 's/^/    /'

bold "結果"

[ -n "$loaded" ] && echo "  ロード済み:$loaded"
if [ -n "$failed" ]; then
  echo "  失敗:$failed"
  echo ""
  echo "  失敗が残っているため成功として扱わない。"
  exit 1
fi

echo ""
echo "  poll-approvals が 60 秒間隔で 👍 を拾うようになる。"
echo "  実際に動いているかはログの更新で確認する（自己申告を信用しない）。"
echo ""
echo "    tail -f ~/.openclaw/workspace/logs/poll-approvals.log"
