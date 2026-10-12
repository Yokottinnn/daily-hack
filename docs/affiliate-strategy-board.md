# アフィリエイト戦略ボード（利用者とコメントでやり取りする場所）

## 本体：収益化作戦室（2026-10-12 から・Artifact の HTML サイト）

> 利用者の指示（10/12）: 内容が浅すぎる。タブ・ページを分け、記事の制作・立案方法と今後のスケジュールを詳細に。
> ひとつのウェブサイトのように Artifacts で。溜まったナレッジ・スキル・ルールを明確に載せ、フィードバックを求めて。

- URL: **https://claude.ai/artifact/9KWGybrAHF7LtbQdVpw9YN**（`capabilities: {db: {}}`）
- ソース: `scripts/strategy-board/board.html`。**直したら同じファイルを scratchpad に写して同じパスで publish し直す**（URL が変わらないように）
- 12 ページ：全体像／現状の数字／ASP と案件／記事づくりの流れ／ルールと教訓／他ブログの分析／戦略／戦術／12 週の予定／X での告知／計測と振り返り／コメント一覧
- **コメントは db の `feedback` コレクション**（`page`・`anchor`・`body`・`createdAt`・`reply`）。読む：`ArtifactData list collection=feedback`。
  **返信は `reply` に書く**（`update` ＋ `if_version`）。ページ上で「返信あり」に変わる
- **決めてほしいことのチェックは `decisions/<id>`**（`checked`・`title`・`updatedAt`）
- 作業の区切りごとに両方を読みに行く。通知を待たない

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
