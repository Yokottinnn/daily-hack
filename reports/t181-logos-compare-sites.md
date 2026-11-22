# 比較サイト 4 社のロゴを実ブラウザで取る（t181・**$0**）

生成: **2026-09-23T22:00:12+0900**

**URL は記事のリンクから取った。ワラウだけ記事にリンクが無いので検索する。**

- CDP **生きている**

- `playwright-core`: `/Users/ny/.openclaw/workspace/node_modules/playwright-core`

## 保険スクエアbang!

- `https://www.bang.co.jp/auto/` → **開けた**（title: "404 Not Found"）
- ⚠️ **ロゴらしい img が無い**

## 価格.com 自動車保険

- `https://kakaku.com/kuruma_hoken/` → **開けた**（title: "自動車保険 比較・見積もり依頼｜ネットで保険料をもっと安く - 価格.com"）
  - ❌ `https://img1.kakaku.k-img.com/images/logo.png` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://img1.kakaku.k-img.com/images/kuruma_hoken/top/logos/logo_axa_d` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://img1.kakaku.k-img.com/images/kuruma_hoken/top/logos/logo_sbi.p` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://img1.kakaku.k-img.com/images/kuruma_hoken/top/logos/logo_sony.` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://img1.kakaku.k-img.com/images/kuruma_hoken/top/logos/logo_saiso` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://img1.kakaku.k-img.com/images/kuruma_hoken/top/logos/logo_zuric` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (

## 楽天保険の窓口

- `https://hoken.rakuten.co.jp/car/` → **開けた**（title: "自動車保険を割引や事故対応・サポートなど詳しく比較【保険の比較】"）
  - ⬇️ `rakuten-hoken-0.png`（**15633 bytes** / image/png / 582x67 / alt: "保険の比較"）
    - 取得元: `https://hoken.rakuten.co.jp/assets/img/header/logo@2x.png`
  - ⬇️ `rakuten-hoken-1.png`（**15976 bytes** / image/png / 112x40 / alt: "保険の比較"）
    - 取得元: `https://hoken.rakuten.co.jp/assets/img/header/logo_sp@3x.png`
  - ⬇️ `rakuten-hoken-2.webp`（**9666 bytes** / image/webp / 500x106 / alt: "楽天自動車保険"）
    - 取得元: `https://hoken.rakuten.co.jp/assets/img/logo/rakuten-sonpo/rakuten-sonpo_car_driveassist.webp`
  - ⬇️ `rakuten-hoken-3.jpg`（**30114 bytes** / image/jpeg / 500x210 / alt: "SBI損保の自動車保険（総合自動車保険）"）
    - 取得元: `https://hoken.rakuten.co.jp/assets/img/logo/sbisonpo/sbi_car.jpg`

## ワラウ

- 検索 `ワラウ ポイントサイト 公式` の上位:
  - "ポイ活ならワラウ - 初心者でも貯まりやすいポイントサイト" → `https://www.warau.jp/`
  - "ワラウ公式｜ポイントサイト (@warau_official) / X" → `https://x.com/warau_official`
  - "ログイン｜ポイ活ならワラウ - 初心者でも貯まりやすい ..." → `https://ssl.warau.jp/login/`
  - "毎日貯める | ポイ活ならワラウ - 初心者でも貯まりやすい ..." → `https://www.warau.jp/play`
  - "ワラウ公式｜ポイントサイト - Periscope" → `https://www.pscp.tv/warau_official`
- **この URL で開く**: `https://www.warau.jp/`（採否はクラウド側で見る）
- `https://www.warau.jp/` → **開けた**（title: "ポイ活ならワラウ - 初心者でも貯まりやすいポイントサイト"）
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/component/logo/` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/project/warauOv` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/project/warauOv` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/project/warauOv` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/project/warauOv` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://warau.akamaized.net/www.warau.jp/images/object/project/warauOv` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (



---

**4 件 持ち帰った。**

**却下するもの**（最上位ルール 17）

- **楽天のロゴを「楽天保険の窓口」のロゴとして使わない**（親ブランド）
- **オープンスマイルのロゴを「ワラウ」のロゴとして使わない**（運営会社）
- キャンペーン版・周年版

経過 **15 秒**。
