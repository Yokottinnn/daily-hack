# ソフトバンク光と JAL Pay のロゴを取る（t189・**$0**）

生成: **2026-09-26T19:04:15+0900**

**どちらも親ブランドのロゴしか在庫が無い。** 自前のロゴを取りに行く。
**App Store と実ブラウザの両方を通して、採否はクラウド側で決める。**

## ① App Store（iTunes Search API）

### ソフトバンク光

- 検索語 `ソフトバンク光` / 期待する提供元 **SoftBank**
- 上位 3 件:
  - My SoftBank / **SoftBank Corp.** / id=1416481094
  - ソフトバンクWi-Fiスポット / **SoftBank Corp.** / id=578226245
  - エコ電気アプリ / **SB Power Corp.** / id=1519205654
- OK `sbhikari-app.png`（**14990 bytes** / HTTP 200）
  - 取得元: `https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/12/4e/45/124e4538-6827-bfa7-2e7a-04a12e34fe98/AppIcon-0-0-1x_U007ephone-0-11-0-85-220.png/512x512bb.jpg`

### JAL Pay

- 検索語 `JAL Pay` / 期待する提供元 **JAL**
- 上位 3 件:
  - JALマイレージバンク / **JAL Payment Port Co.,Ltd** / id=1444599693
  - JAL / **Japan Airlines Co., Ltd.** / id=351785536
  - JALカードアプリ / **JAL CARD INC.** / id=945350317
- OK `jalpay-app.png`（**32108 bytes** / HTTP 200）
  - 取得元: `https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/17/0d/38/170d385d-b792-21c1-fd83-3f72ef2d87f1/AppIcon-0-0-1x_U007ephone-0-1-0-sRGB-85-220.png/512x512bb.jpg`

## ② 実ブラウザ（公式サイト）

### ソフトバンク光

- `https://www.softbank.jp/internet/hikari/` -> **開けた**（title: "Yahoo! BB 光 with フレッツ | インターネット・固定電話 | ソフトバンク"）
  - OK `sbhikari-web0.svg`（**435 bytes** / image/svg+xml / 150x150 / alt: " [header]"）
    - 取得元: `https://www.softbank.jp/site/set/common/sunshine/shared/img/icon-search-black-02.svg`

### JAL Pay

- `https://www.jal.co.jp/jp/ja/jalmile/jalpay/` -> **開けた**（title: "ご指定のページが見つかりません - JAL"）
  - NG `https://www.jal.co.jp/commonY15/img/simple_logo.gif` -> HTTP 403



---

**対象 2 ブランド / 持ち帰った 3 件。** 経過 **14 秒**。

**却下する条件**（最上位ルール 17）

- **ソフトバンク（親ブランド）を「ソフトバンク光」のロゴとして使わない**
- **JAL（親ブランド）を「JAL Pay」のロゴとして使わない**
- キャンペーン版・周年版
