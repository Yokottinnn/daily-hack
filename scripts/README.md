# scripts

## weekly_pv_report.py

GA4 Data API から直近7日間（UTC、終端=昨日）のPV/アクティブユーザー/セッション/上位ページ/国別/流入元を取得し、Slack `#fun_reward-hack-blog` に Incoming Webhook で投稿する。

実行は `.github/workflows/weekly-pv-report.yml` で **毎週月曜 09:00 JST** に自動起動。
GitHub Actions の `workflow_dispatch` から手動実行も可（`dry_run: true` で Slack 投稿なし、標準出力のみ）。

### 必要な GitHub Secrets

| Secret | 説明 | 取得元 |
|---|---|---|
| `GA4_PROPERTY_ID` | GA4 プロパティID（数値、例 `123456789`） | GA4 → 管理（左下歯車）→ プロパティ設定 → 「プロパティID」 |
| `GA4_SERVICE_ACCOUNT_JSON` | Google Cloud Service Account の JSON 秘密鍵（中身を丸ごと） | Google Cloud Console → IAM & Admin → Service Accounts → 作成 → Keys → Add key → JSON |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | api.slack.com/apps → Create New App → Incoming Webhooks → Add Webhook to Workspace → `#fun_reward-hack-blog` |

### Service Account に必要な権限

1. Google Cloud Console で Service Account を作成（権限はプロジェクト側は不要）
2. JSON 鍵を発行してダウンロード（中身を丸ごと GH Secret `GA4_SERVICE_ACCOUNT_JSON` に貼る）
3. **GA4 ダッシュボードで該当プロパティに Service Account の email を「閲覧者」として追加**
   - GA4 → 管理 → アカウント アクセス管理 or プロパティ アクセス管理 → 「+」→ ユーザーを追加 → Service Account の email (`xxx@xxx.iam.gserviceaccount.com`) を入力 → 役割: 閲覧者
4. Google Analytics Data API の有効化（Google Cloud Console → APIs & Services → Library → "Google Analytics Data API" → Enable）

### Slack Incoming Webhook の作り方

1. https://api.slack.com/apps を開いて「Create New App」→ From scratch
2. App 名（例: `daily-hack-reporter`）と Workspace を指定
3. 作成後の左メニュー「Incoming Webhooks」→ Activate Incoming Webhooks を ON
4. 「Add New Webhook to Workspace」→ チャンネル `#fun_reward-hack-blog` を選択 → Allow
5. 生成された Webhook URL を GH Secret `SLACK_WEBHOOK_URL` に設定

### ローカル動作確認

```bash
pip install -r scripts/requirements.txt
export GA4_PROPERTY_ID=123456789
export GA4_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
python scripts/weekly_pv_report.py
```

### コスト
- GA4 Data API: 無料（プロパティあたり 1日10万トークン、本レポートは1回数十トークン程度）
- GitHub Actions: 無料枠内
- Slack Incoming Webhook: 既存ワークスペース利用、追加コストなし

**合計コスト: 0円**
