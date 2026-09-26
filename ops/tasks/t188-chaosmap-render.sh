#!/bin/bash
# **chaosmap の図を作り直す（t188）。LLM 不使用・$0。**
#
# ## なぜ要るか
#
# `point-service-complete-guide-2026` のロゴ 27 枚を差し替えたのに、
# **図のほうは古いアイコンのまま。** 本文と図でロゴが食い違っている。
#
#   chaosmap-matrix.png … 4 象限マップ（**iAEON** が写っている）
#   chaosmap.png        … カテゴリー早見表（**dヘルスケア 10 周年版 / マクロミル 25th**）
#   eyecatch.jpg        … 早見表を取り込んだ 16:9
#
# ## クラウドでは作り直せない
#
# `scripts/render-chaosmap.mjs` は **Mac のフォントとマスコット画像**（`sns-templates`）に
# 依存している。だから Mac で走らせる。
#
# ## パスを当て推量で書かない（最上位ルール 14）
#
# スクリプトには `/Users/ny_taxa/…` と書いてあったが、
# 引き継ぎメモは `/Users/ny/…` と言っている。**どちらが本当か分からない。**
# スクリプト側を直して「**環境変数 → 候補を順に探す → 無ければ探した場所を全部 出して止まる**」
# ようにした。このタスクは**見つかった場所をレポートに出す。**
#
# ## 図はレポートに持ち帰る。リポジトリを直接 書き換えない
#
# `OUT_DIR` をレポート用ディレクトリにして、**作業ツリーを触らない。**
# 差し替えはクラウド側で目で見てから PR にする（`ops/tasks` は PR を作らない）。
#
# **ロゴは `LOGO_DIR` でリポジトリのものを読む。** `OUT_DIR` を変えても出どころは変えない。
#
# **240 秒 で打ち切る**（最上位ルール 15）。画像 3 枚だけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t188-chaosmap-render.md"
DIR="$RDIR/chaosmap"
mkdir -p "$DIR"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# chaosmap の図を作り直す（t188・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**本文のロゴは差し替えたのに、図が古いアイコンのままだった。**"
  echo "図はレポートに持ち帰る。**リポジトリの作業ツリーは触らない。**"
  echo ""
} > "$OUT"

# --- どこに何が在るかを先に出す（**推測で書かない**・最上位ルール 14） ---
{
  echo "## 見つかった場所"
  echo ""
  echo "| | パス | 在るか |"
  echo "| --- | --- | --- |"
} >> "$OUT"
row() { [ -e "$2" ] && echo "| $1 | \`$2\` | ✅ |" >> "$OUT" || echo "| $1 | \`$2\` | ❌ |" >> "$OUT"; }
row "blog リポジトリ" "$REPO"
SNS=""
for d in "$HOME/projects/anta-baka-x/sns-templates" \
         "/Users/ny/projects/anta-baka-x/sns-templates" \
         "/Users/ny_taxa/projects/anta-baka-x/sns-templates"; do
  row "sns-templates 候補" "$d"
  [ -z "$SNS" ] && [ -d "$d" ] && SNS="$d"
done
PWDIR=""
for d in "$HOME/.openclaw/workspace/node_modules" "$HOME/openclaw/node_modules" "$REPO/node_modules"; do
  [ -d "$d/playwright-core" ] && { PWDIR="$d"; break; }
done
row "playwright-core" "${PWDIR:-（無い）}/playwright-core"
echo "" >> "$OUT"

if [ -z "$SNS" ]; then
  echo "⚠️ **\`sns-templates\` がどこにも無い。** フォントとマスコットが読めないので何もせず終わる。" >> "$OUT"
  cat "$OUT"; exit 0
fi
[ -d "$REPO" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }

# --- `origin/main` の版で走らせる（**Mac の作業ツリーは追従していない**） ---
SCRIPT="$RDIR/.t188-render.mjs"
( cd "$REPO" && git fetch -q origin main 2>/dev/null; \
  git show origin/main:scripts/render-chaosmap.mjs ) > "$SCRIPT" 2>/dev/null
n=$(wc -c < "$SCRIPT" | tr -d ' ')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
if [ "$n" -lt 2000 ]; then
  echo "⚠️ **\`origin/main\` からスクリプトを取り出せない**（$n bytes）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- スクリプト: \`origin/main:scripts/render-chaosmap.mjs\`（**$n bytes**）" >> "$OUT"
echo "" >> "$OUT"

{ echo "## 実行"; echo ""; echo '```'; } >> "$OUT"
# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ
SNS_DIR="$SNS" PW_DIR="$PWDIR" BLOG_REPO="$REPO" OUT_DIR="$DIR" \
  node "$SCRIPT" >> "$OUT" 2>&1 &
PID=$!
START=$(date +%s)
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 240 ] && { kill "$PID" 2>/dev/null; echo "**240 秒 で打ち切った**" >> "$OUT"; break; }
  sleep 2
done
wait "$PID" 2>/dev/null
RC=$?
rm -f "$SCRIPT"
echo '```' >> "$OUT"

# --- **`rc=0` を証拠にしない**（最上位ルール 13）。出た画像の大きさで見る ---
{
  echo ""
  echo "## 出た画像"
  echo ""
  echo "| ファイル | bytes |"
  echo "| --- | --- |"
} >> "$OUT"
GOT=0
for f in chaosmap-matrix.png chaosmap.png eyecatch.jpg; do
  if [ -f "$DIR/$f" ]; then
    sz=$(wc -c < "$DIR/$f" | tr -d ' ')
    case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
    echo "| \`$f\` | **$sz** |" >> "$OUT"
    [ "$sz" -gt 20000 ] && GOT=$((GOT + 1))
  else
    echo "| \`$f\` | ❌ **出ていない** |" >> "$OUT"
  fi
done

{
  echo ""
  echo "---"
  echo ""
  echo "**対象 3 枚 / 出たもの $GOT 枚。** 終了コード $RC / 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "> **\`rc=0\` は作れた証拠ではない**（最上位ルール 13）。上の bytes で見ている。"
  echo ""
  echo "**採否はクラウド側で図を見てから決める。** 古いアイコン（iAEON・10 周年版・25th）が"
  echo "消えているかを目で確かめること。"
} >> "$OUT"

cat "$OUT"
