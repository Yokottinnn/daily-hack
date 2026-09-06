#!/bin/bash
# **新しい週次レポートを実機で 1 回だけ走らせて、結果を残す。**
# **Slack には出さない。launchd も触らない。** まず動くかを見る。
#
# ## t053 の焼き直し。t053 は自分のバグで何も残せなかった
#
# t053 はリポジトリの場所を `$(dirname "$0")/../..` で求めていた。
# **ランナーはタスクを `/tmp/ops-tasks/` にコピーして実行する**ため、
# `$0` はリポジトリの中を指さない。`cd /` した状態で
# `python3 scripts/weekly-blog-report.py` を叩き、**ファイルが無くて
# 終了コード 2**（Python の「ファイルを開けない」）で終わっていた。
#
# 今回は `$REPO` から `origin/main` の中身を直接取り出して走らせる。
# **スクリプトは 1 ファイルで完結している**ので worktree は要らない。
#
# ## 実機で確かめたいこと
#
# 1. **Cloudflare の API トークンがどこにあるか。** 無ければレポートがそう言う
# 2. **`rumPageloadEventsAdaptiveGroups` が siteTag で引けるか。**
#    ビーコンは入っている（BaseLayout.astro:106）が、GraphQL 側の呼び方は
#    ドキュメントを読んで書いたもので、実物では未検証
# 3. GSC 側が `seo-rankings.py` と同じ経路で通るか
#
# **失敗しても壊れない。** レポートは節ごとに理由を書いて出るように作ってある。
#
# LLM 不使用・$0/回・$0/日・$0/月（GSC API も Cloudflare API も無料）

set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t055-weekly-report-sample.md"
mkdir -p "$RDIR"

[ -d "$REPO/.git" ] || { echo "リポジトリが無い: $REPO"; exit 1; }
git -C "$REPO" fetch -q origin main || { echo "fetch 失敗"; exit 1; }

SCRIPT="${TMPDIR:-/tmp}/weekly-blog-report.py"
git -C "$REPO" show origin/main:scripts/weekly-blog-report.py > "$SCRIPT" || {
  echo "scripts/weekly-blog-report.py を origin/main から取れない"; exit 1; }
[ -s "$SCRIPT" ] || { echo "スクリプトが空"; exit 1; }

# gcloud は Python 3.9 では動かない。3.10 以上を明示的に選ぶ。
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 \
         /usr/local/bin/python3.12 /usr/local/bin/python3.11 python3; do
  command -v "$c" >/dev/null 2>&1 || continue
  if [ "$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)" = "True" ]; then
    PY="$c"; break
  fi
done
[ -n "$PY" ] || { echo "Python 3.10 以上が見つからない"; exit 1; }
echo "使う Python: $PY ($("$PY" -V 2>&1))"

"$PY" "$SCRIPT" --out "$OUT"
RC=$?

{
  echo
  echo "---"
  echo "t055 実行メモ: Python=\`$("$PY" -V 2>&1)\` / 終了コード=\`$RC\`"
  echo "（1 は「取れなかったものがある」の意味。本文の各節に理由が出る）"
} >> "$OUT"

echo "=== 生成結果（先頭 80 行）==="
head -80 "$OUT"
echo "=== rc=$RC ==="
exit 0
