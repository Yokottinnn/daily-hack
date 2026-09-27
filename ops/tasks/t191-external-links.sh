#!/bin/bash
# **記事の外部リンクが生きているかを一括で見る（t191）。LLM 不使用・$0。**
#
# ## なぜ要るか
#
# **2026-09-26 に 1 日で 3 本 見つかった。どれも気づく仕組みが無かった。**
#
# | リンク | 実際 |
# | --- | --- |
# | `https://www.bang.co.jp/auto/` | title が **"404 Not Found"** |
# | `https://www.softbank.jp/internet/hikari/` | **別商品（Yahoo! BB 光）に転送されていた** |
# | `https://www.jal.co.jp/…/jalpay/` | **404** |
#
# **ビルドも既存の検査も素通りする。** 外部リンクは誰も見ていない。
# しかも **404 より「別物に転送」のほうが悪い**（読者は気づかずに別商品を見る）。
#
# ## クラウドからは走らせられない
#
# egress が塞がれているので、**Mac で走らせる。** 対象は **1,016 件**
# （bot を弾くのが前提のホスト = twitter / x / youtube / a8.net は最初から外した）。
#
# ## 判定の作法（**レポートを読むときも同じ**）
#
# - **`403` を「死んでいる」と書かない。** bot を弾いているだけのことが多いので、
#   「弾かれた（生死は不明）」として分けて出す
# - **転送先が別物になっていないかを見る。** ホストかパスが変わったものを一覧にする。
#   **判断は人がする**（正当な転送も多い）
# - HEAD を拒むサーバが在るので、**405/501/403/400 なら GET の 1 バイトで試し直す**
#
# ## 時間切れでも続きから再開できる
#
# `--budget` 秒で打ち切り、そこまでの結果を JSON に残す。
# 次は `--resume` で続きから。**同じタスクを番号だけ変えて出し直せばよい。**
#
# **300 秒 で打ち切る**（最上位ルール 15）。読むだけ。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t191-external-links.md"
JSON="$RDIR/external-links.json"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# 記事の外部リンクの死活（t191・**\$0**）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
  echo "**\`403\` を「死んでいる」と読まない**（bot を弾いているだけのことが多い）。"
  echo "**404 より「別物に転送」のほうが悪い。** 読者は気づかずに別商品を見る。"
  echo ""
} > "$OUT"

[ -d "$REPO" ] || { echo "⚠️ **リポジトリが無い**: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
command -v node >/dev/null 2>&1 || { echo "⚠️ **node が無い**" >> "$OUT"; cat "$OUT"; exit 0; }

# --- `origin/main` の版で走らせる（**Mac の作業ツリーは追従していない**） ---
SCRIPT="$RDIR/.t191-check.mjs"
( cd "$REPO" && git fetch -q origin main 2>/dev/null; \
  git show origin/main:scripts/check-external-links.mjs ) > "$SCRIPT" 2>/dev/null
n=$(wc -c < "$SCRIPT" | tr -d ' ')
case "$n" in ''|*[!0-9]*) n=0 ;; esac
if [ "$n" -lt 1500 ]; then
  echo "⚠️ **\`origin/main\` からスクリプトを取り出せない**（$n bytes）。" >> "$OUT"
  cat "$OUT"; exit 0
fi
echo "- スクリプト: \`origin/main:scripts/check-external-links.mjs\`（**$n bytes**）" >> "$OUT"
echo "- 記事は \`$REPO\` の作業ツリーから読む" >> "$OUT"
echo "" >> "$OUT"

{ echo '```'; } >> "$OUT"
START=$(date +%s)
# **`timeout` は macOS に無い**（最上位ルール 14）。素の bash で待つ。
# スクリプト側にも予算を渡して、自分から畳めるようにしてある
( cd "$REPO" && node "$SCRIPT" --budget=260 --conc=8 --out="$JSON" ) >> "$OUT" 2>&1 &
PID=$!
while kill -0 "$PID" 2>/dev/null; do
  [ $(( $(date +%s) - START )) -ge 300 ] && { kill "$PID" 2>/dev/null; echo "**300 秒 で打ち切った**" >> "$OUT"; break; }
  sleep 3
done
wait "$PID" 2>/dev/null
rm -f "$SCRIPT"
echo '```' >> "$OUT"

# --- **`rc=0` を証拠にしない**（最上位ルール 13）。JSON が読めるかで見る ---
CHECKED=0
if [ -f "$JSON" ]; then
  CHECKED="$(node -e "
    try { const d = JSON.parse(require('fs').readFileSync('$JSON','utf8'));
          console.log(d.results.length + '/' + d.total); }
    catch (e) { console.log('parse-error'); }" 2>/dev/null || echo 'parse-error')"
fi
{
  echo ""
  echo "---"
  echo ""
  echo "**見た件数: $CHECKED。** 経過 **$(( $(date +%s) - START )) 秒**。"
  echo ""
  echo "> **\`rc=0\` は見た証拠ではない**（最上位ルール 13）。上の件数は JSON を parse して数えている。"
  echo ""
  echo "**全部 見終わっていなければ、番号を変えた同じタスクを \`--resume=$JSON\` で出し直す。**"
  echo "JSON はレポートと一緒に持ち帰るので、クラウド側でも中身を読める。"
} >> "$OUT"

cat "$OUT"
