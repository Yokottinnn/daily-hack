# 未ロード 60 件 の仕分け材料

**このレポートが作られた時刻: 2026-09-20 14:32:04 JST**

> `unloaded_count` が **60**。`ops-watchdog` は 0 件より多ければ鳴るので、
> このままだと **30 分ごとに鳴り続け、本当の異常が埋もれる。**
>
> しかも 60 件 の中に、**いま困っているジョブ本体**が入っている。

**測るだけ。リネームも載せ直しもしない。**

## 1. 全件（**実行ファイルの有無 ＋ 最後に動いた形跡**）

```
  ラベル                              実体 予定     最後のログ 実行するもの
  ------------------------------------------------------------------------------------------
  auto-detect-and-unfollow-inactive      在  定時     2026-09-09    auto_detect_and_unfollow_inactive.js
  auto-thread-chainifier                 在  定時     2026-09-09    auto-thread-chainifier.js
  blog-rss-watcher                       在  起動時のみ 2026-08-10    ai.openclaw.blog-rss-watcher.plist
  bookmark-analyzer                      在  定時     2026-09-07    bookmark-analyzer.js
  bookmark-watcher                       在  定時     2026-09-07    bookmark-watcher.js
  canary-silent-gap                      在  21600秒   2026-09-09    workspace
  celebrate-100                          在  起動時のみ (ログ無し) ai.openclaw.celebrate-100.plist
  chrome-cdp-heal                        在  300秒     (ログ無し) chrome-cdp-heal.sh
  chrome-cdp                             在  起動時のみ (ログ無し) ai.openclaw.chrome-cdp.plist
  chrome-restart-hook                    在  起動時のみ 2026-08-10    ai.openclaw.chrome-restart-hook.plist
  cookie-backup                          在  定時     2026-09-09    cookie-backup.sh
  cost-monitor-health                    在  7200秒    2026-09-09    health-check-cost-monitor.sh
  cost-monitor                           在  3600秒    2026-09-09    run-cost-monitor.sh
  cost-report-daily                      在  定時     2026-06-01    run-daily-cost-report.sh
  crd-detect-daemon                      在  起動時のみ (ログ無し) crd-detect-daemon.js
  daily-action-norm                      在  定時     2026-09-09    daily-action-norm.js
  daily-follow-summary                   在  定時     2026-09-09    openclaw.json
  daily-must-rule-review                 在  定時     2026-09-09    daily-must-rule-review.js
  daily-task-audit                       在  起動時のみ (ログ無し) ai.openclaw.daily-task-audit.plist
  draft-eve                              在  定時     2026-09-09    run-draft.sh
  draft-late                             在  定時     2026-09-09    run-draft.sh
  draft-noon                             在  定時     2026-09-09    run-draft.sh
  engage-daily                           在  定時     2026-09-09    run-engage.sh
  fire-watchdog                          在  3600秒    2026-09-09    run-fire-watchdog.sh
  follow-watchdog                        在  定時     2026-09-09    workspace
  follower-daily-report                  在  定時     2026-09-09    openclaw.json
  follower-monitor                       在  定時     2026-09-09    openclaw.json
  follower-snapshot                      在  定時     2026-09-09    workspace
  gateway                                在  起動時のみ (ログ無し) ai.openclaw.gateway-env-wrapper.sh
  grok-trending-daily                    在  定時     2026-09-09    openclaw.json
  import-manual-image                    在  1800秒    2026-09-09    import-manual-image.js
  incoming-reply-responder               在  起動時のみ 2026-08-10    ai.openclaw.incoming-reply-responder.plist
  memory-review                          在  起動時のみ 2026-08-10    ai.openclaw.memory-review.plist
  monthly-kpi-report                     在  定時     2026-08-01    monthly-kpi-report.js
  node                                   在  起動時のみ (ログ無し) ai.openclaw.node-env-wrapper.sh
  pipeline-guardian                      在  900秒     2026-09-09    pipeline-guardian.js
  poll-approvals                         在  60秒      2026-09-09    poll-approvals.sh
  post-metrics-collector                 在  21600秒   2026-09-09    post-metrics-collector.js
  publish-hanabi-oneshot                 在  定時     (ログ無し) publish-hanabi-oneshot.sh
  qt-daily                               在  起動時のみ 2026-08-09    ai.openclaw.qt-daily.plist
  qt-past-daily                          在  定時     2026-09-09    qt-past-articles-orchestrator.sh
  refollow-may18-once                    在  定時     (ログ無し) refollow-may18-incident.js
  revenge-unfollow                       在  定時     2026-09-09    workspace
  scheduled-entry-watchdog               在  60秒      (ログ無し) scheduled-entry-watchdog.js
  seo-health                             在  定時     2026-08-24    python3.11
  sheet-sync                             在  起動時のみ 2026-08-10    ai.openclaw.sheet-sync.plist
  sitemap-autosubmit                     在  定時     2026-09-09    python3.11
  slack-watchdog                         在  起動時のみ 2026-09-20    run-slack-watchdog.sh
  trend-daily                            在  定時     2026-09-09    trend-orchestrator.sh
  unfollow-cleanup-evening               在  定時     2026-08-06    openclaw.json
  unfollow-cleanup-morning               在  定時     2026-08-06    openclaw.json
  unfollow-daily                         在  起動時のみ 2026-08-10    ai.openclaw.unfollow-daily.plist
  unfollow-evening                       在  起動時のみ 2026-08-09    ai.openclaw.unfollow-evening.plist
  unfollow-stats-monitor                 在  起動時のみ 2026-08-10    ai.openclaw.unfollow-stats-monitor.plist
  v3-violation-watchdog                  在  21600秒   2026-09-09    v3-violation-watchdog.js
  variety-audit                          在  定時     2026-09-07    variety-audit.js
  weekly-design-reminder                 在  定時     2026-09-07    weekly-design-reminder.sh
  x-login-compat-test                    在  定時     2026-09-08    .env
  x-login-monitor                        在  起動時のみ 2026-08-10    ai.openclaw.x-login-monitor.plist
  x-loop-guardian                        在  900秒     2026-09-20    x-loop-guardian.sh
```

**`実体` が `**無**` のものは、指しているファイルがもう無い。畳んでよい候補。**
**`最後のログ` が何か月も前のものも同じ。** ただし `起動時のみ` のものは
ログを残さないことがあるので、それだけで決めない。

## 2. **いま困っている 6 本**を個別に見る

```
  ══ follower-snapshot
    plist 更新: 2026-05-24 01:16
    在  /bin/bash
    在  /Users/ny/.openclaw/workspace
    在  /Users/ny/.openclaw/openclaw.json
    予定: Dict { Hour = 0 Minute = 35}
    --- follower-snapshot.log（2026-09-09 00:35）末尾 3 行
      {"ok":true,"today":"2026-08-29","count_today":215,"count_prev":214,"disappeared":4,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
      {"ok":true,"today":"2026-09-07","count_today":224,"count_prev":215,"disappeared":4,"new":13,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/20
      {"ok":true,"today":"2026-09-08","count_today":227,"count_prev":224,"disappeared":3,"new":6,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
    --- follower-snapshot.out（2026-06-02 00:30）末尾 3 行
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <
      {"ok":true,"today":"2026-05-31","count_today":74,"count_prev":73,"disappeared":7,"new":8,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/2026-
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <

  ══ grok-trending-daily
    plist 更新: 2026-07-20 15:49
    在  /bin/bash
    在  /usr/local/bin/node
    在  /Users/ny/.openclaw/openclaw.json
    予定: Dict { Hour = 8 Minute = 0}
    --- grok-trending-daily.log（2026-09-09 08:00）末尾 3 行
      [2026-09-08T23:00:47.330Z] grok response length: 440
      [2026-09-08T23:00:47.331Z] extracted 0 tweet urls
      [2026-09-08T23:00:47.332Z] verified: 0

  ══ trend-daily
    plist 更新: 2026-05-18 12:19
    在  /bin/bash
    在  /Users/ny/.openclaw/workspace/scripts/trend-orchestrator.sh
    予定: Dict { Hour = 9 Minute = 30}
    --- trend-daily.log（2026-09-09 09:34）末尾 3 行
      [2026-09-09T09:34:01] auto-gen-card: }
      {"ok":true,"id":"trend-20260909-2","slack_ts":"1788914041.936109"}
      [2026-09-09T09:34:03] === trend orchestrator done ===

  ══ unfollow-cleanup-morning
    plist 更新: 2026-09-06 21:23
    在  /bin/bash
    在  /usr/local/bin/node
    在  /Users/ny/.openclaw/openclaw.json
    予定: Dict { Hour = 8 Minute = 30}
    --- unfollow-cleanup-morning.log（2026-08-06 09:30）末尾 3 行
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <

  ══ unfollow-cleanup-evening
    plist 更新: 2026-09-06 21:23
    在  /bin/bash
    在  /usr/local/bin/node
    在  /Users/ny/.openclaw/openclaw.json
    予定: Dict { Hour = 20 Minute = 30}
    --- unfollow-cleanup-evening.log（2026-08-06 20:30）末尾 3 行
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <
      {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <

  ══ x-loop-guardian
    plist 更新: 2026-09-12 22:21
    在  /bin/bash
    在  /Users/ny/.openclaw/workspace/scripts/x-loop-guardian.sh

    --- x-loop-guardian.log（2026-09-20 00:20）末尾 3 行
      [2026-09-12T22:29:55] alerted slack once
      [2026-09-20T00:20:50] reloaded reply-followers-cleanup
      [2026-09-20T00:20:50] reloaded incoming-reply-watcher
    --- x-loop-guardian.out（2026-09-12 22:21）末尾 3 行

```

## 3. フォロワー記録は**いつ止まったか**

```
  /Users/ny/.openclaw/workspace/logs/follower-snapshot.log
  大きさ 19707 bytes / 最終更新 2026-09-09 00:35

  --- 日付ごとの最後の値（heartbeat と同じ取り方）---
    2026-08-09 206
    2026-08-21 207
    2026-08-22 206
    2026-08-23 208
    2026-08-24 210
    2026-08-25 212
    2026-08-26 211
    2026-08-27 214
    2026-08-28 214
    2026-08-29 215
    2026-09-07 224
    2026-09-08 227

  --- 末尾 5 行（**止まり方を見る**）---
    {"ok":true,"today":"2026-08-27","count_today":214,"count_prev":211,"disappeared":4,"new":7,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
    {"ok":true,"today":"2026-08-28","count_today":214,"count_prev":214,"disappeared":5,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
    {"ok":true,"today":"2026-08-29","count_today":215,"count_prev":214,"disappeared":4,"new":5,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
    {"ok":true,"today":"2026-09-07","count_today":224,"count_prev":215,"disappeared":4,"new":13,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/20
    {"ok":true,"today":"2026-09-08","count_today":227,"count_prev":224,"disappeared":3,"new":6,"snapshot_path":"/Users/ny/.openclaw/workspace/data/follower-snapshots/202
```

**`heartbeat` の `followers.now` はこのログの最後の日の値。**
止まっていれば、**古い数字が「いま」として出続ける。**

## 4. 費用

**plist とログを読むだけ。LLM を呼ばない。リネームも載せ直しもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**畳む・載せ直す場合も $0**（launchd の操作のみ）。
ただし `grok-trending-daily` と `trend-daily` は**戻すと LLM を呼ぶ**ので、
戻す前に 1 回あたり・1 日あたり・1 か月あたりを出して確認を取る（最上位ルール 2-B）。

いま動いている返信ループの実額は、pipeline-heartbeat の実測で **$0.021/日**
（1 か月 約 $0.63）。上限は $0.048/日・$1.44/月 で、**これは実績ではなく安全弁。**
