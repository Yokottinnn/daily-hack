#!/bin/bash
# Daily Hack 記事公開スクリプト（OpenClaw用 / ガードレール6）
#
# 使い方:
#   ./scripts/blog-publish.sh <slug> "<title>"
#
# 動作:
#   1. ブランチを切る (post/YYYYMMDD-<slug>)
#   2. ローカルビルドで検証
#   3. 成功すればコミット → push → PR作成
#   4. 失敗すればエラーログを出力して終了（pushしない）

set -e

# 引数チェック
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <slug> <title>"
  echo "Example: $0 best-no-annual-fee-cards-2026 \"2026年最強の無料カード5選\""
  exit 1
fi

SLUG="$1"
TITLE="$2"
BRANCH_NAME="post/$(date +%Y%m%d)-${SLUG}"
POST_FILE="src/content/posts/${SLUG}.md"

# 作業ディレクトリを設定（OpenClawから呼ばれた時の安全策）
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

# 投稿ファイルが存在することを確認
if [ ! -f "${POST_FILE}" ]; then
  echo "❌ 投稿ファイルが見つかりません: ${POST_FILE}"
  echo "OpenClawは先に ${POST_FILE} を作成してからこのスクリプトを実行してください。"
  exit 1
fi

# 既存の post/ ブランチがあれば削除（再実行対応）
git branch -D "${BRANCH_NAME}" 2>/dev/null || true

# 新しいブランチを切る
git checkout -b "${BRANCH_NAME}"

# ローカルビルドで検証
echo "🔨 ローカルビルドで検証中..."
if npm run build > /tmp/blog-build.log 2>&1; then
  echo "✅ ビルド成功"
  git add "${POST_FILE}"
  # 関連アセット（eyecatch等）も自動で追加
  git add public/images/ 2>/dev/null || true
  git commit -m "Add post: ${TITLE}"
  git push -u origin "${BRANCH_NAME}"

  # gh CLI が使える場合は PR 作成
  if command -v gh > /dev/null 2>&1; then
    gh pr create \
      --title "${TITLE}" \
      --body "新規記事を投稿します。プレビューURLが Cloudflare Pages から発行されたら確認してください。" \
      --base main \
      --head "${BRANCH_NAME}"
    echo "✅ PR作成完了"
  else
    echo "⚠️  gh CLI未インストール。PRはWeb UIから手動で作成してください。"
    echo "Branch: ${BRANCH_NAME}"
  fi
else
  echo "❌ ビルド失敗。エラーログ（最後20行）:"
  tail -20 /tmp/blog-build.log
  echo ""
  echo "🔧 修正してから再実行してください。"
  echo "   完全なログ: /tmp/blog-build.log"
  # 失敗時はブランチをmainに戻す
  git checkout main 2>/dev/null || true
  git branch -D "${BRANCH_NAME}" 2>/dev/null || true
  exit 1
fi
