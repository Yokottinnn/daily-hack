#!/bin/bash
# OpenClaw ジョブの課金監査
#
#   bash scripts/openclaw-audit-jobs.sh              # 最小セットを監査
#   bash scripts/openclaw-audit-jobs.sh --all        # ai.openclaw.* を全部監査
#
# ロードする前に「そのジョブが API 課金を発生させるか」を調べる。
# CLAUDE.md 最上位ルール2（課金操作は着手前に確認）を守るための下調べであり、
# このスクリプト自体は読み取りしか行わない。ジョブのロードも実行もしない。

set -uo pipefail

LA="$HOME/Library/LaunchAgents"

# 画像添付と 👍 検知が通る最小限。X への自動投稿ジョブは意図的に含めない。
MINIMAL="gateway node poll-approvals slack-watchdog import-manual-image"

# 課金の痕跡。ここに当たれば「金がかかる可能性あり」として扱う。
BILLABLE_PAT='ANTHROPIC_API_KEY|CLAUDE_API_KEY|ANTHROPIC_AUTH_TOKEN|OPENAI_API_KEY|GEMINI_API_KEY|GOOGLE_API_KEY|api\.anthropic\.com|api\.openai\.com|generativelanguage\.googleapis\.com|anthropic\.messages|openai\.chat'

bold() { printf '\n\033[1m%s\033[0m\n' "$1"; }
hit()  { printf '  \033[31m課金あり\033[0m %s\n' "$1"; }
safe() { printf '  \033[32m痕跡なし\033[0m %s\n' "$1"; }
note() { printf '  \033[33m注意\033[0m    %s\n' "$1"; }

if [ "${1:-}" = "--all" ]; then
  TARGETS="$(ls "$LA" 2>/dev/null | grep '^ai\.openclaw\..*\.plist$' | sed 's/^ai\.openclaw\.//; s/\.plist$//')"
  bold "監査対象: ai.openclaw.* 全部"
else
  TARGETS="$MINIMAL"
  bold "監査対象: 最小セット"
fi

billable_jobs=""
missing_jobs=""
undetermined_jobs=""

for job in $TARGETS; do
  plist="$LA/ai.openclaw.$job.plist"
  bold "ai.openclaw.$job"

  if [ ! -f "$plist" ]; then
    note "plist が無い: $plist"
    missing_jobs="$missing_jobs $job"
    continue
  fi

  # ロード状態（既に動いているなら今さら止める話ではない）
  if launchctl list 2>/dev/null | awk '{print $3}' | grep -qx "ai.openclaw.$job"; then
    echo "  状態: ロード済み"
  else
    echo "  状態: 未ロード"
  fi

  # 実行間隔（頻度が高いほど費用が積み上がる）
  interval="$(plutil -p "$plist" 2>/dev/null | grep -E 'StartInterval' | head -1 | sed 's/.*=> //')"
  [ -n "$interval" ] && echo "  実行間隔: ${interval} 秒"
  plutil -p "$plist" 2>/dev/null | grep -q 'StartCalendarInterval' && echo "  実行間隔: カレンダー指定あり"

  # plist の EnvironmentVariables にキーが直接書かれていることがある。
  # ここを見ずにスクリプト本文だけ調べて「痕跡なし」と報告していた（2026-08-11 に発覚）。
  # 変数名だけを出す。値はトークンそのものなので絶対に出さない。
  envkeys="$(plutil -p "$plist" 2>/dev/null \
    | sed -n '/EnvironmentVariables/,/}/p' \
    | grep -oE '"[A-Za-z_][A-Za-z0-9_]*"[[:space:]]*=>' \
    | sed 's/"//g; s/[[:space:]]*=>//' \
    | grep -v '^EnvironmentVariables$' | sort -u)"
  if [ -n "$envkeys" ]; then
    echo "  plist の環境変数: $(printf '%s' "$envkeys" | tr '\n' ' ')"
    if printf '%s' "$envkeys" | grep -qE "$BILLABLE_PAT"; then
      hit "plist の環境変数に API キーが直接書かれている"
      billable_jobs="$billable_jobs $job"
    fi
  fi

  # ProgramArguments から実ファイルを拾う。
  # plutil -p は配列の添字をクォート無しで出す（  0 => "/bin/bash"）。
  # ここを '"0" =>' と誤って書いていたため全件外れ、「痕跡なし」という
  # 何も調べていない結果を安全そうに見せていた（2026-08-11 に発覚）。
  # 念のため両方の形を受ける。
  files="$(plutil -p "$plist" 2>/dev/null \
    | grep -E '^[[:space:]]*"?[0-9]+"?[[:space:]]*=>' \
    | sed 's/.*=>[[:space:]]*"//; s/"[[:space:]]*$//' \
    | grep '^/')"

  # Program（単体指定）も拾う
  prog="$(plutil -p "$plist" 2>/dev/null \
    | grep -E '^[[:space:]]*"Program"[[:space:]]*=>' \
    | sed 's/.*=>[[:space:]]*"//; s/"[[:space:]]*$//')"
  [ -n "$prog" ] && files="$prog
$files"

  if [ -z "$(printf '%s' "$files" | tr -d '[:space:]')" ]; then
    note "実行ファイルを特定できなかった。判定不能として扱う（痕跡なしではない）"
    echo "  plist の中身:"
    plutil -p "$plist" 2>&1 | sed 's/^/    /' | head -30
    undetermined_jobs="$undetermined_jobs $job"
    continue
  fi

  found=""
  for f in $files; do
    [ -f "$f" ] || continue
    echo "  実行: $f"
    if grep -qE "$BILLABLE_PAT" "$f" 2>/dev/null; then
      found="yes"
      grep -nE "$BILLABLE_PAT" "$f" 2>/dev/null | head -3 | sed 's/^/      /'
    fi
    # 呼び先が別スクリプトを叩いている場合も1段だけ追う
    for sub in $(grep -oE '(/[A-Za-z0-9._-]+)+\.(sh|mjs|js|py)' "$f" 2>/dev/null | sort -u | head -10); do
      [ -f "$sub" ] || continue
      if grep -qE "$BILLABLE_PAT" "$sub" 2>/dev/null; then
        found="yes"
        echo "      → $sub にも課金の痕跡"
      fi
    done
  done

  if [ -n "$found" ]; then
    hit "API 課金の可能性あり"
    billable_jobs="$billable_jobs $job"
  else
    safe "実行ファイルには API キー・課金エンドポイントの参照が無い"
  fi
done

bold "まとめ"

if [ -n "$billable_jobs" ]; then
  echo "  課金の可能性があるジョブ:"
  for j in $billable_jobs; do echo "    - ai.openclaw.$j"; done
  echo ""
  echo "  これらをロードする前に、費用の見積もりを出して承認を得ること。"
fi

if [ -n "$undetermined_jobs" ]; then
  echo ""
  echo "  判定不能（実行ファイルを特定できず、調べられていない）:"
  for j in $undetermined_jobs; do echo "    - ai.openclaw.$j"; done
  echo ""
  echo "  これは「課金なし」ではない。上に出した plist の中身を見て手で確認すること。"
fi

if [ -n "$missing_jobs" ]; then
  echo ""
  echo "  plist が存在しないジョブ:"
  for j in $missing_jobs; do echo "    - ai.openclaw.$j"; done
fi

if [ -z "$billable_jobs" ] && [ -z "$undetermined_jobs" ]; then
  echo "  調べられた範囲では API 課金の痕跡は見つからなかった。"
fi

echo ""
echo "  痕跡が無いことは無料の証明ではない。設定ファイル経由でキーを読む作りなら"
echo "  この監査では見えない。判断がつかないときは実行せずに報告する。"

# 判定不能が残るなら成功として返さない
[ -n "$undetermined_jobs" ] && exit 1
exit 0
