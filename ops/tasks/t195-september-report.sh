#!/bin/bash
# **9 月の月次レポートを出す（t195）。LLM 不使用・$0。**
#
# ## 利用者の依頼（2026-09-27）
#
# > また9月のブログのPV等のレポートを少し早めに教えて／月次レポートを出して欲しい
#
# ## 月次の仕組みは**まだ無い**
#
# 在るのは週次だけ（`com.dailyhack.weekly-blog-report`・毎週月曜 08:00 JST）。
# `docs/analytics/README.md` の運用ルールも「**週1**で分析」としか書いていない。
# **だから今回は手で出す。** 定期化するかは利用者の判断を待つ。
#
# ## PV は GitHub Actions 側で取れる（このタスクの担当ではない）
#
# `weekly-pv-report` が Cloudflare から取る。**9/14・9/21 とも失敗していた**
# （`jq: Argument list too long`）。原因は今日 直したので、そちらで取り直す。
#
# **このタスクの担当は GSC（検索）。** gcloud の SA が Mac にしか無い。
#
# ## 出すもの
#
#   ① 9 月（9/1〜）… `--gsc-days 27`
#   ② 8 月との比較のため 8 月ぶんも … `--gsc-days 57` との差で見る
#
# **`weekly-blog-report.py` は「直近 N 日」しか取れない。**
# 月の境目で切る機能は無いので、**日数で近似していることを明記する**
# （9/1 からちょうど 27 日）。当て推量の数字を出さない。
#
# **GSC は確定まで 2〜3 日かかる。** スクリプトが直近 3 日を除くので、
# 実際の窓は 9/1〜9/24 あたりになる。**レポートに出る窓の表示をそのまま読む。**
#
# **300 秒 で打ち切る**（最上位ルール 15）。読むだけ。

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t195-september-report.md"
mkdir -p "$RDIR"

{
  echo "# 9 月の月次レポート（t195・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**月次の仕組みはまだ無い。** 在るのは週次だけなので、今回は手で出している。"
  echo "**PV は GitHub Actions（\`weekly-pv-report\`）の担当。** ここは GSC（検索）。"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
SCRIPT="${TMPDIR:-/tmp}/t195-weekly-blog-report.py"
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
echo "- python: \`$PY\` / スクリプト **$n bytes**" >> "$OUT"
echo "" >> "$OUT"

START=$(date +%s)
run_limited() {  # $1=秒 …残り=コマンド
  local lim="$1"; shift
  "$@" &
  local pid=$! t0; t0=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    [ $(( $(date +%s) - t0 )) -ge "$lim" ] && { kill "$pid" 2>/dev/null; return 124; }
    sleep 3
  done
  wait "$pid" 2>/dev/null
}

# --- ① 9 月ぶん（9/1 から 27 日） ---
M1="${TMPDIR:-/tmp}/t195-sep.md"
run_limited 130 "$PY" "$SCRIPT" --days 27 --gsc-days 27 --top-pages 20 --top-queries 25 --out "$M1"
RC1=$?
{
  echo "## ① 9 月（直近 27 日 ＝ 9/1 から）"
  echo ""
  echo "> **月の境目で切る機能はスクリプトに無い。** 日数で近似している。"
  echo "> GSC は確定まで 2〜3 日かかるので、**下に出る窓の表示をそのまま読むこと。**"
  echo ""
  echo "終了コード **$RC1**"
  echo ""
} >> "$OUT"
if [ -f "$M1" ]; then cat "$M1" >> "$OUT"; else echo "⚠️ **出力が無い**" >> "$OUT"; fi

# --- ② 前の 4 週との比較用（57 日） ---
if [ $(( $(date +%s) - START )) -lt 150 ]; then
  M2="${TMPDIR:-/tmp}/t195-57.md"
  run_limited 130 "$PY" "$SCRIPT" --days 57 --gsc-days 57 --top-pages 10 --top-queries 10 --out "$M2"
  RC2=$?
  {
    echo ""
    echo "---"
    echo ""
    echo "## ② 直近 57 日（8 月 ぶんを含む。**引き算で 8 月を出すため**）"
    echo ""
    echo "終了コード **$RC2**"
    echo ""
  } >> "$OUT"
  [ -f "$M2" ] && cat "$M2" >> "$OUT" || echo "⚠️ **出力が無い**" >> "$OUT"
fi
rm -f "$SCRIPT"

{
  echo ""
  echo "---"
  echo ""
  echo "経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "> **\`rc=0\` は数字が出た証拠ではない**（最上位ルール 13）。"
  echo "> 各節に「⚠️ 取れなかった」と書かれていないかを見ること。"
  echo "> Cloudflare のトークンが見つからないと **PV の節だけ落ちる**（2026-09-06 に実際そうなった）。"
} >> "$OUT"

cat "$OUT"
