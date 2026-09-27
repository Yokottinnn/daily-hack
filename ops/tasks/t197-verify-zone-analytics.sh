#!/bin/bash
# **一本化した週次レポートが Mac で本当に動くか確かめる（t197）。読むだけ・$0。**
#
# 2026-09-27、`weekly-blog-report.py` の PV 側を RUM から
# **Zone Analytics** に差し替えた（PR #760）。理由は RUM のデータが
# **1 件も存在しなかった**こと（ビーコンの token がアカウントに無いサイトを指していた）。
#
# **ローカルの検証はスタブ（`_cf_day` を差し替え）なので、実 API は通っていない。**
# クラウドは Linux、実行先は macOS で別物（最上位ルール 14）。
# **`rc=0` は数字が出た証拠にならない**（最上位ルール 13）。だから実際に走らせる。
#
# ## 見たいこと
#
#   ① 例外なく完走するか（トークンの権限・ゾーン ID の解決を含む）
#   ② **visits が 0 でない**こと（RUM 時代は記事ページが 0 だった）
#   ③ **実ブラウザ / 日本から の行が出ている**こと
#   ④ 流入経路が「取れない」と書かれていること（空の表になっていないこと）
#   ⑤ 人気ページに **`/posts/…` が並ぶ**こと ← ここが RUM との最大の違い
#
# **2 日ぶんだけ引く。** 1 日 4 クエリなので 8 本。短く終わる（最上位ルール 15）。
#
# LLM 不使用・Cloudflare API と GSC API は無料枠。**$0。**

set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t197-verify-zone-analytics.md"
mkdir -p "$RDIR"

{
  echo "# 一本化した週次レポートを Mac で実行する（t197・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true

SCRIPT="${TMPDIR:-/tmp}/t197-weekly-blog-report.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" 2>/dev/null || {
  echo "⚠️ **スクリプトを取り出せない**" >> "$OUT"; cat "$OUT"; exit 0; }
n=$(wc -c < "$SCRIPT" | tr -d ' ')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
[ "$n" -ge 2000 ] || { echo "⚠️ **スクリプトが小さすぎる**（$n bytes）" >> "$OUT"; cat "$OUT"; exit 0; }

# **一本化済みのものを取れているか確かめる。** 古いまま走らせても意味が無い
if grep -q 'rumPageloadEventsAdaptiveGroups' "$SCRIPT"; then
  echo "⚠️ **まだ RUM 版。** origin/main が更新されていない（PR #760 未マージ？）" >> "$OUT"
  cat "$OUT"; exit 0
fi
grep -q 'httpRequestsAdaptiveGroups' "$SCRIPT" || {
  echo "⚠️ **Zone Analytics のクエリが見つからない**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- スクリプト **$n bytes** / Zone Analytics 版であることを確認" >> "$OUT"

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "⚠️ **Python 3.10 以上が無い**" >> "$OUT"; cat "$OUT"; exit 0; }
echo "- python: \`$PY\`" >> "$OUT"
echo "" >> "$OUT"

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

MD="${TMPDIR:-/tmp}/t197-report.md"
ERR="${TMPDIR:-/tmp}/t197-stderr.txt"
run_limited 200 "$PY" "$SCRIPT" --days 2 --gsc-days 7 --top-pages 10 --top-queries 5 --out "$MD" 2> "$ERR"
RC=$?
echo "終了コード **$RC**" >> "$OUT"
echo "" >> "$OUT"

if [ -s "$ERR" ]; then
  { echo "### 標準エラー"; echo ""; echo '```'; head -c 1200 "$ERR"; echo; echo '```'; echo ""; } >> "$OUT"
fi

if [ ! -s "$MD" ]; then
  echo "⚠️ **レポートが出なかった。**" >> "$OUT"; cat "$OUT"; exit 0
fi

# --- 見たかった 5 点を機械で判定する（目で追わない） ---
{
  echo "### 判定"
  echo ""
  echo "| # | 見たこと | 結果 |"
  echo "| --- | --- | --- |"
} >> "$OUT"

chk() {  # $1=番号 $2=説明 $3=0なら成功
  if [ "$3" = "0" ]; then echo "| $1 | $2 | ✅ |" >> "$OUT"
  else echo "| $1 | $2 | ❌ |" >> "$OUT"; fi
}

grep -q '取得失敗' "$MD"; g=$?; [ "$g" = "1" ] && a=0 || a=1
chk 1 "サマリーが「取得失敗」になっていない" "$a"

V=$(grep -m1 'visits（' "$MD" | grep -o '[0-9][0-9,]*' | head -1 | tr -d ',')
case "$V" in ''|*[!0-9]*) V=0 ;; esac
[ "$V" -gt 0 ] && b=0 || b=1
chk 2 "visits が 0 でない（**$V**）" "$b"

grep -q '実ブラウザ visits' "$MD" && c=0 || c=1
chk 3 "「実ブラウザ visits」の行が在る" "$c"

grep -q 'Cloudflare では取れない' "$MD" && d=0 || d=1
chk 4 "流入経路が「取れない」と書かれている" "$d"

P=$(grep -c '`/posts/' "$MD" | head -1)
case "$P" in ''|*[!0-9]*) P=0 ;; esac
[ "$P" -gt 0 ] && e=0 || e=1
chk 5 "人気ページに /posts/… が並ぶ（**$P 行**）" "$e"

{
  echo ""
  echo "### レポート本文（先頭 70 行）"
  echo ""
  echo '```markdown'
  head -70 "$MD"
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "> **⑤ が ❌ なら一本化は失敗。** RUM 時代と同じく記事ページが 0 のまま。"
  echo ""
  echo "LLM 不使用。Cloudflare API・GSC API は無料枠。**\$0/回・\$0/日・\$0/月。**"
} >> "$OUT"

rm -f "$SCRIPT" "$MD" "$ERR"
cat "$OUT"
