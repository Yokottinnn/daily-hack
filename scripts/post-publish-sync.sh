#!/usr/bin/env bash
# post-publish-sync.sh — ブログ公開（main merge）後に必ず実行する記事DB同期＋検証ゲート。
#
# 役割:
#   1) article-db-sync.py を実行し、Google Sheet「Daily Hack 記事DB」を最新の posts/*.md に同期
#   2) posts/*.md の件数と Sheet「公開済記事」タブの件数を突合し、ドリフトがあれば ❌ で警告
#
# 使い方:  bash scripts/post-publish-sync.sh
# 前提:   gcloud auth ログイン済（切れていたら `gcloud auth login` を促す）
set -euo pipefail
cd "$(dirname "$0")/.."

SID="1cCqUpQoD0oNYkT8xmZvDKu9JlCL5pfdNkLkcraWS5nY"
SA="gsc-bot@daily-hack-blog.iam.gserviceaccount.com"
SA_KEY="$HOME/.config/daily-hack/gsc-bot-key.json"

# 0) 認証チェック — SAキー直認証（ユーザーOAuth不要・失効なし）
#    SAトークンが取れなければ、キーから自動アクティブ化を試みる。
if ! gcloud auth print-access-token --account="$SA" --scopes=https://www.googleapis.com/auth/spreadsheets >/dev/null 2>&1; then
  if [ -f "$SA_KEY" ]; then
    echo "▶ SAキーを再アクティブ化..."
    gcloud auth activate-service-account --key-file="$SA_KEY" >/dev/null 2>&1
  fi
  if ! gcloud auth print-access-token --account="$SA" --scopes=https://www.googleapis.com/auth/spreadsheets >/dev/null 2>&1; then
    echo "❌ SAキー認証に失敗。 $SA_KEY を確認してください（再生成は docs 参照）。"
    exit 1
  fi
fi

# 1) 同期
echo "▶ 記事DB同期を実行..."
python3 scripts/article-db-sync.py | tail -8

# 2) ドリフト検証（posts件数 vs Sheet公開済記事件数）
LOCAL=$(ls src/content/posts/*.md | wc -l | tr -d ' ')
TOK=$(gcloud auth print-access-token --account="$SA" --scopes=https://www.googleapis.com/auth/spreadsheets 2>/dev/null)
SHEET_ROWS=$(curl -s -H "Authorization: Bearer $TOK" \
  "https://sheets.googleapis.com/v4/spreadsheets/$SID/values/%E5%85%AC%E9%96%8B%E6%B8%88%E8%A8%98%E4%BA%8B" \
  | python3 -c "import sys,json; print(max(0,len(json.load(sys.stdin).get('values',[]))-1))")

echo ""
echo "── 検証 ──"
echo "  posts/*.md         : $LOCAL 件"
echo "  Sheet 公開済記事    : $SHEET_ROWS 件"
if [ "$LOCAL" = "$SHEET_ROWS" ]; then
  echo "✅ 一致。記事DB（公開済記事タブ）は最新です。"
else
  echo "❌ 不一致！ posts と Sheet がずれています。article-db-sync を再確認してください。"
  exit 2
fi
