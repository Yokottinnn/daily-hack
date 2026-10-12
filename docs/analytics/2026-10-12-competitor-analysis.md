# 競合分析：同ジャンルの個人・小規模ブログはどう稼いでいるか（2026-10-12 調べ）

対象サイト：daily-hack（https://daily-hack.fieldbeside.com）
目的：1〜3か月でアフィリエイト収益を出すために、個人・小規模ブログが使っている「記事の型」「リンクの置き方」「案件の選び方」を読み取る。

## 0. 調べ方と限界（最初に読む）

- 検索には WebSearch（米国拠点の検索 API）を使った。**Google.co.jp の実際の順位ではない。** 日本語クエリでも、上位はマイベスト・エクシア（exidea）・Selectra・SIM 系の企業メディアがほとんどを占めた。個人ブログは、検索語に「ブログ」「体験」「実際に」「1年使った」などを足したときにだけ出てきた。**この偏り自体が「大手が独占している語」の目安になる**（§(c)）。
- 各ページは WebFetch で取得した。WebFetch は本文を Markdown に変換してから要約するため、**リンク URL とボタン文言は拾えるが、ボタンの見た目・画像バナーの中身・JS で後から差し込まれる広告は見えない。** 「無し」と書いたものは「変換後の本文に見当たらなかった」という意味。
- 個人か法人かは、ページ上の表記だけで判断した。書かれていなければ「不明」とした。
- 記事ページの取得を試みたのは 38 件で、**取れたのは 36 件、取れなかったのは 2 件**：yagokoro-lab.com（HTTP 401）、wangannavi.com（HTTP 403。curl でも 403）。ほかに Bing と DuckDuckGo の検索結果ページも試したが、無関係の結果と画像認証しか返らず使えなかった。
- 金額（キャッシュバック・入会特典）は**各ページに書かれていた時点の値**で、いまの値ではない。

---

## 1. 光回線

### 1-1. 明日も明るく（ashitamoakaruku.com）
- URL：https://ashitamoakaruku.com/comparison/
- 運営：著者「orangesweet35」。個人か法人かの記載は無し（小規模サイトとみられる）
- タイトル：光回線の徹底比較とランキング【2026年最新版】（月額・速度・特徴・おすすめ・合うユーザー）
- 型：**比較表＋ライフスタイル別＋ランキング**
- h2：主要10社の基本プラン比較 → 迷ったらこう決める（ライフスタイル別）→ おすすめランキング → ＜参考＞10ギガ比較 → まとめ
- リンク：**すべて A8.net（px.a8.net）**。楽天ひかりだけ trafficgate。冒頭の比較表で 10 社 → ライフスタイル別の各項目末 → ランキングの各項目末 → まとめの表 → 末尾のバナー 5 枚。**同じ案件を 4〜5 回出しており、リンクは合計でおよそ 40 本。**
- CTA の例：「シンプルに安い速いGMOとくとくBB光！」「【キャッシュバック還元中！】GMOとくとくBBのauひかりキャンペーン」「楽天ひかりの公式サイトへ」
- 推し：1位 NURO光、2位 GMOとくとくBB光、3位 BB.excite光MEC／おてがる光。ドコモ光・ソフトバンク光・auひかりは「**販売代理店 GMOとくとくBB**」のリンクで送っている。キャッシュバックの金額は書いていない
- 差別化：無し（実測も写真も無い）。そのかわり各回線の「合う人・合わない人」記事へ内部リンクを大量に張り、サイト内を回らせている
- PR 表記：**無し**（ステマ規制の観点では危うい）

### 1-2. Wi-Fiのトリセツ（wifi-torisetsu.com）
- URL：https://wifi-torisetsu.com/hikarikaisen-erabikata/
- 運営：「ハルト」（運営者）。個人か法人かは不明
- タイトル：【2026年最新】光回線速度ランキング！実測値で比較した本当に速い回線16選
- 型：**実測データのランキング（他サイトのデータを集め直したもの）＋条件別の結論**
- h2：実測速度ランキング → ランキングを鵜呑みにしてはいけない3つの理由 → 条件別の結論 → 回線を変えても直らないケース → 10ギガで解決するか → FAQ → まとめ
- リンク：A8（NURO光・GMOとくとくBB光）、**accesstrade（GameWith光）**、**felmat（eo光）**。置いているのは「条件別の結論」の各項目末と、まとめの直前だけ。**合計は 5 本ほどと少ない。**
- CTA：「NURO光の提供エリアと現在の料金を公式で確認する」「GMOとくとくBB光の料金と特典条件を確認する」。eo光のボタンには「新しいタブで開きます。この時点では申し込みになりません」と添えている。**申し込みを迫らない「確認する」型の文言。**
- 差別化：みんそく（minsoku.net）の直近 3 か月のデータを 1 ギガ級と 10 ギガ級に分けて集計し、件数も出している。全体平均との差を「編集部算出」と明記。配線方式（VDSL 等）で切り分ける手順も載せている
- PR 表記：冒頭に「広告」と表示し、比較ボックスの直後に「本ページはプロモーション（アフィリエイト広告）を含みます」

### 1-3. りょうブログ（ryou-blog.com）※体験レビューの型
- URL：https://ryou-blog.com/nuro-mansion/
- 運営：個人（ブログ歴 11 年）。体験者は「長谷川」さんと記載
- タイトル：NURO光をマンションで実際に契約・利用した感想まとめ【口コミ・評判】
- 型：**1 回線の体験レビュー（h2 が 15 本の長文）**
- h2：エリア確認と申込 → 工事の体験談 → 実際の速度 → マンション向けサービス → 料金とキャンペーン → メリット・デメリット → トラブル対応 → 解約 → 乗り換え先のおすすめ → 総合評価 → 乗り換えガイド → FAQ → 最新動向 → 1年半使った感想 → 「今が申込みにベストなタイミング！」
- リンク：A8 のみ。**冒頭と、ほぼ全部の h2 の末尾に「NURO光 期間限定キャンペーンはこちら」**。後半では「乗り換え先」としてドコモ光・ソフトバンク光・GMO の auひかり・おてがる光も A8 で送っている
- 訴求：「最大55,000円」「最大48,000円」とキャッシュバック額が**記事の中で食い違っている**。「上のリンク限定」と限定感を出している
- 差別化：築 10 年・8 階の部屋、工事 2 回の立ち会い、時間帯別の実測表、27 台の同時接続、ONU の交換
- PR 表記：冒頭に「記事内に商品プロモーションを含みます」

### 1-4. よみちいblog（yomichii-blog.com）※小さな体験記
- URL：https://yomichii-blog.com/nuro-mansion/
- 運営：個人（臨床検査技師・ワーママ）
- 型：**開通までの時系列の体験記**（管理組合への問い合わせから開通まで約半年）
- リンク：A8 の画像バナー 5 枚（冒頭・比較表の後・工事の後・まとめ）。文字の CTA は無し
- PR 表記：「スポンサーリンク」だけ。PR の明示は無し

### 1-5. 地域×光回線（daily-hack に一番近い型）
- **とよすと（toyosu.tokyo）** https://toyosu.tokyo/life/nuro-hikari-for-mansion-toyosu/
  - 豊洲の地域メディア。「豊洲で NURO光が使える導入済みマンションを調べてみました」（2018 年公開・2021 年更新）
  - 豊洲 1〜6 丁目の導入済みマンションを **31 件** 並べている。NURO 公式へは直リンク、auひかりへは **ValueCommerce** で 3 本
  - PR 表記：「ページに含まれる広告から収益を得ることがあります」
- **光回線比較研究室（hikari-fast.jp）** https://hikari-fast.jp/nuro-mansion/東京都/江東区/
  - 「東京都江東区の NURO光forマンション導入済み物件一覧」。町丁目ごとに約 170 の見出し、物件はおよそ 830 件。住所がそのまま物件名になっている行もあり、**データから機械的に作ったページ（プログラマティック SEO）とみられる**
  - A8 バナーを 3 回置き、「当ページ内のリンク先限定で最大4.5万円のキャッシュバック」と訴求。PR 表記は**無し**
- 参考：タワーマンションガイド（tower-condominium.com）https://tower-condominium.com/network-tower-apartment-slowly/ 。「タワマンでネットが遅い原因と対策」の記事だが、**アフィリエイトリンクは 1 本も無い。** 稼げる語なのに稼いでいない例

---

## 2. 格安SIM

### 2-1. SIMチェンジ（simchange.jp）※小〜中規模の編集部メディア
- URL：https://simchange.jp/kakuyasu-good/
- 運営：「SIMチェンジ編集部」（フッターに会社概要へのリンク）
- 型：**目的別おすすめ 10 選＋データ容量別＋速度別＋キャンペーン別**
- h2：24社比較のおすすめ10選 → 選び方 → 容量別 → 速度別 → キャンペーン → データSIM → メリット・デメリット → 契約方法 → FAQ → まとめ
- ASP：**trafficgate（楽天モバイル）、ValueCommerce（ワイモバイル）、accesstrade（LINEMO・UQ・mineo・IIJmio・イオン・HIS）、ドコモ公式アフィリエイト（ahamo）**。povo と日本通信は直リンク。**A8 は使っていない**
- 置き場所：冒頭の一覧 → 各社の項目末（「＼…／【社名】詳細はこちら」）→ 容量別・速度別・キャンペーン別の各節 → まとめの 3 社。**同じ案件を節を変えて 3〜5 回出している**
- 訴求：楽天「最大40,000円相当おトク」、ワイモバイル「最大20,000pt還元」、LINEMO「最大20,000円相当還元」
- 差別化：みんそくのデータ、家族割の試算表、月末の乗り換えで二重請求になる説明
- PR 表記：本文には無し（サイドバーに「おすすめPR」の欄があるだけ）

### 2-2. お金の和尚さん（okane-osho.com）※個人・手順解説
- URL：https://www.okane-osho.com/mnp-onestop-article/
- 運営：個人（お寺の住職）
- タイトル：MNPワンストップ完全ガイド｜予約番号なしで格安SIMに乗り換える方法
- 型：**手順解説（結論→違い→対応事業者一覧→3ステップ→非対応のとき→事前にやること→FAQ）**
- リンク：**アフィリエイトリンクは 0 本。** IIJmio・LINEMO などの個別記事と「30秒でわかる格安SIM診断」（サイト内）へ送っている
- PR 表記：冒頭に「本記事は広告を含みます（PR）」
- 読み取れること：**手順記事は集客役で、収益は個別記事と診断ページで取る**作り

### 2-3. SIM Note（sim-note.com）※個人・手順解説
- URL：https://sim-note.com/sim/switch/
- 運営：個人（「けんと」）
- 型：**5 ステップの手順＋つながらないときの対処＋FAQ**（h2 は 12 本）
- リンク：**ASP は 0 本。** 内部の /sim/osusume/ などへ誘導している。冒頭のボタン「▶ 乗り換え手続きを始める」はページ内のアンカー
- PR 表記：本文末に「※本記事にはアフィリエイトリンクが含まれる場合があります」
- 2-2 と同じく、**手順記事では売らない**

### 2-4. ギガ通話無制限ドットコム（blogsukisuki.com）※個人・1キャリアの検証
- URL：https://blogsukisuki.com/mobile/rakuten-mobile-speed-test/
- 運営：「ホシノ チカオ」（編集長と名乗る個人）
- タイトル：楽天モバイルの通信速度は遅い？1年以上使った体感と2026年実測データで検証
- 型：**ネガティブな語（遅い？）に答える検証記事**。h2 の例：「都内での通信速度｜同じ山手線でも0.24～249Mbps」「時間帯別」「遅いときの改善方法」「向いている人・慎重に検討したい人」
- ASP：**trafficgate（楽天モバイル）だけ。** 置き場所は結論の直後と、まとめの末尾の 2 か所。CTA は「楽天モバイルの詳細を確認する ＞」。並べて「自分のエリアを確認する ＞」（公式のエリアページ）
- 差別化：みんそく・Opensignal・ICT総研・ALL CONNECT の山手線 30 駅の実測を引いている。**自分で測ったデータは無い**
- PR 表記：冒頭に「このブログでは広告が含まれます」

---

## 3. ポイ活・ポイントサイト

### 3-1. ポイLifeマネー（poitaro.hatenablog.jp）※個人・はてなブログ
- URL：https://poitaro.hatenablog.jp/entry/pointsite_osusume
- 型：**ランキング 7 選＋比較表＋FAQ**
- リンク：**各ポイントサイトの友達紹介 URL**（モッピー・ポイントタウン・ちょびリッチ・ワラウ・ポイントインカム・ECナビ・ハピタス）。比較表と各順位の末尾に置き、CTA は「今すぐ無料で始める（1分でカンタン登録）」「〇〇詳細はこちら」。A8 のバナーは末尾に 1 枚だけ
- 不備：ECナビの比較表のリンクがハピタスの URL になっている
- PR 表記：ページ最上部に「当ブログコンテンツはプロモーションが含まれます」

### 3-2. ピピノブ（pipinobu.com）※個人・陸マイラー
- URL：https://www.pipinobu.com/entry/pointsite-osusume
- 運営：個人（累計 500 万マイル、日経トレンディ掲載、書籍の監修）
- 型：**採点表つきランキング＋使い分け**
- リンク：**ASP は 0 本。全部が紹介 URL**（モッピー・ハピタス・ポイントタウン・ポイントインカム・ECナビ・ポイント獲得ナビ）。各サイトの「お得な入会方法」の末尾とまとめに画像で置いている
- 訴求：**「当ブログ経由の特典」**：モッピーは条件クリアで 2,000 円相当、ポイントインカムは期間限定で最大 3,970 円相当、など。「当ブログはモッピーと協業させていただいており」と書いている
- 不備：採点の合計が合っていない箇所がある
- PR 表記：「PR」「広告」の表記は無し（「スポンサーリンク」と協業の一文だけ）

### 3-3. Wakupen Blog（wakupen.com）※個人・初心者向け
- URL：https://wakupen.com/poikatsu-start/
- タイトル：【5分あればOK！】ポイ活の始め方を初心者向けに分かりやすく解説｜一部収益も大公開！
- 型：**初心者向けの始め方（手順）＋紹介コードの一覧表**
- リンク：紹介 URL を 9 サイト分。CTA は「【特典付き】モッピー新規登録はコチラから！」「〇〇はココから新規登録！」。**末尾に「特典額＋有効期限」つきの一覧**（モッピー最大 12,000 円分・2026/10/31 まで、など）
- 差別化：Booking.com のポイント通帳の画像（15,324 円分）、ワラウフレンズなどの「公式認定」
- PR 表記：タイトルの上に「広告」。本文には無し

### 3-4. 副業クエスト100（kanemotilevel.com）※個人・大物
- URL：https://kanemotilevel.com/moppy
- 運営：個人「きぐち」（モッピーで通算 5,000 万円、書籍あり、A8 のランキング 1 位と名乗る）
- 型：**1 サイトの実績つき解説**
- リンク：サイト内の転送ページ（/point/moppy）を経由する紹介リンクが**約 18 本**。CTA は「モッピー（登録特典あり）」。h2 ごとに置いている
- PR 表記：無し

### 3-5. 補足
- ポイントサイトの紹介報酬は ASP を通らず、**各サイトの紹介 URL が収益源**になっている（友達紹介＋2 ティア）。A8 でも ECナビは 210 円、ポイントインカムは 100 円と単価が低い（daily-hack の `docs/affiliate-registry.md` より）。**ポイ活ジャンルの収益は紹介制度とクレカ案件の送客で取る**のが個人ブログの定石。

---

## 4. クレジットカード

### 4-1. クレカの学び場（cc-lifeblog.com）
- URL：https://cc-lifeblog.com/nenkaifumuryo-creditcard-ranking/
- 型：**ランキング＋用途別の早見表＋FAQ＋番外編**
- リンク：**ランキング本文と比較表には申込リンクが無い。** A8 は番外編にだけ（エポスのバナー、ハピタス、Nexus Card）
- PR 表記：冒頭に「※本記事にはプロモーション（広告）が含まれます。」。バナーの下に「※PR：エポスカード」
- 読み取れること：**エポス以外の提携が取れていないランキング記事**。提携前に記事を書くと収益化できないという典型

### 4-2. ポイ活の窓口（noritetsu.net）※ポイントサイト経由の発行比較
- URL：https://noritetsu.net/blog/creditcard-pointsite/
- 型：**カード×ポイントサイトの還元額の早見表**（年会費無料・有料・ゴールド・ビジネスの 5 区分）
- リンク：ハピタス・モッピー・ちょびリッチの紹介 URL ＋**ポイントサイト内のカード案件ページへの直リンク**（chobirich.com/ad_details/…、m.hapitas.jp/item/detail/…）。ASP は 0 本
- 訴求：三井住友カード（NL）はハピタスで 14,000 円相当、楽天カードはハピタスで 10,600 円相当、など
- PR 表記：冒頭に「当ページのリンクの一部には広告が含まれています。」

### 4-3. ポイントサイトで美味しいワイン（pointsite-wine.com）※個人
- URL：https://pointsite-wine.com/earn-by-pointsite-creating-credit-card
- 運営：個人「バカワイン」（累計 600 万円以上、友達紹介 6,000 人以上と自己申告）
- 型：**「クレカはポイントサイト経由で作る」の解説**
- リンク：ハピタス・モッピー・ちょびリッチなどの紹介 URL をバナーで。カードの申込リンクは 0 本。保険マンモス（catsys）のバナーがサイドバーにある
- 差別化：自分が作ったカードの獲得額の表（楽天カード 10,000 円分、三井住友カード NL 7,000 円分など）、累計ポイントの画像
- PR 表記：明確な開示は無し

### 4-4. The Goal（matsunosuke.jp）※個人・上級者
- URL：https://matsunosuke.jp/recommended-creditcard/
- 運営：個人（63 枚のカードを保有した経験と記載）
- 型：**年間利用額別の最高還元カード一覧＋上級者向けの長文（10 万字超）**
- ASP：**楽天（hb.afl）、ValueCommerce（JCB・アメックス）、J-A-NET（リクルート・エポス・ダイナース等）、trafficgate（楽天カード・イオン）、accesstrade（PayPayカード・JRE）**。三井住友カードは自分では提携せず、**「おすすめポイントサイト」（ハピタス・モッピー等）の紹介 URL で送っている**
- CTA：「公式サイト」「公式キャンペーン」の文字リンク（ボタンではない）
- 差別化：実物カードの写真、マイル積算の画面、ポイント交換ルートの換算
- PR 表記：無し

---

## 5. ふるさと納税

### 5-1. ぐるぐる（grgr135.com）※小規模・会社運営
- URL：https://grgr135.com/furusatonouzei2/
- 型：**サイトを 1 つずつ紹介し、最後に比較表**
- ASP：**楽天（hb.afl）、A8（さとふる・au PAY・ふるさと本舗）、ValueCommerce（ふるなび・ふるラボ）。** 各サイトの冒頭に画像を 1 枚ずつ。比較表にはリンクが無い
- PR 表記：無し

### 5-2. ふるさと納税ガイド（furu-sato.com）※小規模の専門メディア
- URL：https://furu-sato.com/recommend_site
- 型：**22 サイトの一覧→BEST3→キャンペーン→選び方→完全比較表→各サイト解説→返礼品ランキング**
- ASP：**ASP を 9 社以上使い分けている**。楽天（hb.afl）、**i-mobile（ふるなび）**、accesstrade（チョイス・さとふる・ANA ほか）、ValueCommerce（Yahoo!・三越伊勢丹）、**J-A-NET（JAL）**、**LinkShare（au PAY）**、mopo、afi-b（ぐるなび）、felmat、Amazon アソシエイト
- CTA：「〇〇を見る」「〇〇で返礼品を探す」「詳しく見る」
- 訴求：楽天は「5と0のつく日は最大7%」、ふるなびは「10万円寄付で実質3,846円お得」と試算
- PR 表記：上部に「本サイトはプロモーションが含まれています。」

### 5-3. わがやん（furusatotax-blog.com）※個人・大物
- URL：https://furusatotax-blog.com/repeat/
- 運営：個人（13 年で 1,100 品。ダイヤモンドZAi・レタスクラブ掲載、著書あり）
- 型：**「何度もリピートした返礼品 TOP25」**。リピート回数で順位をつける（さがびより米とシャインマスカットが 35 回）
- リンク：**1 品ごとに 2〜4 ボタン**（楽天 a.r10.to、ふるなび、さとふる、ふるさとチョイス〔accesstrade〕）。ボタンの文言はサイト名だけ
- 差別化：自分の Excel で数えたリピート回数（1,100 品のうち 680 品が 2 回以上）、実物の写真
- PR 表記：上部に「当ブログはアフィリエイトプログラムを利用しています」

### 5-4. さとれぽ（furusatorepo.com）※個人
- URL：https://www.furusatorepo.com/2024/01/yokatta.html
- 型：**よかったもの 11 選（食べ物・無印・食べ物以外・保存容器・布団）**
- リンク：**1 品あたり 3 ボタン（ふるさとチョイス・ふるなび〔ValueCommerce〕・楽天ふるさと納税〔hb.afl〕）**
- 差別化：自分で撮った写真を複数、寄付額、使用期間（レミパンは約 1 年 10 か月）
- PR 表記：冒頭に「本ページは広告が含まれています」

### 5-5. 経済圏のお役立ち情報（kmablog.com）※個人・主婦
- URL：https://kmablog.com/hurusatonouzei-shokuhin/
- 型：**食品 12 選（肉・魚・米・野菜・果物・デザート）**
- リンク：**もしも（楽天市場）＋Yahoo!ショッピングの 2 ボタン**（ポチップ）。さとふるは ValueCommerce
- 特徴：PayPay 経済圏の主婦という立ち位置で、さとふる・ふるなびを PayPay と結びつけて送っている
- PR 表記：冒頭に「※この記事はPRを含みます。」

---

## 6. 旅行・ホテル予約

### 6-1. Ordinary Trip（ordinary-trip.com）※独自調査あり
- URL：https://www.ordinary-trip.com/column/ota-recommend
- 型：**独自の価格調査＋サイト別の解説**（海外ホテル）
- 調査：15 か国、HIS の人気ホテルランキング 1〜3 位。2026/1/4〜6 に、約 3 か月後の宿泊日・会員登録なし・シークレットモード・同時刻・税込の条件で調べた（ただし「48ホテル」と「45ホテル」で数字が合っていない）
- ASP：**楽天（hb.afl）、LinkShare（Trip.com）、A8（agoda・Booking.com）、ValueCommerce（HIS）**。Expedia と Hotels.com は直リンク
- CTA：冒頭のまとめに「＞ 公式サイト」、各節に「〇〇を見る」「セール・クーポン一覧」
- PR 表記：「広告」「スポンサーリンク」の表示だけ

### 6-2. にちじょうくんのブログ（nichijo-kun.com）※個人
- URL：https://nichijo-kun.com/hotel-booking-sites-comparison-2026/
- 型：**「先に比べる条件を決める」手順型の比較**
- ASP：A8（一休）、**もしも（楽天トラベル）**、tkqlhce.com（CJ 系。Hotels.com・Expedia）。じゃらんと Yahoo!トラベルは直リンク
- CTA：「同じ宿をHotels.comで見る →」「一休.comで条件を見る →」。**「見る」「確認する」に寄せた文言**
- 差別化：2026/8/21 に各社の公式ページを確認したと日付つきで書いている。「根拠のない点数をつけない」と明言
- PR 表記：**4 か所**（カテゴリ行・タイトル直下・結論の直下・リンク群の直前）。調べた中で一番ていねい

### 6-3. るぴなす速報（p-lupinus.jp）
- URL：https://www.p-lupinus.jp/rakuten-ikkyu-hikaku/
- 型：**2 社比較を 10 項目で**
- リンク：**楽天トラベル（もしも）12 回、一休 3 回（パラメータ無しの直リンク）。** 「10項目中9項目で楽天が上」という結論は、**提携しているほうへ送る構成**になっている
- PR 表記：上部に「アフィリエイト広告を利用しています」

### 6-4. かずトリップ（kazu-trip.com）／たびと（tabito-travel.com）※個人
- https://kazu-trip.com/hotel-reservation-compare/ ：ValueCommerce（一休・じゃらん・Yahoo!トラベル・JTB）＋もしも（楽天トラベル）。CTA は「▶︎ 上質な宿を探すなら【一休.com】公式サイトへ」のように**用途を文言に入れている**。PR 表記は無し
- https://tabito-travel.com/blog/ikyu-rakuten-expedia-comparison/ ：ValueCommerce（一休・Expedia）＋楽天（hb.afl）。「価格比較」の h2 はあるが、**実際の価格データは無い**。PR は目次の前に表示

---

## 7. 地域×生活（湾岸・タワマン）

| サイト | URL | 運営 | 収益の取り方 | 読み取れること |
| --- | --- | --- | --- | --- |
| at tokyo bayside | https://ariakeariel.com/tawaman_kokai/ | 個人（有明在住） | 「スポンサーリンク」のディスプレイ広告＋Amazon の書籍 7 点のみ | 「タワマンを買って後悔？」という**本音の型**で集客。ASP 案件は 0 本 |
| とよすと | https://toyosu.tokyo/life/harumi-flag-mansion-2024/ | 地域メディア | ディスプレイ広告＋Amazon のタイムセール＋求人広告 | 歩いて撮る現地レポート。アフィリエイトは**光回線の記事（§1-5）だけ** |
| しろくま無添加 くらしの便利帳 | https://blog.shirokumachan.com/harumi-flag-for-rental/ | 個人 | **ValueCommerce の SUUMO 賃貸**（バナー 2 回＋文字リンク 1 回）＋一条工務店の紹介制度 | **地域の物件ネタ→賃貸ポータル**の送客。家賃の実例（PORT VILLAGE 3LDK 32 万円等）と利回りの試算 |
| samayuママの3人子育てブログ | https://threechildrenmom-funnyblog.com/harumi-flag-move-in-date/ | 個人 | A8 の画像バナー 1 枚（中身は画像なので判別不能） | 入居時期・戸数・施工会社のまとめ。案件とのつながりは弱い |
| 湾岸マンション価格ナビ | https://wangan-mansion.jp/ | 不動産会社（ケイズワン）系 | **自社で査定・仲介**、バナー広告、[PR]物件 | 163 棟のマンション別ページ。**査定の送客は不動産会社自身が握っている** |
| 湾岸ナビ | https://wangannavi.com/2020/05/31/toyosu-naraigoto-lalaport/ | 個人（湾岸在住 9 年と検索結果にあった） | **取れなかった（HTTP 403）** | — |

### 7-1. daily-hack が強い「公式の数字のランキング」の競合
- **Re-urbanization（saitoshika-west.com）** https://saitoshika-west.com/blog-entry-10254.html ：三井不動産の 2025 年度売上を前年比の表つきで並べている。出典 12 件を「発行元・資料名・公表日」つきで列挙。**収益はディスプレイ広告だけ（スポンサードリンクの枠が 5 つ）。ASP は 0 本**
- **Enjoy EXPO（osaka1shop2channel.jp）** https://osaka1shop2channel.jp/blog-entry-1104.html ：ららぽーと 21 位まで、MOP 11 位まで。前年比は無し。収益は「スポンサーサイト」枠
- 検索結果には daily-hack の「ららぽーと完全ガイド 2026」も出ていた。**この型の競合はどれもディスプレイ広告だけで、アフィリエイトの導線を持っていない。**

---

## 8. 大手メディア（比較のため 1 行ずつ）

- マイベスト（my-best.com）：ポイントサイト・年会費無料カード・ふるさと納税・ホテル予約の「おすすめ」でいずれも上位に出た
- エクシア（exidea.co.jp）：光回線・クレカ・NURO光の口コミで上位を独占していた
- Selectra（selectra.jp）：光回線の「選び方」「乗り換え」系はほぼこのサイトが占めていた
- オリコン（life.oricon.co.jp）：クレカ・ふるさと納税で満足度ランキングが上位
- 価格.com・ITmedia は今回の検索結果の上位には出てこなかった

---

## 9. ジャンルを横断して見えたこと

1. **ASP の使い分けが収益の差になっている。** 稼いでいるサイトほど、案件ごとに単価の高い ASP を選んでいる。格安SIM は accesstrade・trafficgate・ValueCommerce、ふるさと納税は i-mobile・LinkShare・J-A-NET、旅行は LinkShare（Trip.com）・CJ（Hotels.com）。**A8 だけで済ませているのは小さいサイト**だった。
2. **同じ案件を 3〜5 回出す。** 冒頭の結論・比較表・各項目の末尾・まとめに置くのが標準の形（明日も明るく、SIMチェンジ、りょうブログ、ピピノブ）。
3. **手順・解説の記事では売らない。** 格安SIM の乗り換え手順の記事は、2 件とも ASP リンクが 0 本だった。おすすめ記事や診断ページに内部リンクで送っている。
4. **ポイ活とクレカは「紹介 URL」と「ポイントサイト経由」で稼いでいる。** ASP のクレカ案件が取れなくても、ポイントサイトの紹介制度で送客できる（The Goal は三井住友カードをこの方法で送っていた）。
5. **CTA は「申し込む」より「確認する／見る」が増えている。** 「提供エリアと現在の料金を公式で確認する」「同じ宿をHotels.comで見る →」。
6. **差別化は「自分のデータ」。** 実測（りょうブログ）、リピート回数（わがやん）、価格調査（Ordinary Trip）、物件の一覧（とよすと・hikari-fast）。**大手が持っていない一次データがあるページだけが、個人でも上位に出ていた。**
7. **PR 表記はばらばら。** 冒頭に 1 行が多数派。一方で表記が無いサイトも 3 割ほどあった（明日も明るく、ピピノブ、hikari-fast、The Goal、kazu-trip など）。daily-hack は真似しない。

---

## (a) ジャンル別：個人ブログが勝てている検索語の型

| ジャンル | 勝てている型 | 実例 |
| --- | --- | --- |
| 光回線 | 「回線名＋マンション＋実際に／感想」「回線名＋開通まで」「**地域名＋回線名＋導入済みマンション**」「〇〇が遅い 原因」 | ryou-blog、yomichii-blog、toyosu.tokyo、hikari-fast |
| 格安SIM | 「キャリア名＋遅い？＋1年使った」「乗り換え 手順」「MNPワンストップ」（手順記事で集めて、おすすめ記事へ送る） | blogsukisuki、okane-osho、sim-note |
| ポイ活 | 「ポイ活 始め方」「〇〇（サイト名）だけで稼ぐ」「招待コード／入会特典」「〇〇経由 何円」 | wakupen、kanemotilevel、pipinobu |
| クレカ | 「クレカ ポイントサイト経由 どこ」「年間利用額別」「〇〇カード 何年使った」 | noritetsu、pointsite-wine、matsunosuke |
| ふるさと納税 | 「ふるさと納税 よかったもの／リピート」「主婦／経済圏＋返礼品」 | furusatotax-blog、furusatorepo、kmablog |
| 旅行 | 「A と B 比較 どっちがお得」「どこが安い（独自調査）」 | p-lupinus、ordinary-trip、nichijo-kun |
| 地域 | 「地域名＋住んで後悔／本音」「物件名＋賃貸 家賃」「物件名＋入居時期」 | ariakeariel、shirokumachan、samayuママ |

## (b) daily-hack が真似できる型 トップ10

| # | 型 | なぜ効くか | 合う案件（ASP） |
| --- | --- | --- | --- |
| 1 | **湾岸のマンション別「NURO光／光配線 対応状況」一覧**（豊洲・有明・晴海・勝どき） | 地域×回線は大手が手薄で、とよすとの 2018 年の記事がまだ残っている。daily-hack の「公式の数字を並べる」強みがそのまま使える | NURO光（A8）、auひかり（ValueCommerce）、GMOとくとくBB の代理店（A8） |
| 2 | **「タワマンのネットが遅い」切り分け＋個別契約の手順** | 稼げる語なのに、上位のタワーマンションガイドはアフィリエイト 0 本。VDSL／光配線の見分け方は一次情報で書ける | NURO光・ドコモ光・ソフトバンク光（A8）、メッシュ Wi-Fi（楽天・Amazon） |
| 3 | **ららぽーと等の「売上ランキング」記事に、生活の案件を足す** | 競合はディスプレイ広告だけ。施設のポイントカード・クレカに自然につながる | 三井ショッピングパークカード《セゾン》（A8・審査中）、楽天・Yahoo! の商品 |
| 4 | **「ポイントサイト経由でクレカを作ると何円」の早見表（月次更新）** | 紹介 URL だけで収益になり、ASP の審査を待たなくてよい。daily-hack の既存の pointsite-comparison 記事と相性がよい | ハピタス・モッピー・ポイントインカムの紹介制度、ポイントインカム（A8） |
| 5 | **格安SIM「〇〇は都内で遅い？」湾岸の駅・タワマン高層階での実測** | blogsukisuki は熊本在住で、都内は他社データの借り物。湾岸の実測は一次情報になる | 楽天モバイル（trafficgate）、LINEMO・UQ（accesstrade）、ワイモバイル（ValueCommerce） |
| 6 | **手順記事（MNP ワンストップ・光回線の乗り換え）＝集客役、おすすめ記事＝収益役の 2 本立て** | 個人ブログ 2 件とも手順記事は売らずに内部リンクで送っていた。daily-hack の cheap-sim 系記事への入口になる | 上の 5 と同じ |
| 7 | **ふるさと納税「湾岸の家庭で何度も頼んだもの」（冷凍庫が小さいマンション向け）** | リピート型は個人が勝っている。「タワマンの冷凍庫・宅配ボックスに入る」は地域性が出る切り口 | 楽天ふるさと納税（楽天）、ふるなび（i-mobile／ValueCommerce）、さとふる（accesstrade／ValueCommerce） |
| 8 | **「一休と楽天トラベル、同じ湾岸ホテルで比べたら」実際の価格調査** | 価格データを持っていない記事が多い。条件と日付を書けば差がつく（Ordinary Trip の方法を写す） | 一休（A8／ValueCommerce）、楽天トラベル（もしも／楽天）、Trip.com（LinkShare） |
| 9 | **「湾岸に引っ越すときの固定費の見直し」まとめ（光・SIM・電気・保険）** | 引っ越しの時期は乗り換えが重なる。daily-hack の fixed-cost 記事を地域向けに分けて作る | 光回線（A8）、電気・ガス、引越し見積もり（A8／accesstrade） |
| 10 | **「物件名＋賃貸 家賃」の実例まとめ**（晴海フラッグ・勝どき・豊洲） | しろくま無添加が SUUMO 賃貸で送客している型。daily-hack は公開情報から並べられる | SUUMO（ValueCommerce）、賃貸ポータル各社 |

## (c) 避けるべき型

- **「光回線 おすすめ」「格安SIM おすすめ」「年会費無料 クレジットカード おすすめ」「ポイントサイト おすすめ」「ふるさと納税 サイト 比較」「ホテル 予約サイト 比較」の単体語。** どの検索でも上位はマイベスト・エクシア・Selectra・オリコン・企業メディアだった。個人は「体験」「〇〇年使った」などの修飾が付いたときにしか出てこない。
- **「豊洲 住みやすさ」「武蔵小杉 住みやすさ」。** 上位は HOME'S・アットホーム・スマイティ・SUUMO などの不動産ポータルで、個人ブログは 1 件も出なかった。地域ネタは「住みやすさ」ではなく、具体的な物件・設備・数字（回線・家賃・売上）で切る。
- **「タワマン 売却 査定」。** 上位は不動産会社と査定ポータルで、湾岸マンション価格ナビのように仲介会社が自社で査定の送客を握っている。
- **提携が通る前に書くランキング記事。** cc-lifeblog はランキング本文に申込リンクが 1 本も無かった。daily-hack は A8 のクレカ 5 件が審査中なので、**通ってから書く、または紹介 URL で組む。**
- **PR 表記の無い記事・キャッシュバック額が食い違う記事。** 競合のうち数サイトでこれが起きていた。景品表示法（ステマ規制）と信頼の両面で、真似してはいけない。

---

## 出典 URL（WebFetch で開いたもの）

取れたもの（36）
1. https://ashitamoakaruku.com/comparison/
2. https://wifi-torisetsu.com/hikarikaisen-erabikata/
3. https://tower-condominium.com/network-tower-apartment-slowly/
4. https://ryou-blog.com/nuro-mansion/
5. https://yomichii-blog.com/nuro-mansion/
6. https://toyosu.tokyo/life/nuro-hikari-for-mansion-toyosu/
7. https://hikari-fast.jp/nuro-mansion/東京都/江東区/
8. https://simchange.jp/kakuyasu-good/
9. https://www.okane-osho.com/mnp-onestop-article/
10. https://sim-note.com/sim/switch/
11. https://blogsukisuki.com/mobile/rakuten-mobile-speed-test/
12. https://poitaro.hatenablog.jp/entry/pointsite_osusume
13. https://www.pipinobu.com/entry/pointsite-osusume
14. https://wakupen.com/poikatsu-start/
15. https://kanemotilevel.com/moppy
16. https://cc-lifeblog.com/nenkaifumuryo-creditcard-ranking/
17. https://noritetsu.net/blog/creditcard-pointsite/
18. https://pointsite-wine.com/earn-by-pointsite-creating-credit-card
19. https://matsunosuke.jp/recommended-creditcard/
20. https://grgr135.com/furusatonouzei2/
21. https://furu-sato.com/recommend_site
22. https://furusatotax-blog.com/repeat/
23. https://www.furusatorepo.com/2024/01/yokatta.html
24. https://kmablog.com/hurusatonouzei-shokuhin/
25. https://www.ordinary-trip.com/column/ota-recommend
26. https://nichijo-kun.com/hotel-booking-sites-comparison-2026/
27. https://www.p-lupinus.jp/rakuten-ikkyu-hikaku/
28. https://kazu-trip.com/hotel-reservation-compare/
29. https://tabito-travel.com/blog/ikyu-rakuten-expedia-comparison/
30. https://ariakeariel.com/tawaman_kokai/
31. https://toyosu.tokyo/life/harumi-flag-mansion-2024/
32. https://blog.shirokumachan.com/harumi-flag-for-rental/
33. https://threechildrenmom-funnyblog.com/harumi-flag-move-in-date/
34. https://wangan-mansion.jp/
35. https://saitoshika-west.com/blog-entry-10254.html
36. https://osaka1shop2channel.jp/blog-entry-1104.html

取れなかったもの（2）
- https://yagokoro-lab.com/apartment-haisen/ （HTTP 401）
- https://wangannavi.com/2020/05/31/toyosu-naraigoto-lalaport/ （HTTP 403・curl でも 403）

※ matsunosuke.jp と furu-sato.com は本文が長く、10 万字を超えた分（後半）は読んでいない。
