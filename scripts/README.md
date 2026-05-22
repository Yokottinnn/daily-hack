# scripts

## weekly_pv_report.py

GA4 Data API から直近7日間（UTC、終端=昨日）のPV/アクティブユーザー/セッション/上位ページ/国別/流入元を取得し、Slack `#fun_reward-hack-blog` に Incoming Webhook で投稿する。

実行は `.github/workflows/weekly-pv-report.yml` で **毎週月曜 09:00 JST** に自動起動。
GitHub Actions の `workflow_dispatch` から手動実行も可（`dry_run: true` で Slack 投稿なし、標準出力のみ）。

認証は **Workload Identity Federation (WIF)** を使う設計。GCP の組織ポリシー `iam.disableServiceAccountKeyCreation` が JSON 鍵生成を禁じているため、長期 JSON 鍵を作らずに GitHub Actions の OIDC トークンで Service Account を impersonate する方式。

### 必要な GitHub Secrets

| Secret | 説明 | 取得元 |
|---|---|---|
| `GA4_PROPERTY_ID` | GA4 プロパティID（数値、例 `123456789`） | GA4 → 管理（左下歯車）→ プロパティ設定 → 「プロパティID」 |
| `GCP_WIF_PROVIDER` | Workload Identity Provider のフルリソース名（`projects/<NUM>/locations/global/workloadIdentityPools/<POOL>/providers/<PROVIDER>`） | 下記 WIF セットアップ後にコピー |
| `GCP_SA_EMAIL` | impersonate する Service Account の email | 下記 WIF セットアップで作成した SA の email |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | api.slack.com/apps → Create New App → Incoming Webhooks → Add Webhook to Workspace → `#fun_reward-hack-blog` |

### Workload Identity Federation セットアップ（Jordan 側、初回 1 回だけ）

`gcloud` CLI（または GCP コンソール）で次のリソースを作る。プロジェクトIDは Jordan の任意の GCP プロジェクト（GA4 と分離して問題なし）。

```bash
PROJECT_ID="<your-gcp-project-id>"
PROJECT_NUMBER="$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')"
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SA_NAME="daily-hack-pv-reporter"
REPO="Yokottinnn/daily-hack"

# 1. Data API 有効化
gcloud services enable analyticsdata.googleapis.com --project=${PROJECT_ID}

# 2. Service Account を作成（JSON 鍵は不要）
gcloud iam service-accounts create ${SA_NAME} \
  --project=${PROJECT_ID} \
  --display-name="Daily Hack PV Reporter"

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "SA_EMAIL=${SA_EMAIL}  # ← これを GCP_SA_EMAIL secret に"

# 3. Workload Identity Pool 作成
gcloud iam workload-identity-pools create ${POOL_ID} \
  --project=${PROJECT_ID} \
  --location="global" \
  --display-name="GitHub Pool"

# 4. GitHub OIDC Provider 作成
gcloud iam workload-identity-pools providers create-oidc ${PROVIDER_ID} \
  --project=${PROJECT_ID} \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.actor=assertion.actor" \
  --attribute-condition="assertion.repository == '${REPO}'"

# 5. GitHub repo に SA を impersonate する権限を付与
gcloud iam service-accounts add-iam-policy-binding ${SA_EMAIL} \
  --project=${PROJECT_ID} \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${REPO}"

# 6. WIF Provider のフルリソース名を表示
echo "GCP_WIF_PROVIDER=projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}  # ← これを GCP_WIF_PROVIDER secret に"
```

### GA4 プロパティに Service Account を閲覧者として追加

1. https://analytics.google.com → 管理（左下歯車）
2. **「プロパティ アクセス管理」** → 右上の青い「+」→ 「ユーザーを追加」
3. 上記 `${SA_EMAIL}` を入力 → 役割: **「閲覧者」** → 追加

### Slack Incoming Webhook の作り方

1. https://api.slack.com/apps を開いて「Create New App」→ From scratch
2. App 名（例: `daily-hack-reporter`）と Workspace を指定
3. 作成後の左メニュー「Incoming Webhooks」→ Activate Incoming Webhooks を ON
4. 「Add New Webhook to Workspace」→ チャンネル `#fun_reward-hack-blog` を選択 → Allow
5. 生成された Webhook URL を GH Secret `SLACK_WEBHOOK_URL` に設定

### ローカル動作確認（任意）

ローカルで動かす場合は、JSON 鍵が使えない環境では `gcloud auth application-default login` で ADC を発行する手があるが、ローカルでは簡単のため別途 JSON を渡す手も:

```bash
pip install -r scripts/requirements.txt
export GA4_PROPERTY_ID=123456789
export GA4_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'  # 任意・WIF未設定環境のみ
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
python scripts/weekly_pv_report.py
```

### コスト
- GA4 Data API: 無料（プロパティあたり 1日10万トークン）
- GitHub Actions: 無料枠内
- Workload Identity Federation: 無料
- Slack Incoming Webhook: 既存ワークスペース利用、追加コストなし

**合計コスト: 0円**
