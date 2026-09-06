#!/bin/bash
# **新しい週次レポートを実機で 1 回だけ走らせて、結果をブランチに置く。**
# **Slack には出さない。** launchd の設定も変えない。まず動くかを見る。
#
# ## なぜ
#
# `scripts/weekly-blog-report.py` を新規に書いたが、**クラウドセッションからは
# Cloudflare にも GSC にも到達できない**（外部通信が塞がれている）ため、
# 偽データでの整形テストしか通っていない。
#
# 実機で確かめたいのは 3 点。
#
# 1. **Cloudflare の API トークンがどこにあるか。** 無ければレポートがそう言う
# 2. **`rumPageloadEventsAdaptiveGroups` が siteTag で引けるか。**
#    ビーコンは入っている（BaseLayout.astro:106）が、GraphQL 側の呼び方は
#    ドキュメントを読んで書いたもので、実物では未検証
# 3. GSC 側が `seo-rankings.py` と同じ経路で通るか
#
# **失敗しても壊れない。** レポートは節ごとに理由を書いて出るように作ってある。
#
# ## やること
#
# 1. 新しいスクリプトを実行して Markdown をファイルに書く
# 2. その Markdown をブランチへ push する
# 3. 終了コードも残す（取れなかったものがあれば 1 で落ちる仕様）
#
# **Slack へは投稿しない**（`--slack` を付けない）。既存の週次ジョブも触らない。
#
# LLM 不使用・$0/回・$0/日・$0/月（GSC API も Cloudflare API も無料）

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

OUT="reports/t053-weekly-report-sample.md"
mkdir -p reports

# gcloud は Python 3.9 では動かない。3.11 以上を明示的に選ぶ。
PY=""
for c in /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 \
         /usr/local/bin/python3.12 /usr/local/bin/python3.11 python3; do
  if command -v "$c" >/dev/null 2>&1; then
    v=$("$c" -c 'import sys;print(sys.version_info>=(3,10))' 2>/dev/null)
    [ "$v" = "True" ] && PY="$c" && break
  fi
done
if [ -z "$PY" ]; then
  echo "Python 3.10 以上が見つからない" | tee "$OUT"
  exit 1
fi
echo "使う Python: $PY ($("$PY" -V 2>&1))"

"$PY" scripts/weekly-blog-report.py --out "$OUT"
RC=$?

{
  echo
  echo "---"
  echo "t053 実行メモ: Python=\`$("$PY" -V 2>&1)\` / 終了コード=\`$RC\`"
  echo "（終了コード 1 は「取れなかったものがある」の意味。レポート本文に理由が出る）"
} >> "$OUT"

echo "=== 生成結果 ==="
cat "$OUT"

git add "$OUT"
git -c user.name="OpenClaw" -c user.email="ops@fieldbeside.com" \
  commit -q -m "ops(t053): 新しい週次レポートを実機で1回走らせた（rc=$RC）" || true
git push -q origin HEAD:refs/heads/claude/t053-weekly-report-sample 2>&1 | tail -3

exit 0
