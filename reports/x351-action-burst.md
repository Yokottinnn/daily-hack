# X のアクションの固まり具合（2026-10-25 23:54:55 JST・読むだけ・$0）

## 1. 直近 3 日、30 分ごとの最大回数と、1 分以内に続けて出た回数
```
キュー: data/post_queue.json
reply: 3 日で 62 回 ／ 30 分の最大: 2026-10-24 12:00 に 6 回、2026-10-25 12:00 に 6 回、2026-10-24 19:00 に 5 回 ／ 前の回から 1 分以内: 45 回 ／ 間隔の中央値 41 秒
   内訳: comment 62
follow: 3 日で 40 回 ／ 30 分の最大: 2026-10-25 11:30 に 7 回、2026-10-23 11:30 に 5 回、2026-10-23 16:00 に 4 回 ／ 前の回から 1 分以内: 13 回 ／ 間隔の中央値 199 秒
   内訳: comment-orchestrator 18 / competitor-follower:tokufree3 7 / competitor-follower:haiji_doctor 5 / incoming-reply-watcher 3 / hashtag-follow 3 / competitor-follower:himawari56757 2
post: 3 日で 2 回 ／ 30 分の最大: 2026-10-23 08:00 に 2 回 ／ 前の回から 1 分以内: 0 回 ／ 間隔の中央値 1717 秒
   内訳: thread 2
unfollow: 3 日で 37 回 ／ 30 分の最大: 2026-10-24 11:30 に 8 回、2026-10-23 11:30 に 6 回、2026-10-23 15:00 に 5 回 ／ 前の回から 1 分以内: 26 回 ／ 間隔の中央値 0 秒
   内訳: follow-balance 34 / mutual-prune 3
返信＋投稿の 30 分最大: 6
```

## 2. X に触る launchd ジョブと起動の間隔
```
ai.openclaw.auto-detect-and-unfollow-inactive | auto_detect_and_unfollow_inactive.js | "Hour"=>22 "Minute"=>30 
ai.openclaw.badge-followback | | "Hour"=>0 "Minute"=>50 "Hour"=>8 "Minute"=>50 "Hour"=>16 "Minute"=>20 
ai.openclaw.comment-warmup | comment-orchestrator.sh | "Hour"=>16 "Minute"=>0 "Hour"=>12 "Minute"=>0 "Hour"=>22 "Minute"=>0 "Hour"=>19 "Minute"=>0 
ai.openclaw.competitor-follower-follow | competitor-follower-follow.js | "Hour"=>11 "Minute"=>30 "Hour"=>18 "Minute"=>30 
ai.openclaw.daily-follow-summary | daily-follow-summary.js | "Hour"=>23 "Minute"=>0 
ai.openclaw.follow-balance | follow-balance.js | "Hour"=>11 "Minute"=>45 "Hour"=>18 "Minute"=>45 "Hour"=>15 "Minute"=>15 
ai.openclaw.follow-watchdog | follow-watchdog.js | "Hour"=>11 "Minute"=>0 
ai.openclaw.follower-daily-report | follower-daily-report.js | "Hour"=>8 "Minute"=>0 
ai.openclaw.follower-monitor | follower-growth-monitor.js | "Hour"=>12 "Minute"=>30 
ai.openclaw.follower-snapshot | | "Hour"=>0 "Minute"=>35 
ai.openclaw.hashtag-follow | hashtag-follow.js | "Hour"=>10 "Minute"=>15 "Hour"=>17 "Minute"=>0 
ai.openclaw.incoming-reply-responder | | 
ai.openclaw.incoming-reply-watcher | incoming-reply-watcher.js | "StartInterval"=>900 
ai.openclaw.mutual-prune | mutual-prune.js | "Hour"=>6 "Minute"=>0 "Hour"=>18 "Minute"=>0 "Hour"=>12 "Minute"=>30 
ai.openclaw.post-metrics-collector | post-metrics-collector.js | "StartInterval"=>21600 
ai.openclaw.publish-hanabi-oneshot | publish-hanabi-oneshot.sh | "Hour"=>8 "Minute"=>0 
ai.openclaw.publish-payid-oneshot | publish-payid-oneshot.sh | "Hour"=>12 "Minute"=>0 
ai.openclaw.qt-daily | | 
ai.openclaw.qt-past-daily | qt-past-articles-orchestrator.sh | "Hour"=>10 "Minute"=>0 
ai.openclaw.refollow-may18-once | refollow-may18-incident.js | "Hour"=>21 "Minute"=>0 "Hour"=>9 "Minute"=>0 
ai.openclaw.reply-followback-check | reply-followback-check.js | "Hour"=>1 "Minute"=>15 "Hour"=>13 "Minute"=>15 
ai.openclaw.reply-followers-cleanup | reply-followers-cleanup.js | "Hour"=>2 "Minute"=>0 "Hour"=>3 "Minute"=>0 "Hour"=>4 "Minute"=>0 "Hour"=>5 "Minute"=>0 "Hour"=>6 "Minute"=>0 "Hour"=>7 "Minute"=>0 "Hour"=>8 "Minute"=>0 "Hour"
ai.openclaw.revenge-unfollow | revenge-unfollow.js | "Hour"=>13 "Minute"=>0 
ai.openclaw.unfollow-cleanup-evening | unfollow-cleanup.js | "Hour"=>20 "Minute"=>30 
ai.openclaw.unfollow-cleanup-morning | unfollow-cleanup.js | "Hour"=>8 "Minute"=>30 
ai.openclaw.unfollow-daily | | 
ai.openclaw.unfollow-evening | | 
ai.openclaw.unfollow-stats-monitor | | 
```

## 3. いいね・リポストを押しているスクリプト
```
bookmark-watcher.js
engage-via-playwright.js
fetch-4-tweets.js
fetch-ffbuncho.js
incoming-reply-responder.js
post-comment.js
post-metrics-collector.js
qt-probe.js
respond-to-2-replies.js
scrape-tweet-engagement.js
scrape-tweet-replies-2063979763619021022.js
trend-detect.js
```
**読んだだけ。押していない。LLM を呼んでいない（$0／回）。**
