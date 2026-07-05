# ブログ分析（アクセス数・SEO順位）まとめ

Daily Hack のアクセス/SEO分析はここに集約する。

## どこで見る？
1. **このフォルダ `docs/analytics/`** … 週次スナップショット（`YYYY-MM-DD-report.md`）。数値が履歴として残る恒久版。
2. **Slack `#fun_reward-hack-blog`** … 毎週月曜 08:00 JST に自動投稿される週次レポート（流れる速報版）。
   - home-mac の launchd `com.dailyhack.weekly-blog-report`（`~/scripts/weekly-blog-report.py`）が生成。
3. **オンデマンド生成**（最新をその場で見る）:
   - SEO順位・検索流入: `python3 scripts/top-articles.py`（GSC・過去30日／ページ・クエリ別 クリック/表示/CTR/順位）
   - PV: GitHub Actions `weekly-pv-report`（Cloudflare・月曜 07:00）

## データ源
- **Google Search Console (GSC)** … 検索順位・表示回数・クリック・CTR。SA `gsc-bot@daily-hack-blog` を gcloud impersonation で。
- **Cloudflare Analytics** … 実PV（`httpRequestsAdaptiveGroups`, eyeball, 200）。
- **GA4** … フロント計測のみ（詳細はGA Web UI）。

## 運用ルール（Jordan指定 2026-07-05）
- **週1**で分析（毎週月曜、Slack自動＋このフォルダにスナップショット追記）。
- 見る観点: ①相対的な人気/惜しい記事 ②勝ちパターン（長尾/具体語） ③改善対象（表示あり×順位あと一歩） ④狙い目クエリ。
