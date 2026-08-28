#!/bin/bash
# 掲載順位（GSC）を実測する。**019 の再実行版**（done マーカーが残るため番号を変えている）。
#
# 016 が残した reports/seo-rankings-diag.md にこう出ていた。
#
#   ERROR: gcloud failed to load. You are running gcloud with Python 3.9,
#   which is no longer supported by gcloud.
#
# gcloud 本体は /opt/homebrew/bin/gcloud で見つかっていた。**PATH は原因ではなかった。**
# gcloud が自前で拾う Python がシステムの 3.9 だったのが原因で、
# CLOUDSDK_PYTHON に 3.10 以上を渡せば通る。
#
# GSC API は無料。LLM を呼ばないため API クレジットは消費しない。
# **秘密を出力しないこと。** アクセストークンは一切表示しない。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/seo-rankings.md"
DIAG="$RDIR/seo-rankings-diag.md"
TMP="${TMPDIR:-/tmp}/seo-rankings-$$.py"
ERR="${TMPDIR:-/tmp}/seo-rankings-$$.err"

scrub() { sed -E 's/ya29\.[A-Za-z0-9._-]+/<TOKEN>/g; s/[A-Za-z0-9_-]{40,}/<REDACTED>/g'; }

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:scripts/seo-rankings.py > "$TMP" 2>/dev/null || [ ! -s "$TMP" ]; then
  echo "origin/main から scripts/seo-rankings.py を取り出せない"; rm -f "$TMP"; exit 1
fi

PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 /opt/homebrew/bin/python3.12; do
  [ -x "$c" ] && { PY="$c"; break; }
done
[ -n "$PY" ] || PY="$(command -v python3 || true)"
[ -n "$PY" ] || { echo "python3 が見つからない"; rm -f "$TMP"; exit 1; }

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/google-cloud-sdk/bin:$PATH"
# gcloud に 3.9 を拾わせない。スクリプト側でも設定するが、ここでも保険をかける。
export CLOUDSDK_PYTHON="$PY"

if "$PY" "$TMP" --days 28 --min-impressions 1 --top 10 --out "$OUT" 2>"$ERR"; then
  rm -f "$TMP" "$ERR" "$DIAG"
  echo "書き出した: reports/seo-rankings.md（$(wc -l < "$OUT" | tr -d ' ') 行）"
  exit 0
fi

{
  echo "# 順位取得の診断（$(date -u +%Y-%m-%dT%H:%M:%SZ) / v3）"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| python | \`$PY\` |"
  echo "| CLOUDSDK_PYTHON | \`$CLOUDSDK_PYTHON\` |"
  echo "| gcloud | \`$(command -v gcloud || echo 見つからない)\` |"
  echo
  echo "## gcloud のアカウント一覧"
  echo
  echo '```'
  gcloud auth list --format='value(account,status)' 2>&1 | scrub | head -10
  echo '```'
  echo
  echo "## 実行時のエラー（全文）"
  echo
  echo '```'
  scrub < "$ERR" | tail -40
  echo '```'
} > "$DIAG"

echo "取得に失敗。診断を reports/seo-rankings-diag.md に更新: $(tail -1 "$ERR" | scrub | cut -c1-160)"
rm -f "$TMP" "$ERR"
exit 1
