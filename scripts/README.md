# scripts

## weekly_pv_report.py

Cloudflare Web Analytics の GraphQL API から直近7日間のPV/UV/上位ページ/国別/流入元を取得し、
Slack `#fun_reward-hack-blog` (C0B4CJHH797) に投稿する。

実行は `.github/workflows/weekly-pv-report.yml` で **毎週月曜 09:00 JST** に自動起動。
GitHub Actions の `workflow_dispatch` から手動実行も可（`dry_run: true` で Slack 投稿なし、標準出力のみ）。

### 必要な GitHub Secrets

| Secret | 説明 | 取得元 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | CF API トークン（`Account Analytics:Read` スコープのみで十分） | dash.cloudflare.com → My Profile → API Tokens → Create Token |
| `CLOUDFLARE_ACCOUNT_ID` | CF アカウントID | dash.cloudflare.com の URL `/accounts/<ここ>/` （workflow 内で `CLOUDFLARE_ACCOUNT_TAG` にエイリアス） |
| `CLOUDFLARE_SITE_TAG` | Web Analytics サイトの UUID | dash → Analytics → Web Analytics → 該当サイトを開いた URL の `site/<ここ>/` |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | api.slack.com/apps → Create New App → Incoming Webhooks → Add New Webhook to Workspace → #fun_reward-hack-blog を選択 → `https://hooks.slack.com/services/...` |

### Slack Incoming Webhook の作り方（最小手順）
1. https://api.slack.com/apps を開いて「Create New App」→ From scratch
2. App 名（例: `daily-hack-reporter`）と Workspace を指定
3. 作成後の左メニュー「Incoming Webhooks」→ Activate Incoming Webhooks を ON
4. 「Add New Webhook to Workspace」→ チャンネル `#fun_reward-hack-blog` を選択 → Allow
5. 生成された Webhook URL を GH Secret `SLACK_WEBHOOK_URL` に設定

### ローカル動作確認

```bash
export CLOUDFLARE_API_TOKEN=xxx
export CLOUDFLARE_ACCOUNT_TAG=xxx
export CLOUDFLARE_SITE_TAG=xxx
export SLACK_BOT_TOKEN=xoxb-xxx
python scripts/weekly_pv_report.py
```

### コスト
- Cloudflare Web Analytics: 無料（30日リテンション）
- Cloudflare GraphQL API: 無料
- GitHub Actions: パブリックリポジトリは無制限。プライベートでも月2,000分まで無料
- Slack: 既存ワークスペース利用、追加コストなし

**合計コスト: 0円**
