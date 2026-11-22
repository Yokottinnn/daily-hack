# 夕方 18 時台に重なるジョブ（2026-11-11 00:20:41 JST・読むだけ・$0）

## ① 18 時台に動くジョブ（載っているものだけ）
```
ai.openclaw.boost-watch                          600秒ごと  boost-watch.js
ai.openclaw.comment-warmup                       19:00  comment-orchestrator.sh
ai.openclaw.competitor-follower-follow           18:30  competitor-follower-follow.js
ai.openclaw.cost-monitor                         3600秒ごと  run-cost-monitor.sh
ai.openclaw.draft-eve                            18:30  19:00
ai.openclaw.engage-daily                         18:00  run-engage.sh
ai.openclaw.fire-watchdog                        3600秒ごと  run-fire-watchdog.sh
ai.openclaw.follow-balance                       18:45  follow-balance.js
ai.openclaw.import-manual-image                  1800秒ごと  import-manual-image.js
ai.openclaw.incoming-reply-watcher               900秒ごと  incoming-reply-watcher.js
ai.openclaw.mutual-prune                         18:00  mutual-prune.js
ai.openclaw.pipeline-guardian                    900秒ごと  pipeline-guardian.js
ai.openclaw.poll-approvals                       60秒ごと  poll-approvals.sh
ai.openclaw.reply-followers-cleanup              18:00 / 19:00  reply-followers-cleanup.js
ai.openclaw.scheduled-entry-watchdog             60秒ごと  scheduled-entry-watchdog.js
ai.openclaw.thread-guard                         1800秒ごと  thread-guard.js
ai.openclaw.x-loop-guardian                      900秒ごと  x-loop-guardian.sh
com.bubblesnow.remote.watchdog                   30秒ごと  remote-watchdog.sh
com.dailyhack.openclaw.heartbeat                 300秒ごと  heartbeat.py
com.dailyhack.ops-heartbeat                      1800秒ごと  ops-heartbeat.sh
com.dailyhack.ops-poller                         60秒ごと  ops-run-tasks.sh
com.dailyhack.rc-keeper                          300秒ごと  dh-rc-keeper
com.google.GoogleUpdater.wake                    3600秒ごと  *=2
```

## ② 11/10 18:20〜18:55 JST に書かれたログ（09:2x〜09:5x UTC・ファイルごとに最大 4 行）
```
[boost-watch-out.log]
[2026-11-10T09:26:18.517Z] 2120049694818902068（comment-20261110-1603-1）: 表示 24 / 毎分 0.1（1 つ前 0.2・最初 0.3）
[2026-11-10T09:26:20.977Z] 2120049831087632816（comment-20261110-1603-2）: 表示 27 / 毎分 0.1（1 つ前 0.2・最初 0.2）
[2026-11-10T09:26:23.227Z] 2120049951946559637（comment-20261110-1604-4）: 表示 23 / 毎分 0.1（1 つ前 0.2・最初 0.2）
[2026-11-10T09:36:29.374Z] 2120049694818902068（comment-20261110-1603-1）: 表示 25 / 毎分 0.1（1 つ前 0.1・最初 0.3）
[boost-watch.log]
[2026-11-10T09:26:18.517Z] 2120049694818902068（comment-20261110-1603-1）: 表示 24 / 毎分 0.1（1 つ前 0.2・最初 0.3）
[2026-11-10T09:26:20.977Z] 2120049831087632816（comment-20261110-1603-2）: 表示 27 / 毎分 0.1（1 つ前 0.2・最初 0.2）
[2026-11-10T09:26:23.227Z] 2120049951946559637（comment-20261110-1604-4）: 表示 23 / 毎分 0.1（1 つ前 0.2・最初 0.2）
[2026-11-10T09:36:29.374Z] 2120049694818902068（comment-20261110-1603-1）: 表示 25 / 毎分 0.1（1 つ前 0.1・最初 0.3）
[competitor-follower-follow.log]
[2026-11-10T09:30:05.291Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/3) cap=30 ===
[2026-11-10T09:30:22.792Z] scraped 0 followers from @<伏せ>
[2026-11-10T09:30:22.793Z] new targets (after dedup): 0
[cost-monitor-stdout.log]
[2026-11-10T09:23:05.528Z] ERROR fetch-cost-csv (Slack抑制・ログのみ): Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/fetch-cost-csv.js
[cost-monitor.log]
[2026-11-10T09:23:05.528Z] ERROR fetch-cost-csv (Slack抑制・ログのみ): Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/fetch-cost-csv.js
[follow-balance.log]
[2026-11-10T09:45:05.289Z] === follow-balance start (dry=false min=20 max=20 grace=1d inactive=30d big=5000) ===
[2026-11-10T09:45:24.416Z] /home が空。開き直す
[2026-11-10T09:45:39.632Z] 自分のハンドルが画面から読めない → heng_ji31590 を使う（x395）
[2026-11-10T09:45:51.417Z] フォロー中: 0 件（12 秒）
[import-manual-image.log]
[2026-11-10T09:20:37.640Z] no manual images
[2026-11-10T09:50:37.736Z] no manual images
[incoming-reply-watcher.log]
[2026-11-10T09:26:46.804Z] scanning 16 recent posts
[2026-11-10T09:26:46.808Z] today's auto-replies: 2 / 20
[2026-11-10T09:27:01.886Z] fatal: browserType.connectOverCDP: Timeout 15000ms exceeded.
[2026-11-10T09:42:02.401Z] scanning 16 recent posts
[mutual-prune.log]
[2026-11-10T09:21:36.815Z]   @<伏せ>: ページが空。開き直す
[2026-11-10T09:22:05.520Z]   @<伏せ>: ページが空。開き直す
[2026-11-10T09:22:35.286Z]   @<伏せ>: ページが空。開き直す
[2026-11-10T09:23:03.392Z]   @<伏せ>: ページが空。開き直す
[ops-heartbeat.log]
ops-heartbeat: pushed 2026-11-10T09:31:13Z (78 jobs)
[pipeline-guardian.log]
[2026-11-10T09:34:34.981Z] ok=false healed=[] failed=[tab_safety]
[2026-11-10T09:50:15.376Z] ok=false healed=[] failed=[tab_safety]
[post-metrics-collector.log]
[2026-11-10T09:20:37.669Z] will scrape 137 posts (last 7d)
[2026-11-10T09:20:41.893Z] fatal: ctx is not defined
[thread-guard.log]
{"ok":true,"at":"2026-11-10 18:20:42","dry":false,"a_count":5,"b_count":0,"stale_count":14,"notified":[]}
{"ok":true,"at":"2026-11-10 18:50:42","dry":false,"a_count":5,"b_count":0,"stale_count":14,"notified":["A:thread-reply-1-exec","A:thread-main-exec","A:thread-main-exec"]}
[trend-daily.log]
[2026-11-10T09:30:06] === trend orchestrator start ===
[2026-11-10T09:33:08] detected 4 candidates
[2026-11-10T09:33:12] relevant: 2 (cap 2)
[2026-11-10T09:33:12] --- processing #1 ---
[trend-orchestrator.log]
[2026-11-10T09:30:06] === trend orchestrator start ===
[2026-11-10T09:33:08] detected 4 candidates
[2026-11-10T09:33:12] relevant: 2 (cap 2)
[2026-11-10T09:33:12] --- processing #1 ---
[v3-violation-watchdog.log]
[2026-11-10T09:20:34.575Z] no violations detected
[x-loop-guardian.log]
[2026-11-10T09:22:00] unresolved: load-failed:comment-warmup load-failed:reply-followers-cleanup load-failed:incoming-reply-watcher load-failed:pipeline-heartbeat (consec
[2026-11-10T09:37:02] unresolved: load-failed:comment-warmup load-failed:reply-followers-cleanup load-failed:incoming-reply-watcher load-failed:pipeline-heartbeat (consec
[2026-11-10T09:52:04] unresolved: load-failed:comment-warmup load-failed:reply-followers-cleanup load-failed:incoming-reply-watcher load-failed:pipeline-heartbeat (consec
```

## ③ 自動化用 Chrome のタブの数と、18 時台の tab-guard / ensure-chrome の記録
```
いまのタブ: 17
```
