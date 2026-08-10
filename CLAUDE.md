# CLAUDE.md

## セッションの引き継ぎ

会話の中だけに状況を残さない。セッションの実行環境（コンテナやブリッジ接続）は予告なく
消えることがあり、そうなると会話からは状況を引き出せなくなる。Git にコミットされた
ファイルだけが確実に残る。

- 現在の状況・進行中の作業・次のアクションは [`docs/session-handoff.md`](docs/session-handoff.md) に書く。
- 作業を終える前に記録を追加する。

  ```bash
  npm run handoff -- "やったこと" --next "次にやること"
  ```

- 新しいセッションでは `.claude/hooks/session-start.sh` が上記メモと Git の状態を
  自動で読み込むため、利用者が状況を説明し直す必要はない。
- セッションが操作不能になったときの復旧手順は
  [`docs/session-recovery.md`](docs/session-recovery.md) を参照する。
