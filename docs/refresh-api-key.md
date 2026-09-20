# 記事リフレッシュに使う API キーの置き方

**このジョブだけが Console の従量課金を使う。** 置くまでは、毎朝 05:30 に起動して
**何もせずに終わる**（鍵が無ければ API を呼ばない作りにしてある）。

## 費用（置いたあとに発生するもの・最上位ルール 2-B）

| 単位 | 金額 |
| --- | --- |
| 1 回あたり | **約 $0.07**（**推定**） |
| 1 日あたり | **約 $0.07**（1 日 1 本） |
| 1 か月あたり | **約 $2.1** |

**推定の前提**: `claude-sonnet-5`（$2 / $10 per MTok・`claude-api` スキルの料金表）、
入力 2 万トークン・出力 3 千トークン。**実額は `ops/data/refresh-state.json` の
`total_usd` に積まれる。** 推定のままにしない。

いま動いている他の反復ジョブは **$0.021/日・約 $0.63/月（実測）** なので、
合計は **約 $2.7/月** の見込み。

## 手順（Mac で 1 回だけ）

1. [Anthropic Console](https://console.anthropic.com/settings/keys) で API キーを発行する
2. Mac のターミナルで、`~/openclaw/config/.env` に 1 行 足す

   ```bash
   mkdir -p ~/openclaw/config
   printf 'ANTHROPIC_API_KEY=%s\n' 'sk-ant-...' >> ~/openclaw/config/.env
   chmod 600 ~/openclaw/config/.env
   ```

   **`sk-ant-...` の部分を実際の鍵に置き換える。** `printf` を使うのは、
   `echo` だと履歴やクォートの扱いで事故りやすいため。

3. それだけ。**再起動も再ロードも要らない。**
   ジョブは毎回この順に探す。

   ```text
   環境変数 → ~/openclaw/config/.env → launchctl getenv → launchd の plist
   ```

## 置けたことの確かめ方

**`ops/tasks` にタスクを 1 本 置けば、30 分以内に確かめられる**（値は出さずに
長さだけ出す作り）。`t144-refresh-key-verify.sh` と同じものを番号だけ変えて出す。

**鍵そのものをチャットや Slack に貼らないこと。**
`ops/tasks` の出力は**公開リポジトリに載る**ので、タスク側でも値は出さない。

## なぜ 2026-09-20 に見つからなかったか

| 見たところ | 結果 |
| --- | --- |
| シェルの環境変数 | 空 |
| `~/openclaw/config/.env` ほか | 行が無い |
| `launchctl getenv` | **未設定でも rc=0**。値を取ったら空（最上位ルール 13） |
| `com.bubblesnow.remote*.plist` | 名前は出てくるが、`plutil -extract` で**値が取れない** |

**X 系のジョブが毎日 $0.021 使っている**ので鍵は在るはずだが、
上のどこからも読めなかった。**新しく発行して置くのがいちばん速い。**
