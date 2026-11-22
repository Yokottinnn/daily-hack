# シャドウバン対策の関所を入れる（2026-10-25 23:59:10 JST・$0）

## ① 関所と台帳を置く
```
置いた: /Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs（    6186 bytes）
置いた: /Users/ny/.openclaw/workspace/lib/x-action-guard.cjs（    4029 bytes）
```
関所の読み込み: OK

## ② plist に NODE_OPTIONS を足す
```
ai.openclaw.auto-detect-and-unfollow-inactive: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.auto-thread-chainifier: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.badge-followback: 書き換えて読み込み直した（print に関所が出る）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.blog-rss-watcher.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.blog-rss-watcher.plist
ai.openclaw.blog-rss-watcher: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.bookmark-analyzer: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.bookmark-watcher: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.caffeinate: 書き換えた（**動いている最中なので読み込み直しは後で**）
ai.openclaw.canary-silent-gap: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.celebrate-100.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.celebrate-100.plist
ai.openclaw.celebrate-100: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.chrome-cdp-heal: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.chrome-cdp.plist
Unexpected character [ at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.chrome-cdp.plist
ai.openclaw.chrome-cdp: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.chrome-restart-hook.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.chrome-restart-hook.plist
ai.openclaw.chrome-restart-hook: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.comment-warmup: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.competitor-follower-follow: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.cookie-backup: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.cost-monitor-health: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.cost-monitor: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.cost-report-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.crd-detect-daemon: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.daily-action-norm: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.daily-follow-summary: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.daily-must-rule-review: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.daily-supervisor: 書き換えて読み込み直した（print に関所が出る）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.daily-task-audit.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.daily-task-audit.plist
ai.openclaw.daily-task-audit: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.draft-eve: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.draft-late: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.draft-noon: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.engage-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.fire-watchdog: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.follow-balance: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.follow-watchdog: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.follower-daily-report: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.follower-monitor: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.follower-snapshot: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.gateway: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.grok-trending-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.hashtag-follow: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.import-manual-image: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-responder.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-responder.plist
ai.openclaw.incoming-reply-responder: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.incoming-reply-watcher: 書き換えて読み込み直した（print に関所が出る）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.memory-review.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.memory-review.plist
ai.openclaw.memory-review: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.monthly-kpi-report: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.mutual-prune: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.node: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.pipeline-guardian: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.pipeline-heartbeat: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.poll-approvals: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.post-metrics-collector: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.publish-hanabi-oneshot: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.publish-payid-oneshot: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.qt-daily.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.qt-daily.plist
ai.openclaw.qt-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.qt-past-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.refollow-may18-once: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.reply-followback-check: 書き換えて読み込み直した（print に関所が出る）
ai.openclaw.reply-followers-cleanup: 書き換えた（**動いている最中なので読み込み直しは後で**）
ai.openclaw.revenge-unfollow: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.scheduled-entry-watchdog: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.seo-health: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.sheet-sync.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.sheet-sync.plist
ai.openclaw.sheet-sync: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.sitemap-autosubmit: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.slack-watchdog: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.tab-guard: 書き換えた（**動いている最中なので読み込み直しは後で**）
ai.openclaw.thread-guard: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.trend-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.unfollow-cleanup-evening: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.unfollow-cleanup-morning: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist
ai.openclaw.unfollow-daily: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist
ai.openclaw.unfollow-evening: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-stats-monitor.plist
Unexpected character [ at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-stats-monitor.plist
ai.openclaw.unfollow-stats-monitor: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.v3-violation-watchdog: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.variety-audit: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.weekly-design-reminder: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.x-login-compat-test: 書き換えた（載っていないので読み込みは heartbeat に任せる）
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.x-login-monitor.plist
Unexpected character { at line 1
Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.x-login-monitor.plist
ai.openclaw.x-login-monitor: 書き換えた（載っていないので読み込みは heartbeat に任せる）
ai.openclaw.x-loop-guardian: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.asp-sync: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.board-weekly: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.openclaw.heartbeat: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.openclaw.listener: 書き換えた（**動いている最中なので読み込み直しは後で**）
com.dailyhack.ops-poller: 書き換えた（**動いている最中なので読み込み直しは後で**）
com.dailyhack.publish-hanabi-oneshot: 書き換えた（載っていないので読み込みは heartbeat に任せる）
com.dailyhack.publish-prime-oneshot: 書き換えた（載っていないので読み込みは heartbeat に任せる）
com.dailyhack.rc-keeper: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.refresh-daily: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.trend-daily: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.weekly-blog-report: 書き換えて読み込み直した（print に関所が出る）
com.dailyhack.x-impressions: 書き換えて読み込み直した（print に関所が出る）
対象 87 本 / 書き換え 87 本 / 読み込み直して確かめた 20 本
動いていて後回し: ai.openclaw.caffeinate ai.openclaw.reply-followers-cleanup ai.openclaw.tab-guard com.dailyhack.openclaw.listener com.dailyhack.ops-poller
```

## ③ 返信とフォローの前に「空くまで待つ」
```
post-comment.js: 入れた（tweet・最大 150 秒）
follow-handle.js: 入れた（follow・最大 150 秒）
```

## いまの台帳
```
tweet: 直近 30 分 0/12・間隔 60 秒
like: 直近 30 分 0/10・間隔 45 秒
follow: 直近 30 分 0/4・間隔 180 秒
unfollow: 直近 30 分 0/6・間隔 120 秒
```
**LLM を呼んでいない（$0／回）。** 元に戻すときは *.bak-x352 を戻して読み込み直す。
