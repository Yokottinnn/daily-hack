# 記事の候補と進み具合の管理（作戦室「記事の構想と進み具合」）

> 2026-10-25 利用者の指示:「今後の記事候補と作成開始したときの作成状況はすべて作戦室で確認できるようにステータスを管理できるような機能を作って」。
> 作りは affiliate（`scripts/strategy-board/board.html` の `ideas` ページ）。**記事を書くセッション（blog3・affiliate）は、工程が進むたびに必ずここを書き換える。**

## 置き場所

作戦室（https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN）の db の `ideas` コレクション。1 記事 = 1 文書（文書 ID = 記事の id。英小文字とハイフン）。
読み書きは ArtifactData（`get` で version を見てから `update` に `if_version`）。

## 工程（`status`）

| 値 | 表示 | いつ変えるか | 誰が |
| --- | --- | --- | --- |
| `idea` | 候補 | 候補を足したとき | 候補を出したセッション |
| `picked` | 書くと決めた | 利用者が作戦室でチェックを付けたとき（画面が自動で書く）。依頼表で書くと決まったときも | 利用者・セッション |
| `prep` | 準備中 | 商品・型番・公式の数字・価格・素材を集め始めたとき | 担当 |
| `writing` | 執筆中 | 本文を書き始めたとき | 担当 |
| `review` | 公開前の確認 | PR を出してプレビューができたとき（`pr`・`preview` を入れる） | 担当 |
| `published` | 公開済み | 本番にマージされたとき（`slug`・`publishedAt` を入れる） | 担当 |
| `waiting` | 待ち | 外の事情で止まったとき（**`blocker` に理由を必ず書く**） | 担当 |
| `dropped` | 見送り | 書かないと決めたとき（利用者は画面の「見送る」で書ける） | 利用者・セッション |

旧い値 `requested` は「書くと決めた」として表示する（新しく書くときは使わない）。

## 項目

| 項目 | 中身 |
| --- | --- |
| `title` | 記事の題名案（「題材｜切り口」） |
| `status` | 上の工程 |
| `priority` | `A`・`B`・`C`（並べ方の「優先順」は priority → order） |
| `order` | 同じ優先度の中の順番（小さいほど上） |
| `kind` | 種類。`3 店比較`（楽天・Yahoo!・Amazon のボタン）・`楽天・Yahoo! だけ`・`案件`・`湾岸`・`ランキング` など。画面の「種類」の絞り込みになる |
| `stores` | 3 店ボタンの店（`rakuten`・`yahoo`・`amazon`） |
| `owner` | 担当のセッション（`blog3`・`affiliate`） |
| `keyword` | 狙う検索語（主・副を「／」で区切る） |
| `angle` | 検索する人の「買う前の不安」＝比べる軸 |
| `deadline` | 公開期限（`YYYY-MM-DD`・季節やセールから逆算）。7 日を切ると黄色、過ぎると赤 |
| `trend` | 根拠（季節・トレンド・検索の実績。出典は `docs` に） |
| `programs` | 使う成果（楽天・Yahoo!（LinkSwitch）・もしも Amazon・A8 の案件など） |
| `next` | 次にやること（1 行） |
| `blocker` | 待ちの理由 |
| `slug`・`pr`・`preview` | 記事の URL の slug・PR 番号・プレビュー URL |
| `note` | メモ |
| `history` | 経過。`[{at, status, by, note}]` を**足していく**（消さない） |
| `updatedAt`・`pickedAt`・`publishedAt`・`since` | 時刻（ISO） |

## 書き方（セッション）

```text
ArtifactData get   ideas/<id>                       → version と history を読む
ArtifactData update ideas/<id> if_version=<version>
  { status: "writing", updatedAt: "<今>", next: "比較表を入れる",
    history: [...いまの history, { at: "<今>", status: "writing", by: "blog3", note: "本文に着手" }] }
```

- 公開済みの記事は、作戦室が毎日のスナップショットから**公開後の数字**（読者 28 日・検索 90 日・成果リンク）を自動で出す（`slug` が要る）
- `slug` を入れてあり本番に出ているのに `published` でない記事は「本番に出ているのを検出」と出る → 担当が `published` にする
- 候補の中身（商品・出典）は affiliate の `docs/research/` に置き、`note` にパスを書く
