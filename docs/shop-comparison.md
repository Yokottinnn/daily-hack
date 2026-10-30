# 3 店ボタンの比較記事（楽天市場・Yahoo!ショッピング・Amazon）

> 2026-10-25 利用者の指示（決定ログ）:「楽天・アマゾン・Yahoo すべて並べてアフィリエイトで商品を紹介する。どれかで買ってくれたら収入が入る」。
> 形は暮らセレクトの比較記事（https://www.kura-select.com/articles/deodorant-comparison/ ）に似せるが、**観点をシャープにして、購買意欲の高いキーワードで勝つ。**
> 作りは affiliate、記事は blog3（affiliate の `docs/11_shop_comparison_strategy.md` に狙うキーワードと切り口）。

## 1. 記事への書き方（Markdown に 1 行ずつ）

```html
<div data-shop-table="rechargeable-kairo"></div>
<div data-shop-card="rechargeable-kairo:<商品 id>"></div>
<div data-shop-buttons="rechargeable-kairo:<商品 id>"></div>
```

| 書くもの | 出るもの |
| --- | --- |
| `data-shop-table` | 全商品の比較表（仕様の列・いちばん安い店・3 店ボタン）と、価格の時点・PR の注記 |
| `data-shop-card` | 商品カード（推しの札・ひとこと・仕様・3 店の価格と「いちばん安い」印・ボタン・公式の出典） |
| `data-shop-buttons` | 3 店ボタンだけ（見出しの直下など） |

- **1 行で、閉じタグまで書く。** 崩れていたらビルドが落ちる（黙って消えない）
- **`isPR: true` の記事でしか使えない**（使うとビルドが落ちる）。PR 表記と、Yahoo! の成果リンク（LinkSwitch）が isPR の記事でしか効かないため
- **手元でデータの JSON を変えて `astro build` するときは `.astro/` を消してから**（記事の Markdown が変わっていないと、前回の描画が使い回される。CI と Cloudflare は毎回まっさらなので関係ない）
- 置き換えは `src/lib/shop/rehype-shop.mjs`、HTML は `src/lib/shop/render.mjs`、見た目は `src/styles/global.css` の「3 店ボタン」

## 2. データ（`src/data/shop/<シリーズ>.json`）

```jsonc
{
  "id": "rechargeable-kairo", "title": "充電式カイロ",
  "columns": [{ "key": "hours", "label": "連続使用（公称）" }],   // 表とカードに出す仕様の列
  "pricesCheckedAt": null,                                          // apply-prices.mjs が書く
  "items": [{
    "id": "xxx", "brand": "販売元", "name": "正式な製品名 型番",
    "badge": "長く持つ", "summary": "この人にはこれ、の一文", "recommended": false,
    "specs": { "hours": "約8時間（弱）" }, "source": "メーカー公式の URL",
    "rakuten": { "keyword": "型番を含む短い検索語", "must": ["型番"], "exclude": [] },
    "yahoo":   { "keyword": "…", "must": ["型番"] },
    "amazon":  { "keyword": "…", "asin": null }
  }]
}
```

- **仕様は公式の数字だけ**（`source` に出典）。公式に無いものは書かない
- `must` は商品名に必ず含む語（型番）。**似た別商品（色違い・セット・交換用）を拾わないための鍵**。`exclude` で外す語も足せる
- 価格（`price` など）は手で書かない。下の自動取得が書く

## 3. 価格の自動取得（毎日・$0）

| いつ | どこ | 何を |
| --- | --- | --- |
| 毎日 6:40 | Mac `com.dailyhack.board-weekly`（`scripts/strategy-board/mac-weekly.sh` の 2e） | `scripts/shop/fetch-prices.mjs` が楽天市場・Yahoo!ショッピングの API で検索し、`ops/heartbeat` の `reports/board/shop-prices.json` に置く |
| 価格を載せ替えるとき | クラウド（blog3） | `node scripts/shop/apply-prices.mjs` → `src/data/shop/*.json` に書く → PR → マージ |

- 鍵は Mac の Keychain だけに置く（公開リポジトリに出さない）
  - 楽天: `dailyhack-rakuten-ws` の `applicationId`（2026-10-14 登録済み）と **`accessKey`（新 API で必須・未登録）**
  - Yahoo!: `dailyhack-yahoo-shopping` の `clientId`（Yahoo! デベロッパーネットワークのアプリ登録・**未登録**。利用者の OK 済み 2026-10-25）
  - 鍵が無い店は `skipped` になり、価格は空のまま（ボタンは検索結果へのリンクで出る）
- 選び方: 商品名に `must` を全部含む候補のうち「本体価格 − 通常ポイント」が最小の 1 件。**当たりが無ければ価格を消す**（古い価格を出さない）
- 表示する「いちばん安い」は本体価格 − 通常ポイント。送料は足さず「送料別」と書く。SPU・5 のつく日などの上乗せは記事の本文で説明する

## 4. リンクの形と成果

| 店 | リンク | 成果 |
| --- | --- | --- |
| 楽天市場 | `hb.afl.rakuten.co.jp/hgc/<config の affiliateId>/?pc=<商品 or 検索>` | 個人の楽天 ID（決定ログ 2026-10-15）。**法人審査が通ったら `src/data/shop/config.json` の 1 か所を替えれば全記事が替わる** |
| Yahoo!ショッピング | 素の `shopping.yahoo.co.jp`（商品 or 検索） | isPR の記事で LinkSwitch（vc_pid 892728470）が成果リンクに変える。VC「Yahoo!ショッピング 自動提携機能用」提携済み |
| Amazon | `amazon.co.jp/s?k=<検索語>&tag=dailyhack-22`（ASIN があれば `/dp/<ASIN>?tag=…`） | **Amazon アソシエイトに直接（2026-10-30 申し込み）。** もしも経由は 2026-10-28 に否認。`config.json` の `amazon.tag` が null なら Amazon ボタンを出さない |

- **成果リンクになることを実物で確かめた（2026-10-25）**
  - 楽天: 3 店ボタンのリンク → `hb.afl.rakuten.co.jp/ichiba/<ID>` → `pt.afl.rakuten.co.jp/c/587f2635.77bb335f/`（楽天の計測）→ 商品・検索ページ（`scid=af_pc_etc`）。個人 ID で計測される
  - Yahoo!: 本番のドメインに PostLayout と同じ LinkSwitch のタグ（vc_pid 892728470）を置いたページで、素の `store.shopping.yahoo.co.jp`・`shopping.yahoo.co.jp/search` のリンクが読み込み時に `dalr.valuecommerce.com/dck/…?pid=892728470&sid=3776384&mid=2201292` に差し替わった（押しても同じ先へ出ていく）。**isPR: true の記事でだけ効く**（だから isPR でない記事ではビルドを落とす）
  - Amazon: **2026-10-28 にもしもで否認**（理由の開示なし）。**2026-10-30 に Amazon アソシエイトへ直接申し込み、ID `dailyhack-22` でボタンを出した。** 仮の参加中で、申し込みから 180 日以内に適格販売 3 件で本審査（自分の注文は数えない・却下されたら再審査なし）。以下は旧記録：**2026-10-25 22:17 に「申請中」を確認**（審査は数週間かかる場合あり）。通ったら `config.json` の `moshimo*` 4 つを入れ、楽天・Yahoo! と同じく実物で計測を確かめる
  - もしもの告知: 2026-11-01 から Amazon の成果は同じ日の分が 1 件にまとまって表示され、商品情報も取れなくなる。3 店ボタンは Amazon の価格を載せないので影響なし
- 楽天のリンクを使った記事は `docs/affiliate-registry.md` の「楽天アフィリエイトのリンクを入れた記事」に足す（法人 ID への張り替えの一覧）
- 報酬額は記事に書かない

## 5. 記事の型（暮らセレクトより鋭くする点）

暮らセレクトの型（1 位の商品・比較表・選び方・各商品の詳細・FAQ）はそのまま使う。そのうえで:

1. **検索した人の「買う前の不安」を 1 つ決めて、それで並べる**（例: 充電式カイロ＝安全と何時間持つか）。容量あたりの単価で全部を並べない
2. **冒頭で「この人はこれ」を 3 つ言い切る**（用途別の結論＋各 3 店ボタン）。スクロールしないと買えない記事にしない
3. **レビュー件数の少ない商品を 1 位にしない**（暮らセレクトは★5.0（1 件）が 1 位）
4. **元が取れる日数・1 回あたりのコスト**を出す（このサイトの強み。使い捨てとの比較など）
5. 公式の数字には出典、自分で計算した数字には式を書く
