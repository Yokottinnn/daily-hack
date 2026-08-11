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

# MUST rule の実体は Claude Code のプロジェクトメモリにある。
# ~/.openclaw/workspace/memory/ でも workspace/CLAUDE.md でもない
# （daily-must-rule-review.js の MEMORY_DIR がこの場所を指している）。
# 場所を取り違えると「1件も無いのに全件ありと報告する」逆も起きる。
# 同じ誤判定は過去に review スクリプト自身でも発生している。
RULE_DIR="${OPENCLAW_MEMORY_DIR:-$HOME/.claude/projects/-Users-ny--openclaw-workspace/memory}"

KEY_RULE="feedback_verify_external_state_before_claiming"

# ミラー（SHARED/MEMORY-MUST-MIRROR.md）に載っている絶対遵守ルール。
MUST_RULES="feedback_always_buttons
feedback_no_permission_prompts
feedback_post_safety_3_layers
feedback_verify_external_state_before_claiming
feedback_post_creation_must_coordinate_with_blog_terminal
feedback_qt_must_have_external_link
feedback_event_posts_need_4_images
feedback_dm_phishing_security_absolute
feedback_openclaw_listener_thread_context
feedback_notification_requires_solution
feedback_auto_task_title_and_deadline
feedback_login_mode_no_chrome_touch"

JOBS="gateway node poll-approvals slack-watchdog import-manual-image"

uid="$(id -u)"

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
bad()  { printf '  \033[31mNG\033[0m   %s\n' "$1"; }

bold "0. MUST rule の確認（ここが通らなければロードしない）"

if [ ! -d "$RULE_DIR" ]; then
  bad "メモリの置き場所が見つからない: $RULE_DIR"
  echo ""
  echo "  候補を探す:"
  find "$HOME/.claude/projects" -maxdepth 3 -type d -name memory 2>/dev/null | sed 's/^/    /'
  echo ""
  echo "  正しい場所は OPENCLAW_MEMORY_DIR で指定できる。"
  exit 1
fi

echo "  メモリ: $RULE_DIR"

missing=""
present_count=0
total=0
for slug in $MUST_RULES; do
  total=$((total + 1))
  if [ -f "$RULE_DIR/$slug.md" ]; then
    present_count=$((present_count + 1))
  else
    missing="$missing $slug"
  fi
done

echo "  残存: ${present_count}/${total}"
if [ -n "$missing" ]; then
  for slug in $missing; do echo "    欠落: $slug"; done
fi

if [ -f "$RULE_DIR/$KEY_RULE.md" ]; then
  ok "$KEY_RULE は存在する"
  [ -n "$missing" ] && bad "他の MUST rule が欠けている。ロードは続けるが復元すること"
else
  bad "$KEY_RULE が見つからない: $RULE_DIR/$KEY_RULE.md"
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
