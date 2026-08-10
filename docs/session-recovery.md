# セッションが「もう会話できません」になったときの復旧手順

## まず知っておくこと

**会話履歴は消えていない。** 失われるのは Web からセッションへの「接続」であって、
会話そのものではない。セッション一覧に出る次のエラーがこの状態を指す。

```text
environment_deleted:
The environment this session was running on has been deleted; its state cannot be recovered.
```

「state cannot be recovered」が指すのは**実行環境（コンテナやブリッジ接続）の状態**であって、
トランスクリプトではない。

## セッションの種類を確認する

復旧方法は種類によって変わる。セッションの `environment_kind` で判別する。

| 種類 | 実体 | 会話履歴の保存場所 | 復旧方法 |
| --- | --- | --- | --- |
| `bridge` | 自分のマシンで動く CLI セッションを `/remote-control` で Web に公開したもの | **自分のマシン** の `~/.claude/projects/` | `claude --resume` |
| `anthropic_cloud` | Anthropic 側の VM で動くクラウドセッション | Anthropic 側 | セッションを開き直すと VM が再作成される。ローカルに引くなら `claude --teleport <session-id>` |

## bridge セッションの復旧手順

1. ローカルでリポジトリのディレクトリに移動する。

   ```bash
   cd ~/path/to/daily-hack
   ```

2. 履歴一覧から該当セッションを選んで再開する。

   ```bash
   claude --resume
   ```

   セッションを直接指定する場合は `claude --resume <session-id>`。

3. 再び Web やスマホから操作したい場合は、再開したセッション内で実行する。

   ```text
   /remote-control
   ```

`--resume` は**このマシンのローカル履歴**から会話を開き直すコマンドで、クラウドセッションの
一覧は表示しない。クラウドセッションを引く `--teleport` とは別物なので混同しないこと。

## 履歴ファイルを直接確認する

`--resume` の一覧に出ない場合は、実ファイルの有無を確認する。

```bash
ls -lt ~/.claude/projects/*/*.jsonl | head
```

プロジェクトごとのディレクトリに、セッション単位の JSONL が入っている。
ファイルが存在すれば会話は残っている。

## 断絶に強くするために

- 重要な状態は会話の中だけに置かず、[`docs/session-handoff.md`](./session-handoff.md) に書き出す。
  Git にコミットされるため、環境が消えても残る。
- 作業を終える前に記録を追加する。

  ```bash
  npm run handoff -- "やったこと" --next "次にやること"
  ```

- 新しいセッションは `.claude/hooks/session-start.sh` が引き継ぎメモを自動で読み込むため、
  手動で状況を説明し直す必要がない。
