# scripts

## weekly_pv_report.py

GA4 Data API から直近7日間（UTC、終端=昨日）の PV / アクティブユーザー / セッション / TOP10ページ / 国別TOP5 / 流入元TOP5 を取得し、Slack `#fun_reward-hack-blog` に Incoming Webhook で投稿する。

実行は `.github/workflows/weekly-pv-report.yml` で **毎週月曜 09:00 JST** に自動起動。`workflow_dispatch` から手動実行も可（`dry_run: true` で Slack 投稿なし）。

### 必要な GitHub Secrets

| Secret | 説明 |
|---|---|
| `GA4_PROPERTY_ID` | GA4 プロパティID（数値） |
| `GA4_SERVICE_ACCOUNT_JSON` | Google Cloud SA の JSON 秘密鍵（中身を丸ごと文字列で） |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |

### セットアップ手順（Jordan 用、簡素版）

#### Step 1: 組織ポリシーを無効化（3クリック・3分）

1. https://console.cloud.google.com/iam-admin/orgpolicies/iam-disableServiceAccountKeyCreation を開く
2. 右上「**Manage policy**」または「**ポリシーを編集**」をクリック
3. 「**Override parent's policy / 親のポリシーをオーバーライド**」を選択 → 「**Off / オフ**」 → **Save**

#### Step 2: Service Account 作成 + JSON 鍵ダウンロード（5分）

1. https://console.cloud.google.com/iam-admin/serviceaccounts でプロジェクトを選択
2. 「**+ サービスアカウントを作成**」→ 名前 `daily-hack-pv-reporter` → 作成
3. 作った SA をクリック → 上部「**キー**」タブ → **「鍵を追加」→「新しい鍵を作成」→「JSON」**
4. JSON ファイルが自動ダウンロードされる（中身を丸ごとコピー、後で GH Secret に貼る）
5. SA の email (`xxx@xxx.iam.gserviceaccount.com`) も控える

#### Step 3: GA4 と GH Secrets を設定（5分）

1. https://console.cloud.google.com/apis/library/analyticsdata.googleapis.com で **Google Analytics Data API** を **Enable**
2. https://analytics.google.com → 管理（左下歯車）→ プロパティ アクセス管理 → 「+」→ 上記 SA の email を「**閲覧者**」で追加
3. GA4 のプロパティID（数値）を控える: 管理 → プロパティ設定 → プロパティID
4. https://api.slack.com/apps で Slack App 作成 → Incoming Webhooks ON → Add to Workspace → `#fun_reward-hack-blog` → URL コピー
5. https://github.com/Yokottinnn/daily-hack/settings/secrets/actions に3つ追加:
   - `GA4_PROPERTY_ID` (数値)
   - `GA4_SERVICE_ACCOUNT_JSON` (JSON 中身丸ごと)
   - `SLACK_WEBHOOK_URL` (URL)

### コスト
- すべて無料枠（GA4 Data API / GitHub Actions / Slack Incoming Webhook）
- 合計: **0円**
