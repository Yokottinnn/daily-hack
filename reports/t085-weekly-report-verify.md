# 入れ替えた週次レポートは Mac で動くか（t085）

生成: **2026-09-15T02:23:14+0900**

## 1. `ALL_VISITS` を書いているファイルを探す

```
/Users/ny/scripts/weekly-blog-report.py
/Users/ny/scripts/__pycache__/weekly-blog-report.cpython-311.pyc
/Users/ny/.openclaw/ops-heartbeat-wt/reports/t085-weekly-report-verify.md
/Users/ny/.openclaw/ops-heartbeat-wt/reports/t054-weekly-report-dump.md
/Users/ny/.openclaw/ops-heartbeat-wt/reports/t080-weekly-report-truth.md
/Users/ny/.openclaw/ops-heartbeat-wt/reports/t084-install-weekly-report.md
```

（空なら、Slack の `${ALL_VISITS}` は Mac のこれらの場所から出ていない）

## 2. 新しい版を短い期間で 1 回 走らせる

| 項目 | 値 |
| --- | --- |
| 終了コード | **0**（0 = 全部 取れた / 1 = 取れないものがあった） |
| 所要 | 6 秒 |
| 出力の行数 | 95 |

### 出力の先頭 40 行

```
# Daily Hack 週次レポート（2026-09-15）

- アクセス: **2026-09-13 〜 2026-09-14**（2 日・Cloudflare Web Analytics）
- 検索: **2026-09-10 〜 2026-09-12**（3 日・Search Console）
  ※ GSC は確定まで 2〜3 日かかるため直近 3 日を除いている

## サマリー

| 指標 | 今回 | 前回比 |
| --- | --- | --- |
| **ページビュー** | 6 | -34（-85%） |
| **訪問（ユニーク）** | 6 | -34（-85%） |
| 検索クリック | 5 | -32（-86%） |
| 検索表示 | 132 | -598（-82%） |
| 検索 CTR | 3.8% | |
| 平均掲載順位 | 8.3 位 | **改善 1.3** |
| 検索に出た記事数 | 22 | |

## 流入経路

| 経路 | 訪問 | 比率 |
| --- | --- | --- |
| 直接・アプリ内 | 6 | 100% |


## 人気ページ TOP3（ページビュー順）

| # | PV | 訪問 | 前回比 | ページ |
| --- | --- | --- | --- | --- |

## 検索順位 TOP3（順位の高い順・表示 1 回以上）

| # | 平均順位 | 表示 | クリック | CTR | ページ |
| --- | --- | --- | --- | --- | --- |
| 1 | **4.0 位** | 1 | 0 | 0.0% | `/posts/electricity-gas-savings-2026/` |
| 2 | **4.0 位** | 2 | 0 | 0.0% | `/posts/morning-500-2026/` |
| 3 | **4.0 位** | 1 | 0 | 0.0% | `/posts/narita-haneda-overseas-direct-2026/` |

## 順位帯ごとの記事数

```

### `${` が残っていないか（**未展開の変数がここで分かる**）

```
(残っていない)
```

✅ **レポートが生成できた。** marker を置いた: `/Users/ny/.config/daily-hack/weekly-report-ok`
   t086 が plist に `--slack` を足してよい。
