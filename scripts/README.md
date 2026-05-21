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
| `CLOUDFLARE_ACCOUNT_TAG` | CF アカウントID | dash.cloudflare.com の URL `/accounts/<ここ>/` |
| `CLOUDFLARE_SITE_TAG` | Web Analytics サイトの UUID | dash → Analytics → Web Analytics → 該当サイトを開いた URL の `site/<ここ>/` |
| `SLACK_BOT_TOKEN` | Slack Bot User OAuth Token | api.slack.com → Apps → 該当 App → OAuth & Permissions → `xoxb-...` |

オプションの GitHub Variables:
| Variable | 既定 | 説明 |
|---|---|---|
| `SLACK_CHANNEL_ID` | `C0B4CJHH797` | 投稿先チャンネル |

### Slack Bot に必要なスコープ
- `chat:write` （該当チャンネルに招待しておく）

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
