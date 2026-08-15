# 別セッションの会話ログを持ち出して、続きを別の場所で話す

`daily-hack-blog2` のように **Mac 上で動く bridge セッション**の会話は、Mac の
`~/.claude/projects/<プロジェクト>/<session-uuid>.jsonl` にしか無い。クラウドセッションからは
SSH も届かない（[`session-recovery.md`](./session-recovery.md)）ため、**ログを Git に載せて渡す**のが
唯一の確実な経路になる。

そのための道具が [`scripts/export-session-log.mjs`](../scripts/export-session-log.mjs)。
**Claude のログインは要らない。** JSONL を読んで Markdown に整形するだけなので、
`Not logged in · Please run /login` で会話できなくなったセッションのログでも取り出せる。

## Mac 側でやること

**スクリプトはリポジトリの外に置いて実行してよい。** `git rev-parse --show-toplevel` で
リポジトリを見つけるため、`/tmp` から動かしても書き出し先と push 先は正しくなる。
ブランチを切り替えずに済むので、未コミットの変更があっても止まらない。

```bash
# 1. リポジトリへ移動する（クローン先は決め打ちにしない。
#    ~/.claude/projects/ のディレクトリ名に実パスが残っている）
cd ~/projects/anta-baka-x/blog

# 2. スクリプトだけを取り出す（作業ツリーは触らない）
git fetch origin
git show origin/<スクリプトのあるブランチ>:scripts/export-session-log.mjs > /tmp/export-session-log.mjs

# 3. 最新セッションを書き出して push する
node /tmp/export-session-log.mjs --latest --label blog2 --push
```

**`--project daily-hack` は当たらない。** `~/.claude/projects/` のディレクトリ名は cwd を
ハイフンに潰したもので（`-Users-ny-projects-anta-baka-x-blog`）、リポジトリ名とは限らない。
指定を省けば **いま居るリポジトリで動いたセッション**に自動で絞る。全件見るなら `--all`。

スクリプトが `main` に入ったあとは、単に `node scripts/export-session-log.mjs ...` でよい。

`--latest` は条件に合う中で**一番新しい**ログを選ぶ。実行後に session id・期間・最初の発話が
表示されるので、狙ったセッションかどうかはそこで確認する。違っていたら一覧から選び直す。

```bash
node scripts/export-session-log.mjs --list                      # このリポジトリのセッションを新しい順に
node scripts/export-session-log.mjs --list --all                # マシン上の全セッション
node scripts/export-session-log.mjs --list --grep "ららぽーと"    # 本文で探す
node scripts/export-session-log.mjs <session-uuid> --label blog2 --push
```

`--push` は `session-log/<label>` ブランチを作ってそこへ push し、**元いたブランチへ戻す**。
ブランチを作るだけなので、他のファイルの未コミット変更は保持されたまま持ち越される。

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
| `--latest` | 絞り込んだ中の最新を選ぶ（session-uuid を貼らずに済む） |
| `--all` | 「いま居るリポジトリ」で絞る既定を解除し、マシン上の全セッションを対象にする |
| `--label <名前>` | 出力ファイル名とブランチ名に使う |
| `--out <パス>` | 出力先を明示する（既定は `docs/session-logs/<label>.md`） |
| `--max-chars N` | 1 メッセージあたりの文字数上限（既定 4000） |
| `--include-thinking` | thinking も残す |
| `--no-tools` | ツール呼び出し行を出さない |
| `--push` / `--branch` | commit して push する／ブランチ名を指定する |
