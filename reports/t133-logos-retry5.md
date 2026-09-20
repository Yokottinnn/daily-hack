# t130 の取り直し（t133）

生成: **2026-09-20T23:10:05+09:00**

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

## A) コモンズの検索（3 回 まで試す）

### エポスカード

  - **使えるものが無かった。**

### dカード

  - ✅ `dcard-1.png` / 960x195 / **Public domain**
        ← File:NTT docomo (NTT Blue) simple logo.svg
  - ✅ `dcard-2.png` / 960x208 / **Public domain**
        ← File:NTT docomo (NTT blue).svg

### じゃらん

  - ✅ `jalan-1.png` / 960x258 / **Public domain**
        ← File:Recruit Holdings Logo.gif
  - ✅ `jalan-2.png` / 960x402 / **Public domain**
        ← File:Recruit Holdings logo.svg

## B) 公式サイト（SVG も持ち帰る）

### モッピー
  - 取得元: https://pc.moppy.jp/about/

  - ✗ ページが開けない（HTTPError）

### モッピー（企業）
  - 取得元: https://ceres-inc.jp/

  - 候補: `https://ceres-inc.jp/assets/images/common/logo_l.svg` / alt=`株式会社セレス`
  - 📄 `moppy2-1.svg` / 4186 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://media.ceres-inc.jp/services/img/1.png` / alt=`moppyのロゴ`
  - ✅ `moppy2-2.png` / 100x22 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://media.ceres-inc.jp/services/img/10.jpg` / alt=`studio15のロゴ`
  - ✅ `moppy2-3.png` / 582x167 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://media.ceres-inc.jp/services/img/12.png` / alt=`バッカスのロゴ`
  - ✅ `moppy2-4.png` / 312x78 / **公式サイトのロゴ画像（商標）**

### ハピタス
  - 取得元: https://sp.hapitas.jp/

  - 候補: `https://sp.hapitas.jp/apple-touch-icon.png` / alt=`apple-touch-icon`
  - ✅ `hapitas-1.png` / 180x180 / **公式サイトのロゴ画像（商標）**

### 一休.com
  - 取得元: https://www.ikyu.com/corporate/

  - ✗ ページが開けない（HTTPError）

### じゃらん
  - 取得元: https://www.jalan.net/theme/

  - **`logo` を含む img が無い。** ページ内の img を先頭 12 件 出す:
    - `<img class="pc" src="/theme/images/pc_btn_sale_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_sale_more.png" alt="�����ƌ���">`
    - `<img class="pc" src="/theme/images/pc_btn_sale_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_sale_more.png" alt="�����ƌ���">`
    - `<img class="pc" src="/theme/images/pc_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="pc" src="/theme/images/pc_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="pc" src="/theme/images/pc_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="pc" src="/theme/images/pc_btn_theme_more.png" alt="�����ƌ���">`
    - `<img class="sp" src="/theme/images/sp_btn_theme_more.png" alt="�����ƌ���">`

### Yahoo!トラベル
  - 取得元: https://travel.yahoo.co.jp/help/

  - ✗ ページが開けない（HTTPError）

### dカード
  - 取得元: https://dcard.docomo.ne.jp/st/

  - ✗ ページが開けない（URLError）

### エポスカード
  - 取得元: https://www.eposcard.co.jp/company/

  - 候補: `https://www.eposcard.co.jp/common-files/img/com_head_logo01.png` / alt=`EPOS Net �G�|�X�J�[�h`
  - ✅ `epos2-1.png` / 228x70 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://www.eposcard.co.jp/common-files/img/sp_com_epotoku_logo02.gif` / alt=`�G�|�g�N�v���U`
  - ✅ `epos2-2.png` / 130x80 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://www.eposcard.co.jp/common-files/img/sp_com_tamaru_logo02.gif` / alt=`�G�|�X�|�C���gUP�T�C�g`
  - ✅ `epos2-3.png` / 130x80 / **公式サイトのロゴ画像（商標）**
  - 候補: `https://www.eposcard.co.jp/ownernet/common-files/img/header_logo01.png` / alt=`EPOS OWNER`
  - ✅ `epos2-4.png` / 210x41 / **公式サイトのロゴ画像（商標）**

### PayPayカード
  - 取得元: https://www.paypay-card.co.jp/company/

  - 候補: `https://www.paypay-card.co.jp/company/images/logo.svg?20240628` / alt=`PayPayカード`
  - 📄 `paypaycard-1.svg` / 5187 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.paypay-card.co.jp/company/images/logo-sp.svg?20240628` / alt=`PayPayカード`
  - 📄 `paypaycard-2.svg` / 3706 bytes（**SVG のまま持ち帰る**）
  - 候補: `https://www.paypay-card.co.jp/company/images/logo-white.svg` / alt=``
  - 📄 `paypaycard-3.svg` / 9072 bytes（**SVG のまま持ち帰る**）

