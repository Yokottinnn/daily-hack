# フォロー比率の 1 週間（2026-11-23 08:56 JST・読むだけ・$0）

## 外した件数（follow-balance・日ごと・JST の日付ではなくログの日付）
```
2026-11-16  起動 6 回 ／ 外れた 6 件
2026-11-17  起動 6 回 ／ 外れた 9 件
2026-11-18  起動 6 回 ／ 外れた 12 件
2026-11-19  起動 6 回 ／ 外れた 11 件
2026-11-20  起動 6 回 ／ 外れた 3 件
2026-11-21  起動 6 回 ／ 外れた 6 件
2026-11-22  起動 6 回 ／ 外れた 4 件
--- 直近の回の終わり
[2026-11-22T06:44:09.532Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-22T06:44:09.532Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-22T06:44:09.541Z] === 外した: 0 件 / 候補 16 件（今日のフォロー 3 件） / **一覧に混ざっていた未フォロー 14 件** ===
[2026-11-22T06:44:09.541Z] === 外した: 0 件 / 候補 16 件（今日のフォロー 3 件） / **一覧に混ざっていた未フォロー 14 件** ===
[x-jitter] 2026-11-22T20:15:04 32 秒 待ってから始める（最大 1500）
[2026-11-22T11:15:36.811Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
[2026-11-22T11:15:36.811Z] === follow-balance start (dry=false min=2 max=20 grace=3d inactive=30d big=5000) ===
/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26
    throw new Error(message || "Assertion error");
          ^

Error: targetInfo: {
  "targetId": "069DB6C6A2412C5F6DA74E39C525BB02",
  "type": "shared_worker",
  "title": "",
  "url": "blob:https://www.delonghi.com/eb366775-4f9b-4a03-a0df-bda95f00496f",
  "attached": true,
  "canAccessOpener": false
}
    at assert (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26:11)
    at CRBrowser._onAttachedToTarget (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crBrowser.js:140:30)
    at CRSession.emit (node:events:508:28)
    at /Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crConnection.js:138:14

Node.js v24.14.0
```

## フォローした件数（ログに出る件数・日ごと）
```
[badge-followback.log]
  2026-11-16  4 件
  2026-11-17  7 件
  2026-11-18  4 件
  2026-11-19  6 件
  2026-11-20  5 件
  2026-11-21  2 件
  2026-11-22  8 件
[badge-followback.stderr.log]
[badge-followback.stdout.log]
[competitor-follower-follow-err.log]
[competitor-follower-follow.log]
  2026-11-22  2 件
[daily-follow-summary-err.log]
[daily-follow-summary.log]
[follow-daily-err.log]
[follow-daily.log]
[follow-morning-err.log]
[follow-morning.log]
[follow-up-reply.log]
[follow-watchdog-err.log]
[follow-watchdog.log]
[follower-daily-report-err.log]
[follower-daily-report.log]
[follower-monitor-err.log]
[follower-monitor.log]
[follower-snapshot.log]
[follower-snapshot.stderr.log]
[follower-snapshot.stdout.log]
[follower-target-monitor-err.log]
[follower-target-monitor.log]
[hashtag-follow-err.log]
[hashtag-follow.log]
[reply-followback-check.log]
[reply-followers-cleanup.log]
  2026-11-17  1 件
  2026-11-20  2 件
[x-follower-cron.log]
[x-follower-follow-err.log]
[x-follower-follow.log]
```

## 載っているフォロー系のジョブ
```
ai.openclaw.follow-balance                   	state = not running 	runs = 21 	last exit code = 1 		state = active 		state = active 
ai.openclaw.mutual-prune                     	state = not running 	runs = 10 	last exit code = 0 		state = active 		state = active 
ai.openclaw.badge-followback                 	state = running 	runs = 43 	last exit code = 0 		state = active 		state = active 
ai.openclaw.competitor-follower-follow       	state = not running 	runs = 8 	last exit code = 0 		state = active 		state = active 
ai.openclaw.hashtag-follow                   	state = not running 	runs = 8 	last exit code = 0 		state = active 		state = active 
```

## 毎朝の数字（x-numbers）の更新
```
```
