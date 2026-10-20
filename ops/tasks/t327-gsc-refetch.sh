#!/bin/bash
# **今朝の Search Console のデータを取り直して送る（t327）。**
# 10/21 6:40 に書いた reports/board/gsc-weekly.json が、6:44 の heartbeat の巻き戻しで消え、送信に入らなかった
# （作戦室の検索の数字が 10/20 のまま）。タスクの中で書いたものは heartbeat が実行後に commit するので消えない。
# mac-weekly.sh は「外で書いて最後に移して即送る」形に直した（同じ PR）。
# ## 費用（最上位ルール 2-B）: LLM 不使用・GSC API は無料枠。**1 回 $0・1 日 $0・1 か月 $0**
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t327-gsc-refetch.md"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
mkdir -p "$RDIR/board"
{ echo "# 検索データの取り直し（t327・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ python 3.10 以上が無い" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null
G="$RDIR/.gsc-dump.py"; git -C "$REPO" show origin/main:scripts/gsc-dump.py > "$G"
"$PY" "$G" --rolling --out "$RDIR/.gsc-weekly.json" > "$RDIR/.gsc.log" 2>&1 &
P=$!; t0=$(date +%s)
while kill -0 "$P" 2>/dev/null; do [ $(( $(date +%s) - t0 )) -ge 240 ] && { kill "$P" 2>/dev/null; echo "- ⚠️ 240 秒で終わらなかった" >> "$OUT"; break; }; sleep 3; done
if [ -s "$RDIR/.gsc-weekly.json" ] && "$PY" -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d["generated"],d["windows"]["pages_cur"])' "$RDIR/.gsc-weekly.json" >> "$OUT" 2>&1; then
  mv "$RDIR/.gsc-weekly.json" "$RDIR/board/gsc-weekly.json"; echo "- 置いた: reports/board/gsc-weekly.json" >> "$OUT"
else
  echo "- ⚠️ 取れなかった"; tail -5 "$RDIR/.gsc.log" >> "$OUT"
fi
cat "$OUT"
