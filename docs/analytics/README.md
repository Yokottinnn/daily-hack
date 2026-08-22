# ブログ分析（アクセス数・SEO順位）まとめ

Daily Hack のアクセス/SEO分析はここに集約する。

## 取り戻せないデータがある（最重要）

**Cloudflare Zone Analytics は 7 日より古いデータを返さない。** 実測での応答:

```text
zone "550e..." cannot request data older than 1w1d,
but your query requests data from 1w1d23h19s ago
```

つまり **週次で記録しなかった週の PV は、後から永久に取得できない。**
実際に **2026-08-16〜08-21 の PV は失われた**（`weekly-pv-report` が
`jq: Argument list too long` で落ちており、誰も気づかないまま 6 日経過した）。

| データ源 | 遡れる範囲 | 根拠 |
| --- | --- | --- |
| Cloudflare Zone Analytics | **7 日** | 実測（上記エラー） |
| Google Search Console | 未確認 | 実測していない。断定しない |
| GA4 | 未確認 | 同上 |
| 参照元（X からの遷移） | **取得不可** | 実測。`clientRefererHost` はスキーマにあるがプランが許可しない（`authz`） |

### だから、こう運用する

1. **毎週必ず記録する。** `weekly-pv-report` が月曜 07:00 JST に走り、
   `analytics/weekly` ブランチへスナップショットと `history.csv` を push する。
   `main` は保護ブランチのためデータ専用ブランチに積む。
2. **落ちたら気づけるようにする。** Slack 通知を必須化し、送れなければジョブを
   失敗させる。**黙ってスキップさせない**（`if:` で握り潰していたため、この
   ワークフローは一度も Slack に投稿できていなかった）。
3. **数字が 0 のときは「ゼロ」と言わない。** 取得失敗と区別できない値を
   実績として出さない。通知本文でも警告に切り替える。

### 記録の場所

| 何 | どこ |
| --- | --- |
| 週次スナップショット | `analytics/weekly` ブランチ `docs/analytics/weekly/YYYY-MM-DD.md` |
| 推移（1 行 1 週） | 同ブランチ `docs/analytics/weekly/history.csv` |
| 分析コメント付きの回 | このフォルダの `YYYY-MM-DD-report.md` |

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
