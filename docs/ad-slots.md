# 広告枠の全体像

**枠の位置は記事側では決めない。** すべて `src/layouts/PostLayout.astro` と
`src/layouts/BaseLayout.astro` が持っている。記事の Markdown に広告タグを書かない。

## いまある枠

| slot | 場所 | 出る条件 | タグ |
| --- | --- | --- | --- |
| `dailyhack-article-top` | 記事冒頭（リード文の直下） | 常時 | 登録済み |
| `dailyhack-article-middle` | 本文中 — h2 の 1/3 の位置 | h2 が 6 本以上 | **未登録** |
| `dailyhack-article-mid2` | 本文中 — h2 の 2/3 の位置 | h2 が 6 本以上 | **未登録** |
| `dailyhack-article-bottom` | 本文と関連記事の間 | 常時 | 登録済み |
| `dailyhack-sidebar-sticky` | サイドバー・目次の下 | 常時（**モバイルでも消えない**） | 登録済み |
| `dailyhack-sticky-mobile` | スマホ下部固定 | `max-width: 879px` | 登録済み |
| `dailyhack-home-below-hero` | トップの Hero 直下 | 常時 | 登録済み |

本文中の 2 枠は**サーバ側では本文の後ろに描画され、クライアントのスクリプトが
h2 の切れ目へ移動する**。h2 が 6 本未満なら 1 枠、2 本未満なら 0 枠に減る。

`src/data/admax-tags.ts` の値が `PLACEHOLDER` で始まる slot は**何も描画されない**。
枠をコードに足しても、忍者AdMAX の管理画面でタグを作って貼るまで表示は増えない。

## 忍者AdMAX の「1ページ 3 個まで」

複数の解説サイトが「**1 ページ 3 個まで。3 つを超えると正常に表示されないことがある**」
と書いている（[so-zou.jp](https://so-zou.jp/web-app/tech/advertising/publisher/ninja-admax/) /
[abhp.net](https://abhp.net/asp/ASP_Ninja_AdMax_100000.html)）。

**公式規約そのものは未確認。** クラウドセッションからは `admax.shinobi.jp` に到達できず、
検索結果の要約までしか取れていない。**伝聞として扱うこと。**

現在の記事ページの内訳（2026-09-05 時点）。

| | 出ている枠 | 数 |
| --- | --- | --- |
| PC | 冒頭・末尾・サイドバー | **3** |
| スマホ | 冒頭・末尾・サイドバー・下部固定 | **4** |

**本文中の 2 枠に忍者AdMAX のタグを貼ると 5〜6 になる。** そこは AdSense で埋める前提。

### 同じタグを 1 ページに複数貼るのは避ける

忍者AdMAX は「**設置場所ごとに広告枠を作る**」のが標準の作法。同一ページに複数掲載自体は
できるが、**同じ広告が出ることがある**とされている。流用は枠ごとの成果も分けて見られなくなる。

## スマホ下部固定の経緯

- **2026-05-31**: 「UX を損なう」として `BaseLayout` から外された。「文中バナーで代替」と記録
- **2026-09-05**: 利用者の判断で**記事ページにだけ戻した**（`PostLayout.astro`）。
  トップや一覧には出さない

`body:has(.admax--sticky-mobile)` に `padding-bottom: 76px` を当てて、記事の末尾が
広告に隠れないようにしてある（`global.css`）。

## ads.txt はサブドメインだと効かないことがある

**このサイトは `daily-hack.fieldbeside.com`＝サブドメインで動いている。**

ads.txt のクロールは**ルートドメインから始まる**。サブドメインの ads.txt は、
**ルートドメインの ads.txt から `SUBDOMAIN=` で参照されている場合にだけ**
クロール・適用される。参照が無ければサブドメイン側は無視され、
ルートドメインの ads.txt にフォールバックする
（[Ads.txt FAQs](https://support.google.com/adsense/answer/9785052?hl=en) /
[Ensure your ads.txt files can be crawled](https://support.google.com/adsense/answer/7679060?hl=en)）。

つまり `public/ads.txt`（= `daily-hack.fieldbeside.com/ads.txt`）に書くだけでは足りない。

```text
fieldbeside.com/ads.txt   ← このリポジトリの外。ここに次の 1 行が要る
SUBDOMAIN=daily-hack.fieldbeside.com
```

**それが置けないなら、広告事業者の行を `fieldbeside.com/ads.txt` 側に書く。**
HTTP と HTTPS の両方でアクセスできることも確認する。

**ルートドメインの実体は別リポジトリ `Yokottinnn/fieldbeside-website`。**
`index.html` が 1 枚あるだけの静的サイトで、リポジトリのルートをそのまま配信している。
そこへ `ads.txt` を足す PR を出してある（[fieldbeside-website#1](https://github.com/Yokottinnn/fieldbeside-website/pull/1)）。
マージしたら `https://fieldbeside.com/ads.txt` が読めるようになる。

**忍者AdMAX の行はまだ 1 行も無い。** 管理画面（忍者ツールズ → AdMax →
広告枠一覧 →「ads.txt を取得」）で自サイト用の行を取る。ログインが要るので
クラウドセッションからは取れない。

## AdSense（自動広告で始める・2026-09-05 に決定）

**配線は済んでいる。足りないのは環境変数だけ。**

| 部品 | 状態 |
| --- | --- |
| `BaseLayout.astro` | `PUBLIC_ADSENSE_CLIENT` が `ca-pub-` で始まれば `adsbygoogle.js` を読み、`google-adsense-account` メタも出す |
| `CookieConsent.astro` | 同意・拒否で `requestNonPersonalizedAds` を切り替える |
| `AdUnit.astro` | in-article / in-feed のレイアウトに対応。**ただしどこにも設置されていない** |
| `PUBLIC_ADSENSE_CLIENT` | **未設定**（Cloudflare Pages の環境変数） |

### 有効化の手順

1. Cloudflare Pages の環境変数に `PUBLIC_ADSENSE_CLIENT = ca-pub-XXXXXXXXXXXXXXXX` を入れる
2. 再デプロイする（環境変数はビルド時に読まれる）
3. AdSense の管理画面で**自動広告を ON にする**

**自動広告は `AdUnit` を設置しなくても効く。** Google が位置を決めるため、
コード側の追加作業は要らない。手で位置を決めたくなったときに `AdUnit` を使う。

### 併用の可否

**AdSense と他社ネットワークの併用は Google の規約上 OK**
（[Use other ad networks together with AdSense](https://support.google.com/adsense/answer/9728?hl=en)）。
効いてくる制約は 2 つ。

- **AdSense を模した見た目の広告を出す他社ネットワークは不可。** 忍者AdMAX は該当しない
- **広告よりコンテンツが多いこと**（Valuable Inventory）。自動広告は管理画面で
  広告の量を絞れるので、忍者AdMAX の枠と合わせて多すぎないか見ること

### 審査に必要なページの点検（2026-09-05 時点）

| 項目 | 状態 |
| --- | --- |
| オリジナル記事の量 | **72 本** |
| プライバシーポリシー | `src/pages/privacy.astro`。第9条に広告配信、第7条に Cookie |
| 問い合わせ先 | `src/pages/contact.astro`（`info@fieldbeside.com`） |
| 運営者情報 | `src/pages/about.astro`（Fieldbeside合同会社・事業内容） |
| 免責事項 | `src/pages/disclaimer.astro` |
| クロール許可 | `robots.txt` は `Allow: /`。sitemap も出ている |
| PR 表記 | `isPR` の記事に `PRBadge` と注記が出る |

**申請を止める要素は見当たらない。** 申請は Google アカウントでのログインが要るため
クラウドセッションからは行えない。
