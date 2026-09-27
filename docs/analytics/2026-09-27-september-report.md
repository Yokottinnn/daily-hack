# 2026 年 9 月 月次レポート（手で出したもの）

> **月次の仕組みは無い。** 在るのは週次だけ。利用者の依頼（2026-09-27）で手で出した。
> 定期化するかは未決。

- 作成: **2026-09-27**
- 窓: **2026-09-01 00:00 UTC 〜 2026-09-27 00:00 UTC（26 日）**
- 一次情報: Cloudflare Zone Analytics
  （[run 36301127626](https://github.com/Yokottinnn/daily-hack/actions/runs/36301127626)）／
  Google Search Console（`reports/t195-september-report.md` on `ops/heartbeat`）

## ⚠️ この月に見つかった不具合 2 件

**どちらも「黙って間違った数字を出していた」ものなので、先に書く。**

### ① 週次の PV レポートが 2 週間 以上 落ちていた（直した・PR #741）

`weekly-pv-report` が **9/14・9/21 とも失敗**していた。原因は
累積 JSON を `jq --argjson` で渡していたこと（`jq: Argument list too long`）。
**Actions は赤くなっていたが、誰も見ていなかった。**

### ② PV の総数が下限値だった（直した・PR #743）

`httpRequestsAdaptiveGroups` の `limit: 200` が**毎日 飽和**していた
（26 日で 198.6 行/日）。`orderBy: sum_visits_DESC` なので裾が毎日 切り捨てられていた。

上限を 5000 にして取り直した差。**上位記事の順位は変わらない。**

| | 壊れていた値 | 正しい値 | 差 |
| --- | --- | --- | --- |
| 総 visits | 11,702 | **13,778** | +2,076（+18%） |
| 総 requests | 12,472 | **21,503** | +9,031（**+72%**） |
| 全パス数 | 5,163 | **8,644** | +3,481 |

### ③ 週次レポートの PV（Web Analytics 側）は**まだ信用できない**

同じ 9 月について **Zone Analytics が visits 13,778、Web Analytics が PV 100。**
Web Analytics 側は記事ページの PV が 0、流入が直接 100%、desktop 100%、JP 60 / CN 40。
**実在のブログの数字に見えない。**

疑いは `weekly-blog-report.py` の `cf_site_tag()` が **site_tag を推測**していること
（`zone_name` 不一致なら `sites[0]`）。正解は `BaseLayout.astro` のビーコン token。
**測るタスク `t196` を出した（PR #745）。結果が出るまで、この PV は読まない。**

## 9 月の実績（Zone Analytics・26 日）

| 指標 | 値 |
| --- | --- |
| 総 visits | **13,778** |
| 総 requests | **21,503** |
| 1 日平均 visits | **530** |
| 全パス数 | 8,644 |

- 多い日: **9/6 1,692** ／ 9/11 806 ／ 9/19 726
- 少ない日: 9/26 122 ／ 9/23 236 ／ 9/10 254
  - **9/26 の 122 は集計途中の可能性がある**（他日の 1/4）。翌週に再確認する

### 8 月とは比べられない

**Cloudflare 無料プランの保持期間は 31 日（`4w3d`）。**
8/1〜8/27 を引くと、全日 `code: "quota"` で返る。

```
"message": "zone ... cannot request data older than 4w3d,
            but your query requests data from 8w1d6h40m8s ago"
```

**月次比較をしたいなら、毎月の数字をこのフォルダに残すしかない。**
（`docs/seo-monitoring.md` にも同じことが書いてある）

## 人気記事 TOP25（visits 順・9/1〜9/26）

| 順 | visits | requests | 記事 |
| --- | --- | --- | --- |
| 1 | 222 | 225 | `/posts/lalaport-guide-2026/` |
| 2 | 147 | 155 | `/posts/ikea-toyosu-2026/` |
| 3 | 134 | 141 | `/posts/morning-500-2026/` |
| 4 | 103 | 108 | `/posts/walk-poikatsu-2026/` |
| 5 | 89 | 89 | `/posts/sauna-openings-2026/` |
| 6 | 86 | 93 | `/posts/tokyo-discount-supermarket-2026/` |
| 7 | 85 | 87 | `/posts/outlet-mall-guide-2026/` |
| 8 | 72 | 72 | `/posts/credit-card-no-annual-fee-comparison-2026/` |
| 9 | 66 | 66 | `/posts/gyudon-chains-cashless-2026-jun/` |
| 10 | 61 | 62 | `/posts/tokyo-bay-hanabi-2026/` |
| 11 | 61 | 61 | `/posts/summer-cospa-travel-2026/` |
| 12 | 60 | 60 | `/posts/wangan-tower-construction-map-2026/` |
| 13 | 46 | 46 | `/posts/summer-travel-timesale-2026/` |
| 14 | 45 | 45 | `/posts/odaiba-drone-show-2026/` |
| 15 | 42 | 42 | `/posts/wangan-supermarkets-2026/` |
| 16 | 40 | 41 | `/posts/move-to-earn-poikatsu-apps-2026/` |
| 17 | 40 | 41 | `/posts/hoso-daigaku-gakuwari-2026/` |
| 18 | 37 | 37 | `/posts/wangan-august-events-2026/` |
| 19 | 33 | 33 | `/posts/point-exchange-route-2026/` |
| 20 | 28 | 30 | `/posts/furusato-tax-2026-reform-guide/` |
| 21 | 27 | 27 | `/posts/wangan-saving-spots-2026/` |
| 22 | 24 | 24 | `/posts/budget-overseas-resorts-2026/` |
| 23 | 23 | 24 | `/posts/mobility-cost-per-km-2026/` |
| 24 | 23 | 25 | `/posts/amazon-prime-day-rakuten-ss-2026/` |
| 25 | 22 | 22 | `/posts/point-service-complete-guide-2026/` |

## 検索（GSC・8/29〜9/24 の 27 日）

**スクリプトに月の境目で切る機能が無いため日数で近似**している。
GSC は確定まで 2〜3 日かかるので直近 3 日を除いてある。

| 指標 | 9 月ぶん（8/29〜9/24） | その前（7/30〜8/28・引き算） | 動き |
| --- | --- | --- | --- |
| 表示 | **1,178** | 648 | **+82%** |
| クリック | **28** | 32 | **−12%** |
| CTR | **2.4%** | 4.9% | **半分になった** |
| 平均掲載順位 | 8.3 位 | — | 悪化 0.1 |
| 検索に出た記事数 | 65 | — | |

### ここが 9 月のいちばんの課題

**表示は 1.8 倍 に伸びたのに、クリックは減っている。**
順位帯を見ると **4〜10 位に 53 記事・表示 1,064** が溜まっていて、
**1 ページ目の下のほうに並んでいるがクリックされていない。**

| 順位帯 | 記事数 | 表示合計 |
| --- | --- | --- |
| 1〜3 位 | 4 | 7 |
| **4〜10 位** | **53** | **1,064** |
| 11〜20 位 | 5 | 96 |
| 21 位以下 | 3 | 11 |

`lalaport-guide-2026` が **8.6 位・表示 562・クリック 21（CTR 3.7%）**で表示の約半分を占める。
8 月ぶん（引き算）では 439 表示・25 クリック（5.7%）だったので、**この記事の CTR が落ちている。**
順位ではなく**タイトルと説明文**の問題として扱うのが筋。

### 当たっている語は「ららぽーと 売上ランキング」系にほぼ一極集中

| 語 | 表示 | クリック | 平均順位 |
| --- | --- | --- | --- |
| ららぽーと 売上ランキング | 61 | 1 | 8.2 位 |
| ららぽーと売上ランキング | 26 | 0 | 8.0 位 |
| ららぽーと 店舗数ランキング | 13 | 0 | 10.5 位 |
| ららぽーと 売り上げランキング | 11 | 1 | 7.5 位 |
| ららぽーと 売上 | 10 | 0 | 7.6 位 |
| ららぽーと 売上 ランキング | 8 | 0 | 8.4 位 |

**表示があってクリックが 0 の語が並んでいる。** 順位は 7〜10 位で、
検索意図（ランキングそのものを見たい）に対して**スニペットが答えていない**と読める。

### 順位が大きく上がった記事

| 動き | 前回 | 今回 | 記事 |
| --- | --- | --- | --- |
| **↑ 89.0** | 100.0 位 | **11.0 位** | `/posts/paypay-card-gold-kaiaku-2026/` |
| **↑ 74.0** | 77.0 位 | **3.0 位** | `/posts/price-hike-2026-summer-defense/` |
| ↑ 2.4 | 6.4 位 | 4.0 位 | `/posts/wangan-august-events-2026/` |
| ↑ 2.2 | 10.5 位 | 8.3 位 | `/posts/furusato-tax-beginner-guide-2026/` |

### 下がった記事

| 動き | 前回 | 今回 | 記事 |
| --- | --- | --- | --- |
| ↓ 6.9 | 14.4 位 | 21.4 位 | `/posts/move-to-earn-poikatsu-apps-2026/` |
| ↓ 1.6 | 4.8 位 | 6.3 位 | `/posts/morning-500-2026/` |
| ↓ 1.5 | 5.5 位 | 7.0 位 | `/posts/credit-card-kaiaku-2026/` |
| ↓ 1.5 | 4.0 位 | 5.5 位 | `/posts/nisa-recommended-index-funds-2026/` |
| ↓ 1.3 | 2.4 位 | 3.7 位 | `/posts/gyudon-chains-cashless-2026-jun/` |

## コスト

**$0。** LLM 不使用。Cloudflare GraphQL・GSC API・GitHub Actions（public）はいずれも無料枠。

- 1 回あたり **$0**
- 1 日あたり **$0**
- 1 か月あたり **$0**

## 次にやると効くこと（未決・利用者の判断待ち）

1. **`t196` の結果を見て Web Analytics 側を直す。** PV の一次情報が 2 本 食い違っている状態を残さない
2. **ワークフローの失敗を検知する。** ②も①も「赤いのに誰も見ていない」で 2 週間 放置された
3. **`lalaport-guide-2026` のタイトルと説明文。** 表示 562・CTR 3.7%。順位ではなくスニペットの問題
4. **月次を定期化するか決める。** 保持 31 日なので、残さないと来月も 8 月比較ができない
