#!/bin/bash
# 掲載順位（GSC）を実測して報告に書き出す。
#
# GSC はクラウドセッションから叩けない（SA の impersonation が Mac にしか無い）。
# そのため **順位は Mac でしか取れず、取りに行かない限り誰も見ていない状態**が続いていた。
# ここで取って `reports/seo-rankings.md` に置けば、push されてクラウドから読める。
#
# GSC API は無料。LLM を呼ばないため API クレジットは消費しない。
# **秘密を出力しないこと。** 出るのは順位・表示・クリックと URL パスだけ。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/seo-rankings.md"

# gcloud/system python は 3.9 系。google-auth を持つ 3.11 を優先する。
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 /usr/bin/python3 python3; do
  [ -x "$c" ] || command -v "$c" >/dev/null 2>&1 || continue
  PY="$c"; break
done
[ -n "$PY" ] || { echo "python3 が見つからない"; exit 1; }

SCRIPT="$REPO/scripts/seo-rankings.py"
if [ ! -f "$SCRIPT" ]; then
  echo "スクリプトが無い: $SCRIPT（git pull が済んでいない可能性）"; exit 1
fi

if ! "$PY" "$SCRIPT" --days 28 --min-impressions 1 --top 10 --out "$OUT" 2>"${TMPDIR:-/tmp}/seo-rank-err.log"; then
  echo "取得に失敗: $(tail -3 "${TMPDIR:-/tmp}/seo-rank-err.log" | tr '\n' ' ' | cut -c1-200)"
  exit 1
fi

# 週次レポートに順位を足せるよう、実装の骨格だけ持ち帰る。
# **中身は出さない。** 行番号と定義名、順位に触れている行の位置だけ。
WEEKLY=""
for c in "$HOME/scripts/weekly-blog-report.py" "$HOME/.openclaw/workspace/scripts/weekly-blog-report.py"; do
  [ -f "$c" ] && { WEEKLY="$c"; break; }
done
{
  echo
  echo "## 週次レポート実装の骨格"
  echo
  if [ -z "$WEEKLY" ]; then
    echo "\`weekly-blog-report.py\` が既定の場所に無い。launchd の plist から実体を確認すること。"
  else
    echo "ファイル: \`${WEEKLY/#$HOME/~}\`（$(wc -l < "$WEEKLY" | tr -d ' ') 行）"
    echo
    echo '```'
    grep -nE '^\s*(def |class )|順位|position|惜しい|impressions' "$WEEKLY" \
      | sed -E 's#https?://[^ "'"'"']*#<URL>#g; s/[A-Za-z0-9_-]{24,}/<REDACTED>/g' \
      | cut -c1-160 | head -40
    echo '```'
  fi
} >> "$OUT"

echo "書き出した: reports/seo-rankings.md（$(wc -l < "$OUT" | tr -d ' ') 行）"
