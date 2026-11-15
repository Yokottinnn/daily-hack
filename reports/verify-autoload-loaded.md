# autoload の 14 本 は本当に載っているか（2026-09-21 13:10 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 13:10:24 JST**

> `heartbeat.json` は `{"target":14,"tried":0,"loaded":0}` と出している。
> **打った 0 は「全部 載っている」とも「判定が壊れている」とも読める。**
> `tried:0` を正常と読んで 11 日間 気づかなかったのが 2026-09-09 だった。

**`launchctl list | grep` は使わない**（載っていても出ないことがある・最上位ルール 13）。
**`launchctl print gui/501/<ラベル>` で 1 本ずつ見る。**

## 1. 一覧はどこにあるか

```
  /Users/ny/projects/anta-baka-x/blog/ops/data/autoload-jobs.txt
```

## 2. 1 本ずつ print する

```
  ラベル                                  state        runs   last-exit  plist
  --------------------------------------------------------------------------------------------
  ai.openclaw.comment-warmup                 not running  4      0          ai.openclaw.comment-warmup.plist
  ai.openclaw.competitor-follower-follow     not running  5      0          ai.openclaw.competitor-follower-follow.plist
  ai.openclaw.hashtag-follow                 not running  5      0          ai.openclaw.hashtag-follow.plist
  ai.openclaw.badge-followback               not running  2      0          ai.openclaw.badge-followback.plist
  ai.openclaw.reply-followback-check         not running  3      0          ai.openclaw.reply-followback-check.plist
  ai.openclaw.reply-followers-cleanup        running      2      -          ai.openclaw.reply-followers-cleanup.plist
  ai.openclaw.incoming-reply-watcher         not running  139    0          ai.openclaw.incoming-reply-watcher.plist
  ai.openclaw.pipeline-heartbeat             not running  5      2          ai.openclaw.pipeline-heartbeat.plist
  ai.openclaw.mutual-prune                   running      2      -          ai.openclaw.mutual-prune.plist
  ai.openclaw.daily-supervisor               not running  4      0          ai.openclaw.daily-supervisor.plist
  ai.openclaw.caffeinate                     running      1      (never exited) ai.openclaw.caffeinate.plist
  ai.openclaw.tab-guard                      running      1      (never exited) ai.openclaw.tab-guard.plist
  ai.openclaw.follower-snapshot              not running  2      0          ai.openclaw.follower-snapshot.plist
  ai.openclaw.x-loop-guardian                not running  87     0          ai.openclaw.x-loop-guardian.plist

  対象 14 本 / 載っている 14 本 / **載っていない 0 本**
```

### 全部 載っている。**`tried:0` は正常だった**

ただし **`runs = 0` のものは「載っているが一度も動いていない」。** 上の表で確認する。

## 3. フォロワー記録の口を、名指しで見る

**`ai.openclaw.follower-snapshot` はフォロワー数の唯一の記録源。**
2026-09-09 に止まり、9/8 の 227 が 12 日間「いま」として出ていた。

```
  	path = /Users/ny/Library/LaunchAgents/ai.openclaw.follower-snapshot.plist
  	state = not running
  	program = /bin/bash
  	stdout path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stdout.log
  	stderr path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stderr.log
  	runs = 2
  	last exit code = 0
  		state = active
  		state = active
```

### 記録ファイルは増えているか（**これが一次情報**）

```
  /Users/ny/.openclaw/workspace/data/follower-snapshots
  ファイル数: 53
  --- 新しい順に 6 件（日付・人数）---
    2026-09-20.json  266 人
    2026-09-08.json  227 人
    2026-09-07.json  224 人
    2026-08-29.json  215 人
    2026-08-28.json  214 人
    2026-08-27.json  214 人
```

**人数は `count`。`followers` はハンドルの配列で人数ではない**（docs/follower-tracking.md）。

## 4. 費用

**`launchctl print` と `ls` だけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
