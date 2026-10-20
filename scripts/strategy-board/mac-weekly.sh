#!/bin/bash
# **収益化作戦室の元データを Mac で毎日取る**（launchd 毎日 06:40。asp-sync 06:12 の後。2026-10-17 に毎週から毎日へ）。
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

# 2b) A8 以外の提携中（バリューコマース・もしも）。ログインを保ってから読む
OT_RC=99; OT_OK=false
if [ -n "$NODE_BIN" ] && [ -s "$WORK/asp-probe.mjs" ]; then
  ASP_ONLY=vc,moshimo OPS_REPORT_DIR="$WORK/sync" ASP_SYNC_BUDGET_MS=100000 run_limited 120 "$NODE_BIN" "$WORK/asp-sync.mjs" > "$WORK/sync2.log" 2>&1
  ASP_PROBE=others OPS_REPORT_DIR="$BOARD" run_limited 180 "$NODE_BIN" "$WORK/asp-probe.mjs" > "$WORK/others.log" 2>&1; OT_RC=$?
  if [ -s "$BOARD/asp-probe/others.json" ] && "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$BOARD/asp-probe/others.json" 2>/dev/null; then OT_OK=true; fi
fi

# 2c) X の数字（フォロワー数の推移・投稿ごとの表示回数）。t283 と同じ書き出し
X_OK=false
XJS="$(git -C "$REPO" show origin/main:ops/tasks/t283-x-board-export.sh 2>/dev/null | awk '/^cat > "\$JS" <<.JSEOF.$/{f=1;next} /^JSEOF$/{f=0} f')"
if [ -n "$NODE_BIN" ] && [ -n "$XJS" ]; then
  printf '%s\n' "$XJS" > "$WORK/x-export.js"
  run_limited 60 "$NODE_BIN" "$WORK/x-export.js" "$BOARD/x-weekly.json" > "$WORK/x.log" 2>&1 && X_OK=true
fi

# 2d) X の数字（ヘッダー・アナリティクス・収益化の条件）。読むだけ・$0（2026-10-19 追加。それまで作戦室の X の数字は 10/12 の手書きだった）
XN_OK=false
W="$HOME/.openclaw/workspace"
git -C "$REPO" show origin/main:scripts/strategy-board/x-numbers.js > "$W/.x-numbers.js" 2>/dev/null
if [ -n "$NODE_BIN" ] && [ -s "$W/.x-numbers.js" ]; then
  ( cd "$W" && run_limited 150 "$NODE_BIN" "$W/.x-numbers.js" "$BOARD/x-numbers.json" > "$WORK/xn.log" 2>&1 )
  "$NODE_BIN" -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(j.header&&j.header.followers?0:1)' "$BOARD/x-numbers.json" 2>/dev/null && XN_OK=true
fi

# 3) 実行結果（自分で parse して確かめる）
cat > "$BOARD/mac-weekly-status.json" <<JSONEOF
{"generated":"$(date '+%Y-%m-%dT%H:%M:%S%z')","gsc":{"rc":$GSC_RC,"ok":$GSC_OK},"a8_partnered":{"rc":$A8_RC,"ok":$A8_OK},"others":{"rc":$OT_RC,"ok":$OT_OK},"x":{"ok":$X_OK},"x_numbers":{"ok":$XN_OK}}
JSONEOF
"$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$BOARD/mac-weekly-status.json" && echo "board weekly: gsc=$GSC_OK a8=$A8_OK others=$OT_OK x=$X_OK x_numbers=$XN_OK"

# 4) **書いたらすぐ ops/heartbeat に送る**（2026-10-19）
# heartbeat（30 分ごと）は最初に worktree を origin に巻き戻す（reset --hard）。そのため、ここで書き換えた
# 既存のファイル（gsc-weekly.json など）は、送られる前に巻き戻しで消えていた。10/12 から 1 週間、作戦室の数字が止まった原因。
# 新しく増えるファイル（trend/<日付>.json）は巻き戻しで消えないので届いていた。
WT="$(cd "$REPORTS/.." && pwd)"
if git -C "$WT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$WT" add -f "reports/board" 2>/dev/null
  if ! git -C "$WT" diff --cached --quiet -- reports/board; then
    git -C "$WT" commit -q -m "ops: board daily $(date '+%Y-%m-%dT%H:%M:%S%z')" -- reports/board 2>/dev/null
    for i in 1 2 3; do
      git -C "$WT" push -q origin "HEAD:ops/heartbeat" 2>/dev/null && { echo "board weekly: pushed"; break; }
      git -C "$WT" fetch -q origin ops/heartbeat 2>/dev/null; git -C "$WT" rebase -q "origin/ops/heartbeat" 2>/dev/null || git -C "$WT" rebase --abort 2>/dev/null
      sleep 5
    done
  fi
fi
