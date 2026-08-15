# 別セッションの会話ログを持ち出して、続きを別の場所で話す

`daily-hack-blog2` のように **Mac 上で動く bridge セッション**の会話は、Mac の
`~/.claude/projects/<プロジェクト>/<session-uuid>.jsonl` にしか無い。クラウドセッションからは
SSH も届かない（[`session-recovery.md`](./session-recovery.md)）ため、**ログを Git に載せて渡す**のが
唯一の確実な経路になる。

そのための道具が [`scripts/export-session-log.mjs`](../scripts/export-session-log.mjs)。
**Claude のログインは要らない。** JSONL を読んで Markdown に整形するだけなので、
`Not logged in · Please run /login` で会話できなくなったセッションのログでも取り出せる。

## Mac 側でやること

```bash
# 1. リポジトリへ移動（クローン先は決め打ちにしない）
ls ~/.claude/projects/ | grep -i daily-hack     # ハイフン区切りで実パスが入っている
cd ~/projects/anta-baka-x/blog && git pull

# 2. どのセッションかを一覧から特定する
node scripts/export-session-log.mjs --list --project daily-hack

# 3. 書き出してブランチに push する（session-log/<label> ブランチが作られる）
node scripts/export-session-log.mjs <session-uuid> --label blog2 --push
```

session-uuid が分からないときは本文で探せる。

```bash
node scripts/export-session-log.mjs --list --grep "ららぽーと"
```

## クラウドセッション側でやること

```bash
git fetch origin session-log/blog2
git checkout session-log/blog2 -- docs/session-logs/blog2.md
```

`docs/session-logs/blog2.md` を読めば、そのセッションの文脈をそのまま引き継げる。

## 出力の中身

| 残すもの | 落とすもの |
| --- | --- |
| ユーザーの発言（全文、既定 4000 字で切る） | ツール結果の本文（巨大なので） |
| Claude の応答テキスト | thinking（`--include-thinking` で復活） |
| 呼んだツール名と主な引数 1 行 | フック出力・メタ行 |

## 注意

- **機密が混ざる。** API キーらしき文字列（`sk-ant-`, `xoxb-`, `ghp_`, `AKIA`, JWT など）は
  `[REDACTED]` に置換しているが、パターンに載らない秘密は残る。**push 前に必ず目視で確認する。**
- `main` は保護ブランチ。`--push` は `session-log/<label>` ブランチへ送る。直接 `main` へは入れない。
- 会話が長いと Markdown も大きくなる。`--max-chars` で 1 メッセージあたりの上限を調整できる。

## 主なオプション

| オプション | 意味 |
| --- | --- |
| `--list` | 履歴一覧（新しい順）。`--project` / `--grep` / `--limit` で絞る |
| `--label <名前>` | 出力ファイル名とブランチ名に使う |
| `--out <パス>` | 出力先を明示する（既定は `docs/session-logs/<label>.md`） |
| `--max-chars N` | 1 メッセージあたりの文字数上限（既定 4000） |
| `--include-thinking` | thinking も残す |
| `--no-tools` | ツール呼び出し行を出さない |
| `--push` / `--branch` | commit して push する／ブランチ名を指定する |
