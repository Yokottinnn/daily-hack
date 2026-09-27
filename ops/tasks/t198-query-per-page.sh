#!/bin/bash
# **惜しい記事が「どの語で出ているか」を出す（t198）。読むだけ・LLM 不使用・$0。**
#
# 9 月の GSC で、**4〜10 位に 53 記事・表示 1,064** が溜まっている。
# 1 ページ目の下に並んでいるのにクリックされていない。
#
#   表示 88 / クリック 0   tokyo-bay-hanabi-2026            8.1 位
#   表示 76 / クリック 1   outlet-mall-guide-2026          12.6 位
#   表示 60 / クリック 0   furusato-tax-2026-reform-guide   7.6 位
#   表示 43 / クリック 2   wangan-supermarkets-2026         7.1 位
#   表示 35 / クリック 0   narita-haneda-overseas-direct    6.8 位
#   表示 23 / クリック 0   wangan-tower-construction-map    6.8 位
#   表示 22 / クリック 1   mobility-cost-per-km-2026        7.5 位
#
# **だが「どの語で出ているか」が分からないと直せない。**
# 見出しに検索語が無いのか、そもそも検索意図とずれているのかが判別できない。
# 週次レポートは当たり語を**サイト全体**でしか出さないので、ページごとに引く。
#
# **これは測るだけのタスク。** 直すのは記事側で別に行う（最上位ルール 15）。
#
# GSC API は無料。LLM 不使用。**$0。** 240 秒 で打ち切る。

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t198-query-per-page.md"
mkdir -p "$RDIR"

{
  echo "# 惜しい記事の当たり語（t198・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
SCRIPT="${TMPDIR:-/tmp}/t198-wbr.py"
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

PROBE="${TMPDIR:-/tmp}/t198-probe.py"
cat > "$PROBE" <<'PY'
import datetime, importlib.util, sys
spec = importlib.util.spec_from_file_location("wbr", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

# 9 月ぶん。**GSC は確定まで 2〜3 日**かかるので終わりを 9/24 にする
start, end = datetime.date(2026, 9, 1), datetime.date(2026, 9, 24)
tok = m.gsc_token()
rows = m.gsc_rows(tok, ["page", "query"], start, end, 25000)
print(f"- 窓: **{start} 〜 {end}** / page×query **{len(rows)} 行**")
print("")

# ページごとにまとめる
by = {}
for r in rows:
    page, q = r["keys"][0], r["keys"][1]
    by.setdefault(page, []).append(
        (q, int(r["impressions"]), int(r["clicks"]), float(r["position"])))

# 表示が多い順にページを並べ、**クリックが少ないものを先に見る**
def score(v):
    impr = sum(x[1] for x in v)
    clicks = sum(x[2] for x in v)
    return (-(impr - clicks * 20), )      # 表示のわりにクリックが無いものを上へ

pages = sorted(by.items(), key=lambda kv: score(kv[1]))
print(f"**検索に出たページ {len(pages)} 件。** 上位 14 件を出す。")
print("")
print("> 並べ方は「**表示のわりにクリックが無い**」順。")
print("> 各ページの語は表示の多い順で上位 12。")
print("")
for page, v in pages[:14]:
    impr = sum(x[1] for x in v); clicks = sum(x[2] for x in v)
    pos = (sum(x[3] * x[1] for x in v) / impr) if impr else 0
    ctr = (clicks / impr * 100) if impr else 0
    short = page.replace("https://daily-hack.fieldbeside.com", "")
    print(f"### `{short}`")
    print("")
    print(f"表示 **{impr}** / クリック **{clicks}** / CTR **{ctr:.1f}%** / 平均 **{pos:.1f} 位** / 語 {len(v)} 個")
    print("")
    print("| 語 | 表示 | クリック | 順位 |")
    print("| --- | --- | --- | --- |")
    for q, i_, c_, p_ in sorted(v, key=lambda x: -x[1])[:12]:
        mark = "**" if c_ == 0 and i_ >= 3 else ""
        print(f"| {mark}{q}{mark} | {i_} | {c_} | {p_:.1f} |")
    print("")
print("---")
print("")
print("> **太字は「表示 3 回 以上・クリック 0」の語。** そこが直す対象。")
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

RES="${TMPDIR:-/tmp}/t198-res.md"
run_limited 240 "$PY" "$PROBE" "$SCRIPT" > "$RES" 2>&1
RC=$?
echo "終了コード **$RC**" >> "$OUT"
echo "" >> "$OUT"
if [ -s "$RES" ]; then cat "$RES" >> "$OUT"; else echo "⚠️ **出力が空**（$RC）" >> "$OUT"; fi
rm -f "$SCRIPT" "$PROBE" "$RES"

{
  echo ""
  echo "LLM 不使用。GSC API は無料枠。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"
cat "$OUT"
