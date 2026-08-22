#!/bin/bash
# ループ①（返信への返信＝会話の継続）を担う auto-thread-chainifier を調べる。
#
# **ロードはしない。** このジョブは LLM で文面を生成するため、
# 1 日あたり何件打つのかが分からないままロードすると費用が読めない
# （最上位ルール 2-B）。上限値を持ち帰ってから、人が判断してロードする。
#
# 実機の状態: plist は存在するが launchctl に載っていない。
# chain_counts の最終記録は 2026-06-09 で、2 か月半 動いていない。
#
# **秘密を出力しないこと。** 結果は公開リポジトリに載る。
set -uo pipefail

W="$HOME/.openclaw/workspace"
PL="$HOME/Library/LaunchAgents/ai.openclaw.auto-thread-chainifier.plist"
S="$W/scripts/auto-thread-chainifier.js"

echo "## plist"
if [ -f "$PL" ]; then
  echo "program: $(plutil -p "$PL" 2>/dev/null | awk '/ProgramArguments/,/\)/' \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v ProgramArguments | tr '\n' ' ' | cut -c1-200)"
  echo "StartInterval: $(plutil -extract StartInterval raw "$PL" 2>/dev/null || echo '無し')"
  echo "StartCalendarInterval: $(plutil -extract StartCalendarInterval json "$PL" 2>/dev/null | cut -c1-200 || echo '無し')"
  echo "RunAtLoad: $(plutil -extract RunAtLoad raw "$PL" 2>/dev/null || echo '無し')"
else
  echo "plist が無い: $(basename "$PL")"
fi

echo
echo "## スクリプト"
if [ -f "$S" ]; then
  echo "行数: $(wc -l < "$S" | tr -d ' ')"
  echo
  echo "### 上限らしき定数（これが費用を決める）"
  grep -nE '(MAX|LIMIT|CAP|PER_|_PER|COOLDOWN|THRESHOLD)[A-Z_]*[[:space:]]*[=:]' "$S" 2>/dev/null \
    | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | head -20
  echo
  echo "### モデル指定"
  grep -noE 'claude-[a-z0-9.-]+' "$S" 2>/dev/null | sort -u | head -5
  echo
  echo "### 環境変数（キー名のみ）"
  grep -oE 'process\.env\.[A-Z_]+' "$S" 2>/dev/null | sort -u | head -20
  echo
  echo "### 読み書きするファイル"
  grep -oE "(data|state|logs)/[A-Za-z0-9._-]+" "$S" 2>/dev/null | sort -u | head -15
else
  echo "スクリプトが無い: scripts/auto-thread-chainifier.js"
fi

echo
echo "## ログ（直近3行・先頭100字・20字以上の英数字は伏せる）"
tail -3 "$W/logs/auto-thread-chainifier.log" 2>/dev/null \
  | sed -E 's/[A-Za-z0-9_-]{20,}/<MASKED>/g' | cut -c1-100
[ -f "$W/logs/auto-thread-chainifier.log" ] \
  || echo "（ログが無い＝一度も動いていない可能性）"
