# アフィリエイトの台帳（ASP ごとの提携状況・使えるリンク）

> 記事にアフィリエイトリンクを貼る前にここを見る。**ログインが切れても、ここにある ID・リンクは使える。**
> 取り方の仕組みは [`asp-sync.md`](./asp-sync.md)。画面調べは `scripts/asp/asp-probe.mjs`（`ASP_PROBE=…`）。
> **公開リポジトリ。** 自分の報酬額・会社名・契約 ID・口座は書かない。

## 楽天アフィリエイト

- 2026-10-11 から **Keychain だけで自動ログインできる**（t252）
- 商品リンクの形（t259 で画面のコードから読んだ実物）:
  `https://hb.afl.rakuten.co.jp/ichiba/<4 区切りの ID>/?pc=<商品 URL を encode>&link_type=…&ut=…`
- **4 区切りの ID は店ごとに変わる。** 同じ店（edyshop）の 3 商品は同じ値、別の店（kyoto3303）は別の値だった（t259/t268）。
  **別の店の商品へ ID を使い回さない。** 店が変わったら「商品リンク作成」の画面から取る（`ASP_PROBE=rakutenitem RAKUTEN_KW=…`）
- 楽天市場の商品以外（楽天トラベル・ふるさと納税・特集ページ）へのリンクには、自分のアフィリエイト ID が要る。
  楽天ウェブサービスで**アプリを 1 つ登録すると**「アプリ一覧」（`/app/list`。API 説明の `affiliateId`「Check here」のリンク先）に出る**2026-10-14 に登録済み**（アプリ名 `dailyhack`・有効期限 2027-10-14）。**自分のアフィリエイト ID は `587f2635.77bb335f.587f2636.e34c8733`**（t294 で読んだ公開値）。applicationId は Mac の Keychain（`dailyhack-rakuten-ws` / `applicationId`）にだけある。登録で踏んだ落とし穴：アプリ名に記号（ハイフン）は使えない／許可サイト欄は `https://` を付けずドメインだけを 1 行ずつ。
  **アプリ登録はアカウントの操作なので、利用者の OK を取ってから**

### 記事で使っている楽天のリンク

| 記事 | 商品 | 取った日 |
| --- | --- | --- |
| point-service-complete-guide-2026 | Edy-楽天ポイントカード（edyshop・330 円） | 2026-10-11（t268） |

## A8.net（未提携・記事に合う候補）

2026-10-11 に詳細画面（`/program/detail-not-partnered?programId=…`）から読んだ（t260）。
**提携の申請はアカウントの操作なので、利用者の OK を取ってから。**

**2026-10-11 に 5 件 申請済み・審査中**（利用者の OK を受けて t271）: 三井住友カード（NL）／TOKYU CARD／三井ショッピングパークカード《セゾン》／dカード GOLD U／WOWOW セゾンカード（004）。
審査は数週間かかることがある。**通ったら週次の asp-sync の「参加中プログラム」に出る。出たら広告リンクを取ってポイント記事に入れる。**

| programId | 名前 | 成果報酬（広告側） | 自己アフィリ | ポイントサイト掲載 |
| --- | --- | --- | --- | --- |
| s00000023355003 | 三井住友カード（NL） | 新規カード発行 4,800 円 | **OK** | NG |
| s00000023297001 | TOKYU CARD | 新規カード発行 4,135 円 | NG | NG |
| s00000015597014 | 三井ショッピングパークカード《セゾン》 | 初回カード発行 3,500 円 | NG | NG |
| s00000024441001 | プロミス Visa カード | 新規カード発行 3,000 円 | NG | NG |
| s00000013470008 | dカード GOLD U | 初回カード発行 2,860 円 | NG | NG |
| s00000026575004 | WOWOW セゾンカード（ほか 008/010/013 も同系） | 初回カード発行 2,632 円 | NG | NG |
| s00000017066001 | ECナビ | 新規会員登録 210 円 | NG | NG |
| s00000025908001 | ポイントインカム | 新規会員登録 100 円 | NG | OK |

- 「自己アフィリ」「ポイントサイト掲載」は検索結果の札（画像の alt: 本人OK/NG・ポイントOK/NG）
- 各プログラムに「広告主が提携審査のためにメディアを確認する場合があります」とある＝**審査あり**

## バリューコマース

- 広告一覧は `/ad/adList`。提携状態の絞り込みは `ad_search_condition_form[appStatus]`（N 未提携 / P 提携待ち / **A 提携済み** / T 見送り / Q 終了）
- 一覧の「即時提携」は**提携方式の札**であって、提携済みの印ではない（t261 で取り違えかけた）
- **提携済みは 3 件**（t264・2026-10-11）: Liigo（2161122）／**Yahoo!ショッピング 自動提携機能用（2136156）**／ニーズツアー（2175237）
- Yahoo!ショッピングは **MyLink** でリンクを作る（広告詳細にコードの欄は無く、MyLink のボタンから。t267）
- **3 店ボタン（`docs/shop-comparison.md`）の Yahoo! は素の shopping.yahoo.co.jp リンク**で、isPR の記事の LinkSwitch が成果リンクに変える

## もしもアフィリエイト

- **Amazon は もしも経由で取る**（2026-10-25 利用者の判断）。提携が通ったら `src/data/shop/config.json` に a_id 等を写す（`docs/shop-comparison.md`）

- 提携中は 2 件（記事に合うものは無し・t244）


## 楽天アフィリエイトのリンクを入れた記事（法人 ID に張り替えるときの一覧）

2026-10-16 に個人名義の ID（`587f2635…`）で入れた。形は `https://hb.afl.rakuten.co.jp/hgc/<ID>/?pc=<URL>&m=<URL>`（t297 で飛び先と `scid=af_pc_etc` を確認）。**法人審査が通ったら、ここの記事を全部 張り替える。**

| 記事 | 包んだリンク数 | 備考 |
| --- | --- | --- |
| `furusato-portal-comparison-2026` | 3 |  |
| `furusato-tax-2026-reform-guide` | 1 |  |
| `furusato-tax-beginner-guide-2026` | 1 |  |
| `furusato-tax-food-picks-2026` | 1 |  |
| `point-service-complete-guide-2026` | 0 | ID 差し替え |
| `summer-cospa-travel-2026` | 16 |  |
| `summer-travel-timesale-2026` | 5 |  |
| `rechargeable-kairo-comparison-2026` | 3 店ボタン（`src/data/shop/rechargeable-kairo.json`） | 楽天のリンクは `src/data/shop/config.json` の `rakuten.affiliateId` 1 か所で替わる（記事の Markdown には書いていない） |
| `mobile-battery-comparison-2026` | 3 店ボタン（`src/data/shop/mobile-battery.json`） | 同上 |
| `heated-vest-comparison-2026` | 3 店ボタン（`src/data/shop/heated-vest.json`） | 同上 |

## A8 のリンクを入れた湾岸ライフの記事（2026-10-25）

| 記事 | 案件 | 置き場所 |
| --- | --- | --- |
| `tokyo-christmas-market-shintoyosu-2026` | KKday（`4B43JB+BX9KPM+52F8+5YJRM`） | 料金の表の下・事前予約の説明（2 か所。トップへのリンクで「新豊洲」と検索してもらう） |
| `ariake-garden-winter-illuminations-2026` | トラベリスト（`4B3Y38+35PU3E+4XZI+BWVTE`）・イオンコンパス（`4B3Y38+36WPAY+5RZ8+5YJRM`） | SNS の節の前の「近くに泊まるなら」 |
| `mobility-cost-per-km-2026` | EARTHCAR（`4B3Y38+383KII+43U8+HVFKY`） | 状況別おすすめの直後（荷物が多い日・遠出） |
| `wangan-saving-spots-2026` | エネピ 電気（`4B3Y38+25ZTSQ+2W92+1NJK7M`） | まとめの「固定費削減と組み合わせれば」の直後 |
