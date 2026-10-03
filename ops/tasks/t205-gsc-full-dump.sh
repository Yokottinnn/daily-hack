#!/bin/bash
# **全記事の検索順位を JSON で丸ごと出す（t205）。読むだけ・LLM 不使用・$0。**
#
# 利用者の依頼（2026-10-03）:「PVとか記事のSEO上の順位とか全て分析してね」
# 手元にある GSC は「順位 TOP10」と「惜しい記事 6 件の語」（t198）だけで、
# **全記事の順位・表示・クリックが揃っていない。** 分析の元データを 1 回で取る。
#
# 取るもの（すべて type=web）:
#   pages_90d   : ページ別   2026-07-03 〜 2026-09-30
#   pages_cur   : ページ別   2026-09-03 〜 2026-09-30（直近 28 日）
#   pages_prev  : ページ別   2026-08-06 〜 2026-09-02（その前の 28 日）
#   pq_90d      : ページ×語  90 日
#   queries_90d : 語別       90 日（ページ×語で伏せられた分の大きさを見る）
#   dates_90d   : 日別       90 日（推移）
#
# GSC は確定まで 2〜3 日かかるので終わりを 9/30 にしている。
# 出力は $OPS_REPORT_DIR/t205-gsc-full.json（ops/heartbeat に push される）。
# GSC API は無料。LLM 不使用。**$0。** 240 秒 で打ち切る。

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t205-gsc-full-dump.md"
JSON="$RDIR/t205-gsc-full.json"
mkdir -p "$RDIR"

{
  echo "# 全記事の検索データ（t205・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
SCRIPT="${TMPDIR:-/tmp}/t205-wbr.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" 2>/dev/null || {
  echo "⚠️ **スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }
n=$(wc -c < "$SCRIPT" | tr -d ' ')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
[ "$n" -ge 2000 ] || { echo "⚠️ **スクリプトが小さすぎる**（$n bytes）" >> "$OUT"; cat "$OUT"; exit 0; }

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ **Python 3.10 以上が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

PROBE="${TMPDIR:-/tmp}/t205-probe.py"
cat > "$PROBE" <<'PY'
import datetime, importlib.util, json, sys
spec = importlib.util.spec_from_file_location("wbr", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
D = datetime.date
tok = m.gsc_token()
win = {
    "pages_90d":   (["page"],          D(2026, 7, 3), D(2026, 9, 30)),
    "pages_cur":   (["page"],          D(2026, 9, 3), D(2026, 9, 30)),
    "pages_prev":  (["page"],          D(2026, 8, 6), D(2026, 9, 2)),
    "pq_90d":      (["page", "query"], D(2026, 7, 3), D(2026, 9, 30)),
    "queries_90d": (["query"],         D(2026, 7, 3), D(2026, 9, 30)),
    "dates_90d":   (["date"],          D(2026, 7, 3), D(2026, 9, 30)),
}
out = {"generated": datetime.datetime.now().isoformat(timespec="seconds"), "windows": {}, "data": {}}
for k, (dims, s, e) in win.items():
    rows = m.gsc_rows(tok, dims, s, e, 25000)
    out["windows"][k] = [str(s), str(e)]
    out["data"][k] = [
        {"keys": r["keys"], "c": int(r["clicks"]), "i": int(r["impressions"]),
         "p": round(float(r["position"]), 2)} for r in rows]
    print(f"| `{k}` | {s} 〜 {e} | **{len(rows)}** 行 |")
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
PY

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

RES="${TMPDIR:-/tmp}/t205-res.md"
run_limited 240 "$PY" "$PROBE" "$SCRIPT" "$JSON" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"
echo "" >> "$OUT"
echo "| 取ったもの | 窓 | 行数 |" >> "$OUT"
echo "| --- | --- | --- |" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
echo "" >> "$OUT"

# **rc では判断しない。** JSON を読み直して確かめる（最上位ルール 13）
if [ -s "$JSON" ] && "$PY" -c 'import json,sys;json.load(open(sys.argv[1]))' "$JSON" 2>/dev/null; then
  sz=$(wc -c < "$JSON" | tr -d ' ')
  echo "✅ \`t205-gsc-full.json\` **$sz bytes**・JSON として読める" >> "$OUT"
else
  echo "⚠️ **JSON が無いか、読めない**" >> "$OUT"
fi
rm -f "$SCRIPT" "$PROBE" "$RES"

{
  echo ""
  echo "LLM 不使用。GSC API は無料枠。**\$0/回**（1 回きり）。"
} >> "$OUT"
cat "$OUT"
