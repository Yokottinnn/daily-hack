# アフィリエイト戦略ボード（利用者とコメントでやり取りする場所）

## 本体：マネタイズ作戦室（旧名 収益化作戦室・2026-10-12 から・Artifact の HTML サイト）

> 利用者の指示（10/12）: 内容が浅すぎる。タブ・ページを分け、記事の制作・立案方法と今後のスケジュールを詳細に。
> ひとつのウェブサイトのように Artifacts で。溜まったナレッジ・スキル・ルールを明確に載せ、フィードバックを求めて。

- URL: **https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN**（`capabilities: {db: {}}`）
- ソース: `scripts/strategy-board/board.html`。**直したら同じファイルを scratchpad に写して同じパスで publish し直す**（URL が変わらないように）
- 14 ページ：全体像／**タスク**／現状の数字（**記事を調べる**・どこから来たかの詳細）／ASP と案件／記事づくりの流れ／ルールと教訓／他ブログの分析／戦略／戦術／12 週の予定／X での告知／計測と振り返り／更新履歴／コメント一覧
- **v2（2026-10-12）: コメントは「サイト全体」と「記載ごと」の両方。** 利用者の指示「全体に対してコメントを残すのと、各記載に関してコメントを残せるように両方したい」
  - 記載ごと：段落・表の行・カード・工程・週に `data-cid` を振る（静的な記載は本文の指紋、データの行は `now.top.<slug>` など）。触れると「コメント」が出る
  - 全体：右下のボタン。`scope: "site"`
- **数字は db の `snapshot/latest` から描く。毎週月曜に入れ替わる**（[`strategy-board-routine.md`](./strategy-board-routine.md)）。
  利用者の指示「定期的にアップデートして、その結果を踏まえてサイト自体のコンテンツが変更されていく仕組み」
- **コメントは db の `feedback`**（`scope`・`page`・`cid`・`quote`・`body`・`createdAt`・`reply`）。読む：`ArtifactData list collection=feedback`。
  **返信は `reply` に書く**（`update` ＋ `if_version`）。ページ上で「返信あり」に変わる
- **決めてほしいことのチェックは `decisions/<id>`**（`checked`・`title`・`updatedAt`）
- **何をなぜ変えたかは `changelog`** に残す（サイトの「更新履歴」ページ）
- **タスクは db の `todos/<id>`**（`title`・`owner`(you/claude)・`status`・`why`・`how`・`verify`・`note`・`order`・`since`）。
  状態は `you`（あなたの番）→ 利用者がチェック → `claimed`（確認待ち）→ **Claude が実物で確かめて** `verified`（`note` に何で確かめたか）。
  確かめられなければ `you` に戻し、`note` に何が見えなかったかを書く。`claude` は承認済みで Claude が進めるもの。
  **チャットのダイアログで利用者が「やった」と答えたときも `claimed` と同じに扱い、確かめてから `verified` にする**（利用者の指示 2026-10-12: 「これは終えましたか」の往復を無くす）
- 利用者の 10/12 の指示：**素材（利用画面のスクリーンショットなど）は Claude からタスクでお願いする**。セルフバックは使っていないサービスでもよい
- 作業の区切りごとに feedback と decisions を読みに行く。通知を待たない

## 旧：Claude Docs 版（10/12 の最初の版。上のサイトに置き換えた）

- URL: https://claude.ai/artifact/YHKqCBrib2nwhKGMUszNpD（Claude Docs。2026-10-12 作成）
- Claude Docs の doc id: `fd52cdc1-fe9e-4f3f-b8ad-8a1a3e36530e`／本文ノード: `63c07449-dd10`
- **読み書きは Claude Docs コネクタ（`mcp__Claude_Docs__*`）だけ。** Artifact の publish では変わらない
- **作業の区切りごとにコメントを読みに行く**（`query object=utterance under=本文ノード`）。直したらそのスレッドに返信する
- 決まったことは本文に反映し、ここ（CLAUDE.md・スキル・docs）にも書き写す。ボードだけに置かない

## 進め方（利用者の指示・2026-10-12）

> 一気にまとめてやらなくていいので、ステップバイステップで一つずつ、必要であれば私に確認を取りながら進めて

現状 → 他ブログの分析 → 戦略 → 戦術 → 12 週の計画 → X の告知 → 計測、の順に 1 節ずつ埋める。

## 関連

- ASP の台帳: [`affiliate-registry.md`](./affiliate-registry.md)
- 別リポジトリ `Yokottinnn/daily-hack-affiliate`（セッション「daily-hack-affiliate」）に、ラクヨコ戦略・ASP 計画・コンプライアンスの過去分析がある
