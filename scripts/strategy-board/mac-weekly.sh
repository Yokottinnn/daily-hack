#!/bin/bash
# **収益化作戦室の元データを Mac で毎週取る**（launchd 毎週 月曜 06:40。asp-sync 06:12 の後）。
# LLM 不使用・**$0**。書き出し先は heartbeat が push する reports/board/（公開ブランチ ops/heartbeat）。
#
#   1) Search Console の直近 28 日・前の 28 日・90 日（gsc-dump.py --rolling）→ board/gsc-weekly.json
#   2) A8 の提携中プログラムの名前・広告側の報酬・本人申込の可否（asp-probe a8partnered）→ board/asp-probe/a8partnered.json
#   3) 実行結果 → board/mac-weekly-status.json（各段の終了コードと生成時刻）
#
# **公開ブランチに出すので、自分の報酬額・会社名・氏名・口座は出さない。** 出すのは広告側の公開条件だけ。
# macOS で使えない構文（timeout / sed -i / date -d / stat -c）は使わない（最上位ルール 14）。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
REPORTS="${OPS_REPORT_DIR:-$HOME/.openclaw/ops-heartbeat-wt/reports}"
BOARD="$REPORTS/board"
WORK="${TMPDIR:-/tmp}/board-weekly"
mkdir -p "$BOARD" "$WORK"
git -C "$REPO" fetch -q origin main 2>/dev/null || true
NODE_BIN=/opt/homebrew/bin/node; [ -x "$NODE_BIN" ] || NODE_BIN="$(command -v node || true)"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
run_limited() {
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}
for f in gsc-dump.py weekly-blog-report.py; do git -C "$REPO" show "origin/main:scripts/$f" > "$WORK/$f" 2>/dev/null; done
git -C "$REPO" show origin/main:scripts/asp/asp-sync.mjs > "$WORK/asp-sync.mjs" 2>/dev/null
git -C "$REPO" show origin/main:scripts/asp/asp-probe.mjs > "$WORK/asp-probe.mjs" 2>/dev/null

# 1) Search Console
GSC_RC=99
if [ -n "$PY" ] && [ -s "$WORK/gsc-dump.py" ]; then
  run_limited 240 "$PY" "$WORK/gsc-dump.py" --rolling --out "$WORK/gsc-weekly.json" > "$WORK/gsc.log" 2>&1; GSC_RC=$?
  # **rc では判断しない。** JSON を読み直してから置く（最上位ルール 13）
  if [ -s "$WORK/gsc-weekly.json" ] && "$PY" -c 'import json,sys;json.load(open(sys.argv[1]))' "$WORK/gsc-weekly.json" 2>/dev/null; then
    mv "$WORK/gsc-weekly.json" "$BOARD/gsc-weekly.json"; GSC_OK=true
  else GSC_OK=false; fi
else GSC_OK=false; fi

# 2) A8 の提携一覧（先に asp-sync でログインを保つ）
A8_RC=99; A8_OK=false
if [ -n "$NODE_BIN" ] && [ -s "$WORK/asp-probe.mjs" ]; then
  ASP_ONLY=a8 OPS_REPORT_DIR="$WORK/sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$WORK/asp-sync.mjs" > "$WORK/sync.log" 2>&1
  ASP_PROBE=a8partnered OPS_REPORT_DIR="$BOARD" run_limited 600 "$NODE_BIN" "$WORK/asp-probe.mjs" > "$WORK/a8.log" 2>&1; A8_RC=$?
  if [ -s "$BOARD/asp-probe/a8partnered.json" ] && "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$BOARD/asp-probe/a8partnered.json" 2>/dev/null; then A8_OK=true; fi
fi

# 3) 実行結果（自分で parse して確かめる）
cat > "$BOARD/mac-weekly-status.json" <<JSONEOF
{"generated":"$(date '+%Y-%m-%dT%H:%M:%S%z')","gsc":{"rc":$GSC_RC,"ok":$GSC_OK},"a8_partnered":{"rc":$A8_RC,"ok":$A8_OK}}
JSONEOF
"$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$BOARD/mac-weekly-status.json" && echo "board weekly: gsc=$GSC_OK a8=$A8_OK"
