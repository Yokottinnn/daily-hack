#!/bin/bash
# 掲載順位（GSC）を実測する。**015 が rc=1 で落ちたのでその修正版。**
#
# 015 の失敗は `heartbeat.json` の 300 字制限で切れており、
# 見えたのは subprocess の CalledProcessError の途中だけだった。
# 原因は gcloud の呼び出しにあるが、**何が起きたかが読めなかった。**
# ここでは失敗しても診断を reports/ に残す。
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

# 秘密が混ざらないよう、出力は必ずここを通す
scrub() { sed -E 's/ya29\.[A-Za-z0-9._-]+/<TOKEN>/g; s/[A-Za-z0-9_-]{40,}/<REDACTED>/g'; }

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:scripts/seo-rankings.py > "$TMP" 2>/dev/null || [ ! -s "$TMP" ]; then
  echo "origin/main から scripts/seo-rankings.py を取り出せない"; rm -f "$TMP"; exit 1
fi

PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 /usr/bin/python3; do
  [ -x "$c" ] && { PY="$c"; break; }
done
[ -n "$PY" ] || PY="$(command -v python3 || true)"
[ -n "$PY" ] || { echo "python3 が見つからない"; rm -f "$TMP"; exit 1; }

# launchd 経由は PATH が最小限になる。Homebrew と Cloud SDK を足しておく。
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/google-cloud-sdk/bin:$PATH"

GCLOUD="$(command -v gcloud || true)"

{
  echo "# 順位取得の診断（$(date -u +%Y-%m-%dT%H:%M:%SZ)）"
  echo
  echo "| 項目 | 値 |"
  echo "| --- | --- |"
  echo "| python | \`$PY\` |"
  echo "| gcloud | \`${GCLOUD:-見つからない}\` |"
  echo "| PATH | \`$(printf '%s' "$PATH" | cut -c1-200)\` |"
  echo "| HOME | \`${HOME/#\/Users\//~/}\` |"
  echo
  echo "## gcloud のアカウント一覧"
  echo
  echo '```'
  if [ -n "$GCLOUD" ]; then
    "$GCLOUD" auth list --format='value(account,status)' 2>&1 | scrub | head -10
  else
    echo "gcloud が PATH に無い"
  fi
  echo '```'
} > "$DIAG"

if "$PY" "$TMP" --days 28 --min-impressions 1 --top 10 --out "$OUT" 2>"$ERR"; then
  rm -f "$TMP" "$ERR"
  echo "書き出した: reports/seo-rankings.md（$(wc -l < "$OUT" | tr -d ' ') 行）"
  exit 0
fi

{
  echo
  echo "## 実行時のエラー（全文）"
  echo
  echo '```'
  scrub < "$ERR" | tail -40
  echo '```'
} >> "$DIAG"

echo "取得に失敗。診断を reports/seo-rankings-diag.md に書いた: $(tail -1 "$ERR" | scrub | cut -c1-160)"
rm -f "$TMP" "$ERR"
exit 1
