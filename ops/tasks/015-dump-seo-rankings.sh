#!/bin/bash
# 掲載順位（GSC）を実測して報告に書き出す。
#
# **010 が失敗したのでその修正版。**
# 010 は Mac の作業ツリー（$REPO/scripts/seo-rankings.py）を読もうとしたが、
# ops-heartbeat は origin/main を fetch するだけで作業ツリーには反映しない。
# そのため `git pull が済んでいない可能性` で落ちた。
# ここでは heartbeat 自身がタスクを取り出すのと同じやり方で、
# **origin/main から直接スクリプトを取り出す。**
#
# GSC API は無料。LLM を呼ばないため API クレジットは消費しない。
# **秘密を出力しないこと。** 出るのは順位・表示・クリックと URL パス、検索クエリだけ。
set -uo pipefail

REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
OUT="${OPS_REPORT_DIR:-/tmp}/seo-rankings.md"
TMP="${TMPDIR:-/tmp}/seo-rankings-$$.py"
ERR="${TMPDIR:-/tmp}/seo-rankings-$$.err"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }

git -C "$REPO" fetch -q origin main 2>/dev/null || true
if ! git -C "$REPO" show origin/main:scripts/seo-rankings.py > "$TMP" 2>/dev/null || [ ! -s "$TMP" ]; then
  echo "origin/main から scripts/seo-rankings.py を取り出せない"
  rm -f "$TMP"; exit 1
fi

# gcloud/system python は 3.9 系。GSC 用に 3.11 を優先する。
PY=""
for c in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11 /usr/bin/python3; do
  [ -x "$c" ] && { PY="$c"; break; }
done
[ -n "$PY" ] || PY="$(command -v python3 || true)"
[ -n "$PY" ] || { echo "python3 が見つからない"; rm -f "$TMP"; exit 1; }

if ! "$PY" "$TMP" --days 28 --min-impressions 1 --top 10 --out "$OUT" 2>"$ERR"; then
  echo "取得に失敗（$PY）: $(tail -3 "$ERR" | tr '\n' ' ' | cut -c1-200)"
  rm -f "$TMP" "$ERR"; exit 1
fi
rm -f "$TMP" "$ERR"

echo "書き出した: reports/seo-rankings.md（$(wc -l < "$OUT" | tr -d ' ') 行）"
