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

## 運用ルール

### 週次（Jordan指定 2026-07-05）
- **週1**で分析（毎週月曜、Slack自動＋このフォルダにスナップショット追記）。

### 月次（2026-09-27 に追加）

> **それまで月次は無かった。** 「週次と月次の二段構え」と思われていたが、
> 在ったのは週次だけ。利用者の依頼で作った。

| ワークフロー | いつ | 出力 |
| --- | --- | --- |
| `pv-archive.yml` | 毎日 **05:37 JST** | `ops/pv-archive` の `data/<YYYY-MM>.json` |
| `monthly-pv-report.yml` | 毎月 2 日 **06:11 JST** | `ops/pv-archive` の `reports/<YYYY-MM>.md` |

**その場で前月を引くことはできない。** Cloudflare 無料プランの保持は
**31 日（`4w3d`）**で、それより前は `code: "quota"` で返る。
**だから毎日 積んでいる。**

過去ぶんを埋めるときは、**1 日ずつ dispatch しない**
（`concurrency` で待機が順次キャンセルされ、2026-09-27 に 26 件 中 16 件 消えた）。

```text
workflow_dispatch: from=2026-09-01 to=2026-09-26   ← 1 回の実行に収める
```

## ⚠️ 「visits」を読者数として読まない（2026-09-27 に実測）

**Cloudflare Zone Analytics の visits はボットとクローラを含む。**
9 月は **13,778 のうち 94% がボット**だった。

| | 2026-09（26 日） | 割合 |
| --- | --- | --- |
| 総 visits | 13,778 | 100% |
| **実ブラウザ** | **789** | **5.7%** |
| **日本から** | **389** | **2.8%** |

最大は `Unknown`（User-Agent に名前を載せないもの）の **11,189**。
国別でも **FR 5,532 / US 3,687 / DE 1,638** が上位で、**日本は 6 位。**

| 知りたいこと | 見るもの |
| --- | --- |
| **検索から来た実訪問** | **GSC のクリック数** |
| 読者のおおよその規模 | **実ブラウザ**（`human`） |
| サーバの負荷・帯域 | 総 visits・総 requests |
| **読者数** | ❌ 総 visits を使わない |

**流入経路は Zone Analytics では取れない**（`clientRefererHost` /
`clientRequestReferer` は無料プランで拒否される）。GSC 側で見る。

## ⚠️ Web Analytics（RUM）は 1 件も取れていない（2026-09-27 に判明）

`src/layouts/BaseLayout.astro` のビーコン token `0dc312c5…` が
**Cloudflare アカウントに存在しない。** 引くと PV 0 が返る。
アカウントにある RUM サイトは `fieldbeside.com`（`73990e57…`）の **1 件だけ**で、
`weekly-blog-report.py` はそちらの数字（PV 100・記事ページ 0）を出していた。

**直し方は未決。** 3 択。

1. daily-hack 用の Web Analytics サイトを作ってビーコンを差し替える（Cloudflare へ書き込み）
2. 既存の `73990e57…` に寄せる（fieldbeside.com 本体と混ざる）
3. RUM をやめて Zone Analytics に一本化する
- 見る観点: ①相対的な人気/惜しい記事 ②勝ちパターン（長尾/具体語） ③改善対象（表示あり×順位あと一歩） ④狙い目クエリ。
