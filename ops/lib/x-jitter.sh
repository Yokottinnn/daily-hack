#!/bin/bash
# 起動の時刻をばらつかせる（2026-11-14・スパムのラベル対策）。launchd の決まった時刻に起きたら、0〜<最大秒> のランダムな秒数だけ待ってから本体を動かす。
# 使い方（plist の ProgramArguments の先頭に足す）: /bin/bash x-jitter.sh <最大秒> <本体のコマンド…>
MAX="${1:-1500}"; shift
case "$MAX" in ''|*[!0-9]*) MAX=1500 ;; esac
S=$(( RANDOM % (MAX + 1) ))
echo "[x-jitter] $(date '+%Y-%m-%dT%H:%M:%S') ${S} 秒 待ってから始める（最大 ${MAX}）" >&2
sleep "$S"
exec "$@"
