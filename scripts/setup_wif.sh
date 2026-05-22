#!/usr/bin/env bash
# Daily Hack Weekly PV レポート用 GCP セットアップ (Workload Identity Federation)
# JSON 鍵を作らない方式なので組織ポリシー iam.disableServiceAccountKeyCreation の制約を回避
#
# 使い方:
#   1. gcloud CLI がない場合: brew install --cask google-cloud-sdk
#   2. gcloud auth login（ブラウザでログイン）
#   3. このスクリプト末尾の PROJECT_ID を編集して実行:
#      bash scripts/setup_wif.sh
#   4. 出力された GCP_WIF_PROVIDER / GCP_SA_EMAIL を GH Secrets に投入

set -euo pipefail

# ========= ここだけ書き換える =========
PROJECT_ID="${PROJECT_ID:-daily-hack-blog}"  # daily-hack 用 GCP プロジェクトID
# =====================================

POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SA_NAME="daily-hack-pv-reporter"
REPO="Yokottinnn/daily-hack"

echo "[1/5] プロジェクト確認..."
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"

echo "[2/5] Google Analytics Data API を有効化..."
gcloud services enable analyticsdata.googleapis.com --project="${PROJECT_ID}"

echo "[3/5] Service Account を作成..."
gcloud iam service-accounts create "${SA_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="Daily Hack PV Reporter" \
  || echo "  (既存の SA をそのまま使う)"

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "[4/5] Workload Identity Pool + GitHub OIDC Provider を作成..."
gcloud iam workload-identity-pools create "${POOL_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Pool" \
  || echo "  (既存の Pool をそのまま使う)"

gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository == '${REPO}'" \
  || echo "  (既存の Provider をそのまま使う)"

echo "[5/5] GitHub repo に SA impersonate 権限を付与..."
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${REPO}"

echo ""
echo "============================================="
echo "✅ セットアップ完了"
echo ""
echo "🔑 GH Secrets に投入する値:"
echo ""
echo "  GCP_SA_EMAIL"
echo "    = ${SA_EMAIL}"
echo ""
echo "  GCP_WIF_PROVIDER"
echo "    = projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo ""
echo "============================================="
echo ""
echo "📌 残作業:"
echo "  1. GA4 ダッシュボード → 管理 → プロパティアクセス管理 → 上記 SA email を「閲覧者」で追加"
echo "  2. GA4 → 管理 → プロパティ設定 → 「プロパティID」をメモ"
echo "  3. https://api.slack.com/apps で Slack App 作成 → Incoming Webhooks ON → #fun_reward-hack-blog 用 URL 取得"
echo "  4. https://github.com/${REPO}/settings/secrets/actions に下記4つを追加:"
echo "       - GA4_PROPERTY_ID         (プロパティID 数値)"
echo "       - GCP_WIF_PROVIDER        (上記 ↑)"
echo "       - GCP_SA_EMAIL            (上記 ↑)"
echo "       - SLACK_WEBHOOK_URL       (Webhook URL)"
