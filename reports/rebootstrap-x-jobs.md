# 再起動で外れた X のループを載せ直す

**このレポートが作られた時刻: 2026-09-20 01:14:21 JST**

> 2026-09-20 00:54 JST の heartbeat: **`x_jobs loaded 0 / expected 8`**。
> Mac が 11:21 JST に落ち、00:20 JST に戻ったが **LaunchAgents が載り直していない。**
> **認証も CDP も生きている**ので、載せれば動く。

**`kickstart` はしない**（いま走らせると LLM 代が発生する）。**載せるだけ。**

## 1. 載せる前

```
  badge-followback                 **載っていない → 載せる**
  caffeinate                       **載っていない → 載せる**
  comment-warmup                   **載っていない → 載せる**
  competitor-follower-follow       **載っていない → 載せる**
  daily-supervisor                 **載っていない → 載せる**
  hashtag-follow                   **載っていない → 載せる**
  incoming-reply-watcher           **載っていない → 載せる**
  mutual-prune                     **載っていない → 載せる**
  pipeline-heartbeat               **載っていない → 載せる**
  reply-followback-check           **載っていない → 載せる**
  reply-followers-cleanup          **載っていない → 載せる**
  tab-guard                        載っている

  ai.openclaw.* の合計: 1 本
```

## 2. 載せる（`bootout` → `bootstrap`）

```
  badge-followback                 rc=0
  caffeinate                       rc=0
  comment-warmup                   rc=0
  competitor-follower-follow       rc=0
  daily-supervisor                 rc=0
  hashtag-follow                   rc=0
  incoming-reply-watcher           rc=0
  mutual-prune                     rc=0
  pipeline-heartbeat               rc=0
  reply-followback-check           rc=0
  reply-followers-cleanup          rc=0

  **rc は載った証拠にならない**（最上位ルール 13）。下で一覧を取り直して確かめる。
```

## 3. 結果（**`launchctl list` を取り直す**）

```
  ✅ badge-followback               PID=- 最後の終了コード=0
  ✅ caffeinate                     PID=17868 最後の終了コード=0
  ✅ comment-warmup                 PID=17950 最後の終了コード=0
  ✅ competitor-follower-follow     PID=- 最後の終了コード=0
  ✅ daily-supervisor               PID=17878 最後の終了コード=0
  ✅ hashtag-follow                 PID=- 最後の終了コード=0
  ✅ incoming-reply-watcher         PID=- 最後の終了コード=0
  ✅ mutual-prune                   PID=- 最後の終了コード=0
  ✅ pipeline-heartbeat             PID=- 最後の終了コード=0
  ✅ reply-followback-check         PID=- 最後の終了コード=0
  ✅ reply-followers-cleanup        PID=- 最後の終了コード=0
  ✅ tab-guard                      PID=- 最後の終了コード=1

  載った: 12 本 / 載らなかった: 0 本

  ai.openclaw.* の合計: 12 本
```

## 4. この後どうなるか

```
  comment-warmup          12 / 16 / 19 / 22 時 に発火（1 回 4 件）
  competitor-follower     11:30 / 18:30
  hashtag-follow          10:15 / 17:xx
  mutual-prune             6 / 18 時（x80 で StartCalendarInterval に変更済み）
  daily-supervisor         5 / 17 時（今日 走っていないジョブを kickstart する）

  **次の発火を待てば自然に戻る。** いま走らせたい場合は kickstart になるが、
  **返信の生成は LLM 代が出る**ので、承認を取ってから別のタスクで行う。
```

## 5. 費用

**載せるだけ。LLM を呼ばない。投稿もフォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**載った後に動き出す分**の実額（`docs/recurring-job-costs.md`）:
返信ループ 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 **$1.44**
（`MAX_PICKS` は 4 のまま）。フォロー・アンフォロー系は **$0**（DOM 操作のみ）。
**これは元々 想定していた額で、今回の作業で増えるものではない。**
