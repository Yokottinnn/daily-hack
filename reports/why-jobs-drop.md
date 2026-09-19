# 再起動でジョブが外れる理由

**このレポートが作られた時刻: 2026-09-20 01:24:28 JST**

> **2 回 起きている。** 2026-09-12 と 2026-09-20。
> どちらも `ai.openclaw.*` がほぼ全滅し、手で載せ直している。
>
> `~/Library/LaunchAgents` の plist は**本来ログイン時に自動で載る。**
> 載らないなら理由がある。**推測で書き換える前に実物を読む。**

**測るだけ。直さない。**

## 1. `launchctl disable` されていないか（**再起動をまたいで残る**）

```
  無効にされている合計: 4 件

  --- ai.openclaw / com.dailyhack のうち無効なもの ---

  --- 対象 12 本 の状態 ---
    badge-followback               "ai.openclaw.badge-followback" => enabled
    caffeinate                     "ai.openclaw.caffeinate" => enabled
    comment-warmup                 "ai.openclaw.comment-warmup" => enabled
    competitor-follower-follow     "ai.openclaw.competitor-follower-follow" => enabled
    daily-supervisor               "ai.openclaw.daily-supervisor" => enabled
    hashtag-follow                 "ai.openclaw.hashtag-follow" => enabled
    incoming-reply-watcher         "ai.openclaw.incoming-reply-watcher" => enabled
    mutual-prune                   "ai.openclaw.mutual-prune" => enabled
    pipeline-heartbeat             "ai.openclaw.pipeline-heartbeat" => enabled
    reply-followback-check         "ai.openclaw.reply-followback-check" => enabled
    reply-followers-cleanup        "ai.openclaw.reply-followers-cleanup" => enabled
    tab-guard                      "ai.openclaw.tab-guard" => enabled
```

**`=> true` や `disabled` が付いていれば、それが原因。**
その場合は `launchctl enable gui/<uid>/<label>` が要る（**このタスクではやらない**）。

## 2. plist の `Disabled` と `RunAtLoad`

```
    ジョブ                      Disabled   RunAtLoad  置き場所
    badge-followback               (無し)   (無し)   LaunchAgents
    caffeinate                     (無し)   true       LaunchAgents
    comment-warmup                 (無し)   (無し)   LaunchAgents
    competitor-follower-follow     (無し)   (無し)   LaunchAgents
    daily-supervisor               (無し)   true       LaunchAgents
    hashtag-follow                 (無し)   (無し)   LaunchAgents
    incoming-reply-watcher         (無し)   (無し)   LaunchAgents
    mutual-prune                   (無し)   false      LaunchAgents
    pipeline-heartbeat             (無し)   false      LaunchAgents
    reply-followback-check         (無し)   (無し)   LaunchAgents
    reply-followers-cleanup        (無し)   (無し)   LaunchAgents
    tab-guard                      (無し)   true       LaunchAgents
```

**`Disabled = true` なら、それだけで載らない。**
**`RunAtLoad` が無いものは、載っても次の定時まで走らない**（これは正常）。

## 3. いまの状態（**`launchctl list` を 1 回だけ取る**）

```
    ジョブ                      PID        最後の終了コード
    badge-followback               -  0
    caffeinate                     17868  0
    comment-warmup                 19015  5
    competitor-follower-follow     18137  0
    daily-supervisor               -  0
    hashtag-follow                 -  0
    incoming-reply-watcher         -  0
    mutual-prune                   18625  0
    pipeline-heartbeat             -  2
    reply-followback-check         -  0
    reply-followers-cleanup        18410  0
    tab-guard                      18057  1

  ai.openclaw.* の合計: 12 本
```

**最後の終了コードが 0 以外のものは、走って落ちている。**
載っていないこととは別の問題なので、混ぜない。

## 4. plist の置き場所と更新日

```
  /Users/ny/Library/LaunchAgents
    ai.openclaw.mutual-prune.plist                 2026-09-15 01:21
    ai.openclaw.mutual-prune.plist.bak-20260915-012122 2026-09-15 01:21
    ai.openclaw.mutual-prune.plist.bak-20260913-104853 2026-09-13 10:46
    ai.openclaw.caffeinate.plist                   2026-09-13 03:09
    ai.openclaw.reply-followers-cleanup.plist      2026-09-13 03:09
    ai.openclaw.daily-supervisor.plist             2026-09-13 03:02
    ai.openclaw.x-loop-guardian.plist              2026-09-12 22:21
    ai.openclaw.comment-warmup.plist               2026-09-06 23:25
    ai.openclaw.comment-warmup.plist.bak-20260913-030908 2026-09-06 23:25
    ai.openclaw.revenge-unfollow.plist             2026-09-06 22:21
    ai.openclaw.follow-watchdog.plist              2026-09-06 22:21
    ai.openclaw.unfollow-cleanup-evening.plist     2026-09-06 21:23
    ai.openclaw.unfollow-cleanup-morning.plist     2026-09-06 21:23
    ai.openclaw.hashtag-follow.plist               2026-09-05 17:29
    ai.openclaw.hashtag-follow.plist.bak-20260913-030908 2026-09-05 17:29
    ai.openclaw.competitor-follower-follow.plist   2026-09-05 17:29

  --- ここ以外に置かれていないか（LaunchDaemons など） ---
    /Library/LaunchAgents              0
0 件
    /Library/LaunchDaemons             0
0 件
```

## 5. 費用

**読むだけ。LLM を呼ばない。enable も bootstrap もしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**直す場合も $0**（launchd の設定のみ。LLM を呼ばない）。
