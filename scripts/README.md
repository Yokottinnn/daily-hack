# scripts

## weekly_pv_report.py

Cloudflare Web Analytics GraphQL API から直近7日間の PV / 訪問 / TOP10ページ / 国別TOP5 / 流入元TOP5 を取得し、Slack `#fun_reward-hack-blog` に Incoming Webhook で投稿する。標準ライブラリのみ（依存ゼロ）。

実行は `.github/workflows/weekly-pv-report.yml` で **毎週月曜 09:00 JST** に自動起動。`workflow_dispatch` から手動実行も可（`dry_run: true` で Slack 投稿なし、標準出力のみ）。

### 必要な GitHub Secrets

| Secret | 説明 | 取得元 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | CF API トークン（Account Analytics:Read 以上） | dash.cloudflare.com → My Profile → API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | CF アカウントID | dash URL `/accounts/<ここ>/` （workflow 内で CLOUDFLARE_ACCOUNT_TAG にエイリアス） |
| `CLOUDFLARE_SITE_TAG` | CF Web Analytics サイトのトークン（= BaseLayout beacon の token） | dash → Analytics → Web Analytics → 該当サイト → URL の siteTag |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL | api.slack.com/apps → Create New App → Incoming Webhooks → Add to Workspace → `#fun_reward-hack-blog` |

### Daily Hack 専用サイトの追加（初回 1 回だけ）

現在の `BaseLayout.astro` のビーコントークン `0dc312c59cff43f58507d2b4f669dd82` は orphan（Jordan の CF アカウントに紐づいてない）。新規に daily-hack.fieldbeside.com サイトを Web Analytics に追加する必要あり:

1. dash.cloudflare.com → Analytics → Web Analytics
2. 「Add a site」または「+ サイトを追加」
3. Hostname: **daily-hack.fieldbeside.com**
4. プラン「Free」を選択
5. 表示される `data-cf-beacon='{"token":"..."}'` の **token を控える**（32文字hex）
6. その token を `BaseLayout.astro` の `data-cf-beacon` の値に書き換える（別 PR で対応）
7. 同じ token を `CLOUDFLARE_SITE_TAG` GH Secret として登録

### コスト
- すべて無料枠（CF Web Analytics / GitHub Actions / Slack Incoming Webhook）
- 合計: **0円**
