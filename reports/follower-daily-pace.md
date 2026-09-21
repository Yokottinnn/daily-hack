# フォロワーの日次記録（2026-09-21 12:52 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 12:52:30 JST**

> `heartbeat` は **2 点しか持っていない**ので 12 日 平均しか出せない。
> **その 12 日 には、48 本 のジョブが外れていた期間が丸ごと入っている。**
> 平均で見ると、止まっていた日と動いていた日が混ざって実態が消える。

9/30 に 300 人 まで **残り 34 人・9 日 ＝ 3.78 人/日 が必要**。
12 日 平均の 3.25 のままだと **295 人 で 5 人 足りない。**

## 1. 記録がどこにあるか

```
  在る    /Users/ny/.openclaw/workspace/data/follower-history.json 1577 bytes / 73 行
  無い    /Users/ny/.openclaw/workspace/data/followers.json
  無い    /Users/ny/.openclaw/workspace/data/follower-snapshot.json
  無い    /Users/ny/.openclaw/workspace/data/follower-counts.jsonl
  無い    /Users/ny/.openclaw/workspace/data/follower-history.jsonl
  在る    /Users/ny/.openclaw/workspace/logs/follower-snapshot.out 3195 bytes / 40 行

  --- data/ で follow を含むもの ---
    badge-followback-state.json
    follow-watchdog-state.json
    followed.json
    follower-daily-report-state.json
    follower-history.json
    follower-snapshots
    follower-target-config.json
    follower-target-config.json.bak
    following-snapshots
    refollow-blacklist.json
    refollow-may18-done.flag
    reply-followers.json
    reply-followers.json.bak-20260913-194151
    reply-followers.json.bak-20260913-194413
    reply-followers.json.bak-20260915-020121
    unfollow-cleanup-state.json
    unfollow-whitelist.json
    unfollow_batch.json
  --- logs/ で follow を含むもの ---
    auto-detect-and-unfollow-inactive-err.log
    auto-detect-and-unfollow-inactive.log
    badge-followback.log
    badge-followback.stderr.log
    badge-followback.stdout.log
    competitor-follower-follow-err.log
    competitor-follower-follow.log
    daily-follow-summary-err.log
    daily-follow-summary.log
    follow-daily-err.log
    follow-daily.log
    follow-morning-err.log
    follow-morning.log
    follow-up-reply.err
    follow-up-reply.log
    follow-up-reply.out
    follow-watchdog-err.log
    follow-watchdog.log
    follower-daily-report-err.log
    follower-daily-report.log
    follower-monitor-err.log
    follower-monitor.log
    follower-snapshot.err
    follower-snapshot.log
    follower-snapshot.out
    follower-snapshot.stderr.log
    follower-snapshot.stdout.log
    follower-target-monitor-err.log
    follower-target-monitor.log
    hashtag-follow-err.log
    hashtag-follow.log
    reply-followback-check.err
    reply-followback-check.log
    reply-followback-check.out
    reply-followers-cleanup.err
    reply-followers-cleanup.log
    reply-followers-cleanup.out
    revenge-unfollow-err.log
    revenge-unfollow.log
    unfollow-cleanup-evening-err.log
    unfollow-cleanup-evening.log
    unfollow-cleanup-morning-err.log
    unfollow-cleanup-morning.log
    unfollow-daily-err.log
    unfollow-daily.log
    unfollow-evening-err.log
    unfollow-evening.log
    unfollow-stats-monitor.log
    unfollow-stats-monitor.stderr.log
    unfollow-stats-monitor.stdout.log
    x-follower-cron.log
    x-follower-follow-err.log
    x-follower-follow.log
    x-follower-unfollow-err.log
    x-follower-unfollow.log
```

## 2. 日次の推移

```
  日付つきの人数を 1 件も取れなかった
```

## 3. 読み方

- **平均ではなく直近を見る。** 12 日 平均にはジョブが止まっていた期間が入っている
- **前日比がマイナスの日**は、相互フォロー外し（`mutual-prune`）の影響かもしれない。
  増えた数だけでなく**減った数**も見る
- **記録が飛んでいる日**は、そこでジョブが止まっていた合図

## 4. 費用

**ファイルを読んで並べるだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
