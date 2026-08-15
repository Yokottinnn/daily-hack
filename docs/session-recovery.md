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

## OAuth 失効 — 無応答に見える最有力の原因

Mac 側のセッションが**何を送っても返さない**とき、まず疑うのは相手の怠慢でも
コネクタ設定でもなく、**OAuth の失効**である。

```text
Failed to authenticate: OAuth session expired and could not be refreshed
```

2026-08-15 にこれが起きた。**クラウド側からは何も見えない。**
`get_session` は `SESSION_STATUS_IDLE` / `connection_status: connected` を返し続け、
トリガーの `fire_trigger` も正常に成功する。**それでもターンは実行されない。**

このとき私は「トリガーにコネクタが乗っていないため報告が外へ出ない」と診断したが、
**それは副次的な要因で、主因は認証切れだった。**

### 見分け方

| 症状 | 意味 |
| --- | --- |
| `fire_trigger` は成功するが Slack に何も出ない | 認証切れの可能性が高い |
| `get_session` が IDLE / connected を返す | **正常の証拠にならない。** 失効中でもこう見える |
| 同じ依頼を送り直しても変わらない | 経路の問題ではなく実行できていない |

**クラウド側から確認する手段は無い。** 利用者に Mac のターミナルを見てもらうしかない。
無応答が続いたら、**送り直す前に利用者へ「ターミナルに何か出ていますか」と聞く。**

### 復旧手順（Mac 側で実行してもらう）

```bash
# 1) 動いている claude を終了する（Ctrl+C を2回、または /exit）

# 2) リポジトリで起動し直す
cd /Users/ny/projects/anta-baka-x/blog
claude

# 3) 起動したら、その中で
/login

# 4) 認証が通ったら、クラウドから届くように公開し直す
/remote-control
```

**`/login` だけでは足りない。** `/remote-control` を実行しないとクラウドから届かない。

## クラウドセッションからは Mac を操作できない

**OpenClaw に関わる作業はクラウドセッションでは進まない。** SSH で届くという前提を
実測したところ、すべて塞がっていた（2026-08-11 に検証）。

| 確認項目 | 結果 |
| --- | --- |
| `ssh` / `scp` / `autossh` | いずれも未インストール |
| `~/.ssh` の鍵 | 1 本も無い |
| `192.168.2.102:22` への TCP | 到達不可 |
| 任意ホストの 22 番（`github.com:22` で検証） | 到達不可 |

外向き通信は `HTTPS_PROXY=http://127.0.0.1:43919` の **HTTPS プロキシ経由のみ**で、
生の TCP が出られないため SSH はプロトコルとして成立しない。加えて `192.168.0.0/16` は
`NO_PROXY` に入っており、プライベート IP はプロキシを通さず直接接続を試みて経路が無く失敗する。

Mac を SSH で操作できること自体は正しい。ただしそれは**手元や LAN 内から**の話であって、
クラウドコンテナからではない。

## OpenClaw を触るときはブリッジセッションを使う

Mac 上で動く CLI セッションを Web に公開する。実行される場所が Mac になるため、
OpenClaw も launchd も直接触れる。

1. Mac のターミナルでリポジトリに移動して起動する。**クローン先は決め打ちにしない。**
   過去のセッションが使ったパスは `~/.claude/projects/` の名前に残っている。

   ```bash
   # ハイフン区切りで実パスが入っている（例: -Users-ny-...-daily-hack）
   ls ~/.claude/projects/ | grep -i daily-hack

   # 見つからなければ探す
   find ~ -maxdepth 4 -type d -name daily-hack -not -path '*/node_modules/*' 2>/dev/null
   ```

   場所が分かったら移動して起動する。

   ```bash
   cd <見つかったパス> && git pull && claude
   ```

2. セッション内で Web に公開する。

   ```text
   /remote-control
   ```

3. 表示された URL を開けば、スマホや別の PC からも操作できる。

4. そのセッションに復旧を依頼する。次をそのまま貼れる。

   ```text
   docs/openclaw-recovery.md の手順で OpenClaw を復旧して。
   bash scripts/openclaw-recover.sh を実行し、MUST rule の復元を再起動より先に行うこと。
   復旧したかどうかは OpenClaw 自身の報告ではなく Slack への実着信で判断して。
   ```

**このクラウドセッションを閉じる必要はない。** ブリッジ側で Mac を触り、
コード変更やリリースはこちらで進める、という並行運用ができる。

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
