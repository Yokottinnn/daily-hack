#!/bin/bash
# OpenClaw（home-mac）復旧スクリプト
#
#   bash scripts/openclaw-recover.sh
#
# docs/openclaw-recovery.md の手順1〜5を順に実行する。
#
# 設計方針:
#   - 上書きの前に必ずバックアップを取る（復元に失敗しても元に戻せる）
#   - 判断が要る箇所では推測せず、見つけた事実を出して止まる
#   - 最後に「復旧した」と言わない。外部から見える証拠だけを出す
#
# macOS 標準の bash 3.2 で動く範囲に留めている。

set -uo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
MEMORY_DIR="$WORKSPACE/memory"
LOG_DIR="$WORKSPACE/logs"
MIRROR="/Users/ny/projects/anta-baka-x/SHARED/MEMORY-MUST-MIRROR.md"
BACKUP_DIR="$HOME/.openclaw/recovery-backup-$(date +%Y%m%d-%H%M%S)"
# 消えると虚偽報告が再発する要のルール。復元後にこれを検査する。
KEY_RULE="feedback_verify_external_state_before_claiming"

uid="$(id -u)"
step_failed=""

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mNG\033[0m   %s\n' "$1"; step_failed="${step_failed}${1}
"; }

# ---------------------------------------------------------------- 1. 現状確認

bold "1. 現状確認"

if [ ! -d "$WORKSPACE" ]; then
  bad "ワークスペースが見つからない: $WORKSPACE"
  echo "     OPENCLAW_WORKSPACE を設定して再実行する"
  exit 1
fi
ok "ワークスペース: $WORKSPACE"

# ジョブ名は決め打ちにしない。記録では ai.openclaw.* だったが、実機には
# com.dailyhack.openclaw.* が入っていた（2026-08-11 に判明）。名前を固定すると
# 「全部 OK に見えるが実は何も触っていない」空振りになる。
JOBS="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -iE 'openclaw|dailyhack' | sort -u)"
if [ -z "$JOBS" ]; then
  JOBS="$(ls "$HOME/Library/LaunchAgents" 2>/dev/null | sed 's/\.plist$//' | grep -iE 'openclaw|dailyhack' | sort -u)"
  [ -n "$JOBS" ] && warn "launchctl に載っていないが plist は存在する（未ロードの可能性）"
fi

if [ -z "$JOBS" ]; then
  bad "openclaw / dailyhack に該当する launchd ジョブが 1 つも見つからない"
else
  echo "  対象ジョブ:"
  for job in $JOBS; do echo "    - $job"; done
fi

for job in $JOBS; do
  state="$(launchctl print "gui/$uid/$job" 2>/dev/null | grep -E '^\s*state = ' | head -1 | sed 's/.*= //')"
  exit_code="$(launchctl print "gui/$uid/$job" 2>/dev/null | grep -E 'last exit code' | head -1 | sed 's/.*= //')"
  if [ -z "$state" ]; then
    bad "$job が launchd に登録されていない"
  else
    printf '  %-34s state=%-12s last exit=%s\n' "$job" "$state" "${exit_code:-n/a}"
  fi
done

if [ -d "$LOG_DIR" ]; then
  newest="$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)"
  if [ -n "$newest" ]; then
    age_min=$(( ( $(date +%s) - $(stat -f %m "$newest") ) / 60 ))
    echo "  最新ログ: $(basename "$newest")（${age_min} 分前）"
    [ "$age_min" -gt 120 ] && warn "2時間以上更新が無い。プロセスが止まっている可能性が高い"
  fi
fi

# ------------------------------------------------- 2. MUST rule の復元（最優先）

bold "2. MUST rule の復元（最優先）"
echo "  ここを飛ばして再起動すると、確認せずに「完了しました」と報告する状態のまま動き出す。"

current_has_key=""
if [ -d "$MEMORY_DIR" ] && grep -rql "$KEY_RULE" "$MEMORY_DIR" 2>/dev/null; then
  current_has_key="yes"
  ok "$KEY_RULE は現在のメモリに存在する（復元は不要）"
fi

if [ -z "$current_has_key" ]; then
  warn "$KEY_RULE が現在のメモリに無い。復元元を探す"

  source_file=""
  if [ -f "$MIRROR" ] && grep -q "$KEY_RULE" "$MIRROR" 2>/dev/null; then
    source_file="$MIRROR"
    echo "  候補1（旧ミラー）: $MIRROR"
  else
    [ -f "$MIRROR" ] && warn "ミラーはあるが $KEY_RULE を含まない: $MIRROR"
  fi

  if [ -z "$source_file" ] && [ -d "$MEMORY_DIR/snapshots" ]; then
    for snap in $(ls -t "$MEMORY_DIR/snapshots" 2>/dev/null); do
      if grep -rql "$KEY_RULE" "$MEMORY_DIR/snapshots/$snap" 2>/dev/null; then
        source_file="$MEMORY_DIR/snapshots/$snap"
        echo "  候補2（スナップショット）: $source_file"
        break
      fi
    done
  fi

  if [ -z "$source_file" ] && [ -d "$WORKSPACE/.git" ]; then
    echo "  候補3（Git 履歴）: 次で該当コミットを探せる"
    echo "    cd $WORKSPACE && git log --oneline -S '$KEY_RULE' -- memory/ | head"
  fi

  if [ -z "$source_file" ]; then
    bad "復元元が見つからない。手動での復元が必要"
    echo "     docs/openclaw-recovery.md の手順2を参照する"
  else
    mkdir -p "$BACKUP_DIR"
    if [ -d "$MEMORY_DIR" ]; then
      cp -R "$MEMORY_DIR" "$BACKUP_DIR/memory-before-restore"
      ok "復元前の状態をバックアップした: $BACKUP_DIR/memory-before-restore"
    fi
    echo ""
    echo "  復元元: $source_file"
    echo "  含まれる MUST rule:"
    grep -oE '[a-z_]*(rule|must|feedback)[a-z_]*' "$source_file" 2>/dev/null | sort -u | sed 's/^/    - /'
    echo ""
    printf "  この内容でメモリを復元する [y/N]: "
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
      mkdir -p "$MEMORY_DIR"
      cp "$source_file" "$MEMORY_DIR/MUST-RULES-restored.md"
      if grep -q "$KEY_RULE" "$MEMORY_DIR/MUST-RULES-restored.md"; then
        ok "復元した: $MEMORY_DIR/MUST-RULES-restored.md"
        warn "OpenClaw がこのファイルを読み込む設定になっているか確認すること"
      else
        bad "復元したファイルに $KEY_RULE が含まれていない"
      fi
    else
      bad "復元を見送った。この状態で再起動しても虚偽報告は直らない"
    fi
  fi
fi

# -------------------------------------------- 3. スナップショットの世代を増やす

bold "3. スナップショットの世代"
echo "  今回復元できなかった直接の理由は、前日ぶん1世代しか保持していなかったこと。"

if [ -d "$MEMORY_DIR/snapshots" ]; then
  gen="$(ls "$MEMORY_DIR/snapshots" 2>/dev/null | wc -l | tr -d ' ')"
  echo "  現在の世代数: $gen"
  if [ "$gen" -lt 7 ]; then
    warn "7世代未満。消失に気づくのが1日遅れると全損する"
    echo "     OpenClaw 側の保持設定を 7 以上に変更する（このスクリプトからは変更しない）"
  else
    ok "7世代以上を保持している"
  fi
else
  warn "スナップショット置き場が無い: $MEMORY_DIR/snapshots"
fi

# ------------------------------------------- 4. spawnSync ETIMEDOUT の解消

bold "4. プロセスの整理と再起動"

procs="$(ps aux | grep -i openclaw | grep -v grep | grep -v openclaw-recover)"
if [ -n "$procs" ]; then
  count="$(echo "$procs" | wc -l | tr -d ' ')"
  echo "  稼働中のプロセス: ${count} 件"
  echo "$procs" | awk '{printf "    pid=%-7s %s\n", $2, $11}'
  [ "$count" -gt 2 ] && warn "多重起動の可能性。ETIMEDOUT の原因になりうる"
else
  echo "  稼働中の openclaw プロセスは無い"
fi

for job in $JOBS; do
  if launchctl kickstart -k "gui/$uid/$job" 2>/dev/null; then
    ok "再起動した: $job"
  else
    bad "再起動に失敗: $job"
  fi
done

# ------------------------------------------------------ 5. 外部からの生存確認

bold "5. 生存確認"
echo "  OpenClaw 自身の「復旧しました」という報告は信用しない。それが今回の問題だった。"
echo "  30秒待ってからログの更新を見る。"
sleep 30

alive=""
if [ -d "$LOG_DIR" ]; then
  newest="$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)"
  if [ -n "$newest" ]; then
    age_min=$(( ( $(date +%s) - $(stat -f %m "$newest") ) / 60 ))
    if [ "$age_min" -le 2 ]; then
      alive="yes"
      ok "ログが更新されている: $(basename "$newest")（${age_min} 分前）"
      tail -5 "$newest" | sed 's/^/    /'
    else
      bad "ログが更新されていない（最終更新 ${age_min} 分前）"
    fi
  else
    bad "ログファイルが見つからない: $LOG_DIR"
  fi
fi

# ------------------------------------------------------------------ まとめ

bold "結果"

if [ -n "$step_failed" ]; then
  echo "  未解決の項目:"
  printf '%s' "$step_failed" | sed 's/^/    - /'
  echo ""
  echo "  この状態では復旧とみなさない。docs/openclaw-recovery.md を見て個別に対処する。"
  exit 1
fi

if [ -z "$alive" ]; then
  echo "  プロセスの生存を確認できなかった。復旧とみなさない。"
  exit 1
fi

echo "  手順1〜5は完了した。ただし復旧の最終判断は Slack への実着信で行う。"
echo ""
echo "  次に確認すること:"
echo "    - fieldbeside の C0A5FKU7T5M に OpenClaw のメッセージが実際に届くか"
echo "    - 届いたら画像を Slack スレッドへ添付させる（リンクではなくファイル添付）"
echo "    - 👍 を得てから X へ投稿する（順序を逆にしない）"
[ -d "$BACKUP_DIR" ] && echo "" && echo "  復元前のバックアップ: $BACKUP_DIR"
