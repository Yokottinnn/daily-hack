# 一本化した週次レポートを Mac で実行する（t197・**$0**）

生成: **2026-09-27T16:49:58+0900**

- スクリプト **35455 bytes** / Zone Analytics 版であることを確認
- python: `/opt/homebrew/bin/python3.11`

終了コード **1**

### 標準エラー

```
書いた: /var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//t197-report.md

```

### 判定

| # | 見たこと | 結果 |
| --- | --- | --- |
| 1 | サマリーが「取得失敗」になっていない | ❌ |
| 2 | visits が 0 でない（**0**） | ❌ |
| 3 | 「実ブラウザ visits」の行が在る | ✅ |
| 4 | 流入経路が「取れない」と書かれている | ✅ |
| 5 | 人気ページに /posts/… が並ぶ（**32 行**） | ✅ |

### レポート本文（先頭 70 行）

```markdown
# Daily Hack 週次レポート（2026-09-27）

- アクセス: **2026-09-25 〜 2026-09-26**（2 日・Cloudflare Zone Analytics）
- 検索: **2026-09-18 〜 2026-09-24**（7 日・Search Console）
  ※ GSC は確定まで 2〜3 日かかるため直近 3 日を除いている

## サマリー

> **visits は読者数ではない。** ボットとクローラを含む。
> **読者に近いのは「実ブラウザ」の行。** 検索から来た実訪問は下の「検索クリック」を見る。

| 指標 | 今回 | 前回比 |
| --- | --- | --- |
| visits | ⚠️ 取得失敗 | Cloudflare GraphQL エラー（2026-09-25 / clientRequestPath）: Actor 'com.cloudflare.api.token.96de0c5f279d3893cb21cd4e7f80db4f |
| 実ブラウザ visits | ⚠️ 取得失敗 | 同上 |
| 検索クリック | 7 | -53（-88%） |
| 検索表示 | 266 | -1560（-85%） |
| 検索 CTR | 2.6% | |
| 平均掲載順位 | 9.3 位 | 悪化 0.6 |
| 検索に出た記事数 | 24 | |

## 流入経路

**Cloudflare では取れない。** リファラの次元（`clientRefererHost` /
`clientRequestReferer`）は無料プランで拒否される。

**検索からの流入は下の「検索クリック」と「検索順位 TOP10」を見ること。**

## 人気ページ TOP10（visits 順・**ボット込み**）

⚠️ **取れなかった。** Cloudflare GraphQL エラー（2026-09-25 / clientRequestPath）: Actor 'com.cloudflare.api.token.96de0c5f279d3893cb21cd4e7f80db4f' does not have permission 'com.cloudflare.api.account.zone.analytics.read' for zone 550e390d142924cebb45d6d401afe4cc

## 検索順位 TOP10（順位の高い順・表示 1 回以上）

| # | 平均順位 | 表示 | クリック | CTR | ページ |
| --- | --- | --- | --- | --- | --- |
| 1 | **2.0 位** | 1 | 0 | 0.0% | `/posts/wangan-august-events-2026/` |
| 2 | **3.0 位** | 2 | 0 | 0.0% | `/posts/price-hike-2026-summer-defense/` |
| 3 | **4.0 位** | 1 | 0 | 0.0% | `/posts/furusato-tax-beginner-guide-2026/` |
| 4 | **5.0 位** | 1 | 0 | 0.0% | `/posts/cheap-sim-speed-cost-2026/` |
| 5 | **6.4 位** | 5 | 0 | 0.0% | `/posts/narita-haneda-overseas-direct-2026/` |
| 6 | **6.9 位** | 8 | 0 | 0.0% | `/posts/tokyo-discount-supermarket-2026/` |
| 7 | **7.0 位** | 1 | 0 | 0.0% | `/posts/nisa-recommended-index-funds-2026/` |
| 8 | **7.0 位** | 1 | 0 | 0.0% | `/posts/wangan-sauna-2026/` |
| 9 | **7.9 位** | 7 | 0 | 0.0% | `/posts/wangan-supermarkets-2026/` |
| 10 | **8.0 位** | 3 | 0 | 0.0% | `/posts/wangan-tower-construction-map-2026/` |

## 順位帯ごとの記事数

| 順位帯 | 記事数 | 表示合計 |
| --- | --- | --- |
| 1〜3 位 | 2 | 3 |
| 4〜10 位 | 16 | 240 |
| 11〜20 位 | 3 | 13 |
| 21 位以下 | 3 | 10 |

## 惜しい記事（6〜20 位・表示 5 回以上＝あと一歩で 1 ページ目）

| 平均順位 | 表示 | クリック | ページ |
| --- | --- | --- | --- |
| 6.4 位 | 5 | 0 | `/posts/narita-haneda-overseas-direct-2026/` |
| 6.9 位 | 8 | 0 | `/posts/tokyo-discount-supermarket-2026/` |
| 7.9 位 | 7 | 0 | `/posts/wangan-supermarkets-2026/` |
| 8.6 位 | 165 | 4 | `/posts/lalaport-guide-2026/` |
| 8.6 位 | 8 | 0 | `/posts/ikea-toyosu-2026/` |
| 9.1 位 | 34 | 1 | `/posts/outlet-mall-guide-2026/` |
| 11.4 位 | 11 | 1 | `/posts/hoso-daigaku-gakuwari-2026/` |

## 順位が動いた記事（前回比）

```

---

> **⑤ が ❌ なら一本化は失敗。** RUM 時代と同じく記事ページが 0 のまま。

LLM 不使用。Cloudflare API・GSC API は無料枠。**$0/回・$0/日・$0/月。**
