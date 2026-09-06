#!/bin/bash
# **Cloudflare のトークンを置いてもらったので、週次レポートをもう一度 走らせる。**
#
# t055 は GSC だけ取れて、Cloudflare は「トークンが見つからない」で落ちた。
# 2026-09-06 に利用者が `~/.config/daily-hack/cf-token` へ保管済みの値を置いた。
#
# **見たいのは 3 つ。**
#   1. トークンが読めるか（読めなければレポートがそう言う）
#   2. rumPageloadEventsAdaptiveGroups が siteTag で引けるか（**実物では未検証**）
#   3. MAU（訪問数）・PV・流入経路が実際に出るか
#
# **Slack には出さない。launchd も触らない。** 数字を見るだけ。
#
# **秘密は出さない。** トークンの値は表示しない。長さだけ出す。
#
# LLM 不使用・$0/回・$0/日・$0/月（GSC API も Cloudflare API も無料）

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t060-weekly-report.md"
mkdir -p "$RDIR"

TOK="$HOME/.config/daily-hack/cf-token"
{
  echo "# 週次レポート（t060 / Cloudflare トークンあり）"
  echo
  echo "## トークンの状態"
  if [ -f "$TOK" ]; then
    echo "- \`~/.config/daily-hack/cf-token\` … **あり**（$(wc -c < "$TOK" | tr -d ' ') バイト）"
    echo "- パーミッション: $(ls -l "$TOK" | awk '{print $1}')"
  else
    echo "- \`~/.config/daily-hack/cf-token\` … **無い**"
  fi
} > "$OUT"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
git -C "$REPO" fetch -q origin main || true
SCRIPT="${TMPDIR:-/tmp}/weekly-blog-report.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" || {
  echo "スクリプトが取れない"; exit 1; }

PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ] && PY="$c" && break
done
[ -n "$PY" ] || { echo "Python 3.10 以上が無い"; exit 1; }

BODY="${TMPDIR:-/tmp}/t060-body.md"
"$PY" "$SCRIPT" --out "$BODY"
RC=$?

{
  echo
  cat "$BODY" 2>/dev/null
  echo
  echo "---"
  echo "t060: Python=\`$("$PY" -V 2>&1)\` / 終了コード=\`$RC\`（1 は「取れなかったものがある」）"
} >> "$OUT"

echo "=== 結果 ==="
cat "$OUT"
exit 0
