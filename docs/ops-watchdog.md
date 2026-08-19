# X 運用の外部監視

## なぜ必要か

2026-08-10、Chrome の自動更新（151）が Playwright の接続を壊し、**X 運用のジョブが全停止した。**
リプライ営業もフォロー施策も 5 日間ゼロだった。

問題は止まったこと自体より、**5 日間 誰も気づかなかったこと**にある。
異常を検知する `pipeline-heartbeat` が同じ Mac で動いていたため、Mac が倒れたときに
監視も一緒に倒れた。倒れたことを知らせる者がいなくなった。

同じ構造である限り、また 5 日間気づかない。そこで監視を Mac の外へ出す。

## 仕組み

**Mac は「生きている」と押すだけ。GitHub Actions が「来なくなったこと」を検知する。**

```text
Mac（30分ごと）                      GitHub Actions（2時間ごと）
  scripts/ops-heartbeat.sh             .github/workflows/ops-watchdog.yml
    launchctl list を集める        →     ops/heartbeat を取得
    ops/heartbeat に push                古さと欠落を判定
                                         異常なら Slack へ通知
```

Mac が丸ごと落ちても、**押されないこと自体が異常の証拠**になる。
監視する側が Mac の外にいるため、Mac と一緒に死なない（dead-man's-switch）。

## 判定条件

| 条件 | 閾値 | 意味 |
| --- | --- | --- |
| `stale` | heartbeat が **90 分**より古い | Mac が落ちている、または heartbeat ジョブが止まっている |
| `missing` | 期待するジョブが `launchctl list` に無い | Mac は生きているが特定のジョブだけ死んだ |
| `auth` | `auth.ok` が `false` | Claude の認証が失効している。**セッションは何を送っても返さない** |
| `auth_soon` | トークンの残りが **24 時間**未満 | 失効「前」の警告。切れる前に `/login` できる |
| `silent` | ジョブは載っているのに本日の投稿が **0 件** | 載っているだけで実際は打てていない。今回の事故と同じ形 |

期待するジョブはワークフローの `EXPECTED_JOBS` で定義する。現在は次の 4 つ。

```text
ai.openclaw.comment-warmup          リプライ営業（10 reply/日）
ai.openclaw.incoming-reply-watcher  受信リプ返信（15分ごと）
ai.openclaw.gateway                 OpenClaw の入口
ai.openclaw.node                    本体
```

`poll-approvals` は**意図的に外している。** 滞留エントリの連鎖投稿を防ぐため停止させており、
再開したら `EXPECTED_JOBS` に足す。

## 「載っている」は「動いている」ではない

**`launchctl list` にジョブが居ることは、リプが打てている証拠にならない。**

2026-08-15 にこれが起きた。heartbeat は 30 分ごとに届き、12 ジョブすべてが載っていて、
外形上は完全に正常だった。**それでも実際には何も打てていない可能性があった**（認証切れで
生成が失敗する）。ジョブの死活だけを見ていると、この形の故障は永久に見えない。

そこで heartbeat に**本日の実投稿数**を載せる。

```json
"activity": {
  "date": "2026-08-15",
  "posted_today": 8,
  "detail": "ログを走査した",
  "sources": [{ "file": "comment-warmup.log", "count": 8 }]
}
```

`~/.openclaw/workspace/logs/*.log` から、今日の成功記録を数える。

**検出条件は実機のログ書式に合わせること。** 最初の実装は `tweet_id` という文字列と
`2026-08-16` 形式の日付を条件にしていたが、実機の成功記録は次の形で、
**どちらも含まれていなかった。投稿があっても 0 件と数えていた。**

```text
{"ok":true,"entry_id":"comment-20260816-...     ← ジョブの成功記録
[2026-08-16T19:03:05] today's reply-conn ...    ← 行頭に日時
```

日付の表記が `20260816` と `2026-08-16` の 2 通りあるため、両方を見る。
`grep -c` は行単位で数えるので、両方に当たる行があっても二重には数えない。

**推測でパターンを書かない。** 実機のログを 1 度見れば済む話だった。

### 0 件と「判定不能」を混同しない

ログのディレクトリごと存在しないときも `posted_today` は 0 になる。
**これを「今日は 1 件も打てていない」と読むと誤報になる。**
`detail` が `ログを走査した` のときだけ判定する。

判定は `comment-warmup` の最終発火（13:00 UTC）を過ぎた **14:00 UTC 以降**に行う。
朝の時点で 0 件なのは正常なので、そこでは鳴らさない。

## 認証の失効を、切れる前に知る

2026-08-15、Mac 側の OAuth が失効し、**セッションが 2 時間半 何も返さなくなった。**
クラウドからは `connected` に見え、`fire_trigger` も成功する。症状は「返事が来ない」
ことだけで、**失効を知る手段が無かった。** ジョブの死活を見ていても、これは見えない。

そこで heartbeat に認証の状態を載せる。判定は 2 系統あり、片方が取れなくても効く。

| 経路 | 何を見る | 取れないとき |
| --- | --- | --- |
| 会話ログ | 直近 3 時間に更新された `~/.claude/projects/**/*.jsonl` の**末尾 200KB**に `OAuth session expired` / `Not logged in` が出ていないか | ログ自体は launchd から必ず読める |
| Keychain | `Claude Code-credentials` の `expiresAt`。読めなければ `~/.claude/.credentials.json` を見る | どちらも取れなければ **異常扱いにしない**（`ok: null`） |

**外部インタプリタに依存しない。** 最初の実装は `/usr/bin/python3` で JSON を解いていたが、
実機（手動実行・Keychain が読める状態）でも判定不能のままだった。**解析側が動いていなかった。**
macOS の `/usr/bin/python3` は Command Line Tools を要求することがあり、その場合は黙って失敗する。

```bash
# grep だけで完結させる。秘密は出力しない
grep -o '"expiresAt"[[:space:]]*:[[:space:]]*[0-9]*' | grep -oE '[0-9]+$' | head -1
```

`.credentials.json` は再ログインしても更新されないことがあるため、**Keychain を優先する。**

末尾だけを見るのは、**過去に一度失効すると永久に異常と判定され続けるのを避ける**ため。

```json
"auth": { "ok": false, "expires_at": null, "detail": "直近の会話ログに認証エラーが出ている" }
```

### 落とし穴: `jq` の `//` は false を潰す

```bash
jq -r '.auth.ok // "null"'   # ← false のとき "null" を返す。一生鳴らない
jq -r '.auth.ok | tostring'  # ← 正しい
```

`//` は「null または false」を欠損とみなす演算子で、**まさに検知したい `false` が
握り潰される。** 実測で確認済み。`auth` 欄を持たない旧形式の `heartbeat.json` でも
`tostring` は `"null"` を返すため、誤報にはならない。

## main にマージしても Mac には届かない（自己更新で塞いだ）

**`main` へのマージは、Mac 上のスクリプトを更新しない。**

2026-08-16 に実測した。認証検知を入れた #171 をマージした 18 分後の heartbeat に、
新しい項目が一切載っていなかった。`ops-heartbeat.sh` は `ops/heartbeat` ブランチしか
fetch しておらず、**誰かが手で `git pull` するまで古いまま**という構造だった。

実際、8/15 に認証欄が現れたのは Mac セッションが別作業のついでに pull したためで、
**仕組みとして届いていたわけではなかった。**

そこで heartbeat 自身に自己更新を入れた。30 分ごとに確実に走る唯一のジョブなので、
ここが最新であれば以降の変更は自動で届く。

```bash
git -C "$MAIN_REPO" fetch -q origin main
git -C "$MAIN_REPO" show origin/main:scripts/ops-heartbeat.sh > "$latest"
# 中身が違えば、その場で入れ替えて実行し直す
OPS_HEARTBEAT_SELF_UPDATED=1 exec /bin/bash "$latest" "$@"
```

- **作業ツリーには触らない。** `git pull` は Mac 上で進行中の作業と衝突しうるため、
  `git show` で中身だけ取り出す
- 環境変数で **1 回だけ**に制限する。取り違えても無限ループにならない
- 取得に失敗したら、そのまま古い版で走る。**heartbeat が止まる方が害が大きい**

### 最初の一回だけは手で pull が要る

自己更新のコード自体が Mac に無いため、**これを有効にする最初の 1 回だけは
`git pull` が必要**（Mac セッションか OpenClaw に頼む）。以降は自動で追随する。

## 押す側の設定（Mac）

`scripts/ops-heartbeat.sh` を 30 分ごとに実行する。

```bash
bash scripts/ops-heartbeat.sh
```

進行中の作業と衝突しないよう、**専用の worktree**（`~/.openclaw/ops-heartbeat-wt`）で動く。
リポジトリの作業ツリーには触らない。履歴が伸びないよう毎回 force push で 1 コミットに潰す。

環境変数で場所を変えられる。

| 変数 | 既定値 |
| --- | --- |
| `DAILY_HACK_REPO` | `/Users/ny/projects/anta-baka-x/blog` |
| `OPS_HEARTBEAT_WORKTREE` | `~/.openclaw/ops-heartbeat-wt` |
| `OPS_HEARTBEAT_BRANCH` | `ops/heartbeat` |

## 鳴らない状態を作らないために

- **`ops/heartbeat` ブランチが無い間、Slack には通知しない。** 登録前に鳴り続けるのを避けるため。
  代わりに Actions の Summary に「未設定」と出る。**未設定は監視ゼロと同じなので放置しない。**
- 異常検知時はワークフロー自体も `exit 1` で失敗させる。Slack を見落としても
  GitHub の失敗通知が残る。
- 通知は 2 時間ごとに繰り返す。うるさいのは意図的で、5 日間気づかなかった事故の再発を防ぐため。

## 監視が動いていることの確認

```bash
# 最新の heartbeat を見る
git fetch origin ops/heartbeat && git show origin/ops/heartbeat:heartbeat.json
```

ワークフローは手動でも起動できる（Actions タブの `ops-watchdog` → Run workflow）。
**閾値を跨いだときに実際に Slack が鳴るかは、一度手で確かめておくこと。**
鳴らない監視は無いのと同じで、それが今回の事故の本質だった。
