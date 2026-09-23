# 新電力 3 社のロゴを実ブラウザで取る（t180・**$0**）

生成: **2026-09-23T21:53:31+0900**

**3 社とも t167（curl）では親ブランド・運営会社しか掴めなかった。**
**`denki` / `でんき` を含むものを先に取る。**

- CDP **生きている**（`{
   "Browser": "Chrome/140.0.7339.207",
   "Protocol-Version": "1.3",
   "User-`）

- `playwright-core`: `/Users/ny/.openclaw/workspace/node_modules/playwright-core`

## 楽天でんき

- `https://energy.rakuten.co.jp/` → **開けた**（title: "楽天のでんき・ガス｜楽天エナジー"）
  - ⬇️ `rakuten-denki-0.svg`（**6055 bytes** / image/svg+xml / 300x60 / alt: "楽天でんき"）
    - 取得元: `https://energy.rakuten.co.jp/common/img/logo_denki.svg`
  - ⬇️ `rakuten-denki-1.svg`（**2961 bytes** / image/svg+xml / 0x0 / alt: "logo"）
    - 取得元: `https://energy.rakuten.co.jp/common/img/logo_energy_small.svg`
  - ⬇️ `rakuten-denki-2.svg`（**3125 bytes** / image/svg+xml / 300x45 / alt: "logo"）
    - 取得元: `https://energy.rakuten.co.jp/common/img/logo_energy.svg`
  - ⬇️ `rakuten-denki-3.svg`（**5108 bytes** / image/svg+xml / 300x73 / alt: "楽天ガス"）
    - 取得元: `https://energy.rakuten.co.jp/common/img/logo_gas.svg`
  - ❌ `https://cdn.rmc.contents.rakuten.co.jp/block/d40535ac09aac0ef32f8a23b8` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (

## auでんき

- `https://www.au.com/energy/` → **開けた**（title: "【公式】auでんき_Web限定！新規お申し込みで5,000円(不課税)相当を還元！"）
  - ❌ `https://production-image-proxy.reproio.com/10/insecure/plain/https%3A%` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ⬇️ `au-denki-0.jpg`（**91810 bytes** / image/jpeg / 980x280 / alt: "【公式】auでんき 電気料金に応じてPontaポイントがたまる！ [header"）
    - 取得元: `https://www.au.com/denki/assets/energy/img/service_img_denki_pc.jpg`
  - ❌ `https://production-image-proxy.reproio.com/10/insecure/plain/https%3A%` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ❌ `https://www.au.com/denki/assets/energy/img/icon_menu_smp.png` → 380 bytes（小さすぎる）
  - ⬇️ `au-denki-1.png`（**2700 bytes** / image/avif / 224x88 / alt: "おもしろい方の未来へ。 au"）
    - 取得元: `https://kddi-h.assetsadobe3.com/is/image/content/dam/au-com/common/icon/au_logo_t.png?scl=1&fmt=png-alpha`
  - ⬇️ `au-denki-2.png`（**2597 bytes** / image/avif / 360x38 / alt: "おもしろい方の未来へ。 au"）
    - 取得元: `https://kddi-h.assetsadobe3.com/is/image/content/dam/au-com/common/icon/au_logo_y.png?scl=1&fmt=png-alpha`
  - ⬇️ `au-denki-3.png`（**4057 bytes** / image/avif / 171x80 / alt: "KDDI"）
    - 取得元: `https://kddi-h.assetsadobe3.com/is/image/content/dam/au-com/designs/icon/footer_logo.png?fmt=png-alpha&scl=1`
  - ⬇️ `au-denki-4.png`（**1171 bytes** / image/avif / 51x51 / alt: " [header]"）
    - 取得元: `https://kddi-h.assetsadobe3.com/is/image/content/dam/au-com/designs/icon/icon_pontapass_gray_51d343cd9cd339bd.png?fmt=png-alpha&scl=1`

## ドコモでんき

- `https://denki.docomo.ne.jp/` → **開けた**（title: "ドコモでんき｜電気料金の支払いでdポイントを還元"）
  - ❌ `https://cache2.denki.cilite.docomo.ne.jp/assets_brand/img/common/logo_` → Error: page.evaluate: TypeError: Failed to fetch
    at eval (eval at evaluate (
  - ⬇️ `docomo-denki-0.png`（**7299 bytes** / image/png / 0x0 / alt: "ドコモMAX ドコモポイ活MAX ドコモmini ドコモポイ活20"）
    - 取得元: `https://cache2.denki.cilite.docomo.ne.jp/assets_brand/img/img_plan_logo_pc.png`



---

**26 件 持ち帰った。**

**採否はクラウド側でコンタクトシートを見て決める。** 次は却下する:

- **親ブランド**（au / NTT docomo）を、でんきのロゴとして使わない
- **運営会社**（楽天エナジー）を、楽天でんきのロゴとして使わない
- **周年版・キャンペーン版**（`logo_10th` など）

経過 **17 秒**。
