# SEO 監視の構成

最終更新: 2026-08-08

## なぜこれがあるのか（障害の記録）

**サイトマップが 2026-06-05 以降 Google に取得されず、163 URL が「Google が存在を知らない」まま約2ヶ月放置された。**

検知できなかった理由は2つ:

1. `.github/workflows/weekly-pv-report.yml` の Slack 通知ステップが
   `if: ${{ env.SLACK_WEBHOOK_URL != '' }}` という条件付きだったが、
   **`SLACK_WEBHOOK_URL` という Secret は一度も設定されていなかった**。
   → 作られた日から全実行で `skipped`。エラーにならずジョブは緑のままなので、
   「通知が来ない」ことに気づく手段がゼロだった。
2. 監視内容が Cloudflare の PV だけで、サイトマップ鮮度も Search Console も対象外。
   **仮に Slack が飛んでいても今回の障害は検知できなかった。**

> ⚠️ **`weekly-pv-report.yml` の Slack ステップは現在も残っているが死んでいる。**
> 削除には gh トークンの `workflow` スコープが必要で、2026-08-08 時点で付与されていないため
> 未対応。**このワークフローから Slack 通知は飛ばない。**Slack 通知は下記の launchd
> ジョブに一本化されている。修正版の YAML は作成済み。

## 現在の構成（二重の防御）

| | ジョブ | 頻度 | 役割 |
|---|---|---|---|
| **予防** | `ai.openclaw.sitemap-autosubmit` | 1日2回 07:40 / 19:40 JST | サイトマップの変化＝新記事を検知して GSC へ自動再送信 |
| **検知** | `ai.openclaw.seo-health` | 週1 月曜 08:10 JST | 万一予防が止まってもサイトマップ7日超で 🚨 |

どちらも `home-mac` の launchd で動く。GitHub Actions にしていない理由:

- `.github/workflows/` の変更に `workflow` スコープが必要で、現状それが無い
- デプロイ元が CI / OpenClaw / 手動 のどれでも等しくカバーできる
- Slack トークンと GSC SA キーが home-mac に既にあり Secret 複製が不要

### 実体

| ファイル | 説明 |
|---|---|
| `scripts/sitemap-autosubmit.py` | 予防側。sitemap の SHA256 が変われば GSC に PUT。無変化なら無音 |
| `scripts/seo-health-monitor.py` | 検知側。サイトマップ鮮度・GSC 指標・インデックス状況をレポート |
| `~/Library/LaunchAgents/ai.openclaw.sitemap-autosubmit.plist` | 予防側の launchd 定義 |
| `~/Library/LaunchAgents/ai.openclaw.seo-health.plist` | 検知側の launchd 定義 |
| `~/.config/daily-hack/gsc-bot-key.json` | GSC のサービスアカウント鍵 |
| `~/openclaw/config/.env` の `OPENCLAW_BOT_TOKEN` | Slack 投稿用 |
| `~/.config/daily-hack/*-state.json` | 前回比較用のスナップショット |

通知先 Slack チャンネル: `C0A5FKU7T5M`

## 検知項目と閾値（seo-health-monitor）

| 検知 | 閾値 |
|---|---|
| 🚨 サイトマップ最終取得 | 7日超（`STALE_DAYS`） |
| 🚨 登録URL数と実URL数の乖離 | 5%超（`URL_GAP_PCT`） |
| 🚨 表示回数の急減 | 前週比40%超減 |
| ⚠️ 未インデックス率の悪化 | 前回比10pt超 |

## 「沈黙して腐らない」ための設計

前回の失敗の本質は **「壊れても何も起きない」** ことだった。同じ轍を踏まないための担保:

| 失敗パターン | 対策 |
|---|---|
| 資格情報が無く静かに skip（**前回の原因**） | `skip` ではなく `exit 1` で落とす |
| 想定外の例外で沈黙 | `notify_failure()` で Slack に鳴らす |
| ハングして永久に鳴らない | インデックス走査に300秒の時間予算。超過時も必ず通知 |
| 毎回同じ記事だけ見て後半を見落とす | 順繰り走査（`scan_offset` を永続化） |
| 走査本数の差による誤警報 | 絶対数でなく未登録率で比較 |

## 動作確認のしかた

```bash
PY=/opt/homebrew/bin/python3.11   # gcloud/system python は 3.9 で google-auth が無い

# 予防側（送信せず差分だけ見る）
$PY scripts/sitemap-autosubmit.py --dry-run
$PY scripts/sitemap-autosubmit.py --force      # 変化が無くても強制送信

# 検知側（Slack に送らない／インデックス全走査を省略して高速）
$PY scripts/seo-health-monitor.py --dry-run --no-index

# 警報が実際に発火するかのテスト（閾値を反転させる）
sed 's/^STALE_DAYS = 7/STALE_DAYS = -1/' scripts/seo-health-monitor.py > /tmp/t.py
$PY /tmp/t.py --dry-run --no-index

# launchd 経由の実行確認
launchctl kickstart -k gui/$(id -u)/ai.openclaw.seo-health
launchctl print gui/$(id -u)/ai.openclaw.seo-health | grep -E 'state|runs|last exit'
tail -20 ~/.openclaw/workspace/logs/seo-health.log
```

> 監視を変更したら **必ず警報経路まで実走させて確認すること。**
> 「作った」だけで検証しないと、また静かに壊れた監視が増えるだけになる。

## 既知の未解決

- **IndexNow が 403**（`UserForbiddedToAccessSite`）。キーファイルは 200 で配信されているのに
  弾かれる。Cloudflare が検証 Bot をブロックしている可能性。Bing / Yandex への通知が効いていない
  （Yandex のみ 202 で受理される）。Google には影響しない。
- `scripts/seo-submit.mjs` はどのワークフローからも呼ばれていない。
- Cloudflare 無料プランの Analytics は **8日分しか保持しない**ため、PV の月次比較はできない。
  長期トレンドが要るなら別途蓄積が必要。
