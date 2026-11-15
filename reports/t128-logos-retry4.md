# t124 / t125 の取り直し（t128）

生成: **2026-09-20T22:24:01+09:00**

**SVG は変換せずそのまま持ち帰る。** ラスタライズはクラウド側で Chromium が行う。
**採否はクラウド側で目で見て決める。**

## 0) Mac に何が在るか（SVG 変換まわり）

  - `qlmanage` … 在る（`/usr/bin/qlmanage`）
  - `rsvg-convert` … **無い**
  - `inkscape` … **無い**
  - `magick` … **無い**
  - `convert` … **無い**
  - `sips` … 在る（`/usr/bin/sips`）
  - `node` … 在る（`/opt/homebrew/bin/node`）
  - `npx` … 在る（`/opt/homebrew/bin/npx`）

  - `cairosvg` … **無い**

## A0) App Store（ID を直に指定）

### JAL Wellness & Travel（id 1498726068）

  - ストア上の名前: **JAL Wellness & Travel**
  - 提供元: **JAL Brand Communications Co.,Ltd.**
  - ✅ `jalwellness-app.png` / 512x512 / **App Store の登録アイコン（商標）**

## A) コモンズの検索（3 回 まで試す）

### 楽天損保

  - ✅ `rakutensonpo-1.png` / 384x64 / **Public domain**
        ← File:Rakuten Travel logo.png
  - ✅ `rakutensonpo-2.png` / 960x720 / **Attribution**
        ← File:新臺鐵彩繪列車2025微笑冠軍號1月15日正式啟航 班表曝光！-活動照片 頁面 2 影像 0001.jpg

## B) 公式サイト（SVG も持ち帰る）

### ソニー損保
  - 取得元: https://www.sonysonpo.co.jp/

  - 候補: `https://www.sonysonpo.co.jp/share/image/portal/top/logo_financial.svg` / alt=`�\�j�[�t�B�i���V�����O���[�v`
  - 📄 `sonysonpo-1.svg` / 5575 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.sonysonpo.co.jp/share/image/portal/top/logo_seimei.svg` / alt=`�\�j�[����`
  - 📄 `sonysonpo-2.svg` / 3168 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.sonysonpo.co.jp/share/image/portal/top/logo_sonpo.svg` / alt=`�\�j�[����`
  - 📄 `sonysonpo-3.svg` / 4063 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.sonysonpo.co.jp/share/image/portal/top/logo_bank.svg` / alt=`�\�j�[��s`
  - 📄 `sonysonpo-4.svg` / 4761 bytes（**SVG のまま持ち帰る**）

### 楽天損保
  - 取得元: https://www.rakuten-sonpo.co.jp/

  - 候補: `https://www.rakuten-sonpo.co.jp/Portals/0/images/common/header/logo_sp01.png` / alt=`楽天損害保険株式会社`
  - ✅ `rakutens-1.png` / 148x80 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://www.rakuten-sonpo.co.jp/Portals/0/images/common/header/logo_pc.png` / alt=`楽天損害保険株式会社`
  - ✅ `rakutens-2.png` / 422x64 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://www.rakuten-sonpo.co.jp/Portals/0/images/common/apple-touch-icon.png` / alt=`apple-touch-icon`
  - ✅ `rakutens-3.png` / 152x152 / **公式サイトのロゴ画像（商標）**

### Looopでんき
  - 取得元: https://looop.co.jp/denki/

  - ✗ ページが開けない（HTTPError）

### 保険スクエアbang!
  - 取得元: https://www.bang.co.jp/auto/

  - ✗ ページが開けない（HTTPError）

### レモンガス
  - 取得元: https://www.lemongas.co.jp/

  - 候補: `https://www.lemongas.co.jp/lg/wp-content/themes/twentytwenty/images/logo.svg` / alt=``
  - 📄 `lemongas-1.svg` / 17779 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.lemongas.co.jp/lg/wp-content/themes/twentytwenty/images/footerlogo.png` / alt=``
  - ✅ `lemongas-2.png` / 427x42 / **公式サイトのロゴ画像（商標）**

### トリマ
  - 取得元: https://www.trip-mile.com/

  - 候補: `https://static.wixstatic.com/media/a9144a_c53b802238a04b988f6c10711f0e58f7~mv2.png/v1/fill/w_103,h_60,al_c,q_8` / alt=`トリマ_logo.png`
  - ✅ `torima-1.png` / 103x60 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://static.wixstatic.com/media/a9144a_38608f87832a4adbaa35cc7c25b8f3eb%7Emv2.png/v1/fill/w_180%2Ch_180%2Cl` / alt=`apple-touch-icon`
  - ✅ `torima-2.png` / 180x180 / **公式サイトのロゴ画像（商標）**

