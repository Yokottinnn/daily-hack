# 夜のフォローを読む（2026-11-14 18:48:20 JST・読むだけ・$0）
見る時間: 11/12 12:00Z〜11/13 02:59Z と 11/13 12:00Z〜11/14 02:59Z（JST 21:00〜11:59）

## 1. ログごとの『フォローした』らしい行の数（この時間帯）
```
15 badge-followback.log
7 competitor-follower-follow.log
7 comment-warmup.log
7 comment-orchestrator.log
4 follow-balance.log
2 reply-followers-cleanup.log
2 incoming-reply-watcher.log
```

## 2. 上位 3 つのログの該当行（各 25 行）

### badge-followback.log
```
[2026-11-12T15:51:59.057Z] followed back @<伏せ>
[2026-11-12T15:52:08.151Z] followed back @<伏せ>
[2026-11-12T15:52:16.682Z] followed back @<伏せ>
[2026-11-12T15:52:29.562Z] followed back @<伏せ>
[2026-11-12T23:52:10.378Z] followed back @<伏せ>
[2026-11-12T23:52:20.401Z] followed back @<伏せ>
[2026-11-12T23:52:33.027Z] followed back @<伏せ>
[2026-11-12T23:52:41.910Z] followed back @<伏せ>
[2026-11-12T23:52:58.855Z] followed back @<伏せ>
[2026-11-13T15:52:08.645Z] followed back @<伏せ>
[2026-11-13T15:52:18.749Z] followed back @<伏せ>
[2026-11-13T15:52:31.119Z] followed back @<伏せ>
[2026-11-13T15:52:45.704Z] followed back @<伏せ>
[2026-11-13T23:52:35.842Z] followed back @<伏せ>
[2026-11-13T23:52:53.463Z] followed back @<伏せ>
```

### competitor-follower-follow.log
```
[2026-11-12T20:00:52.618Z] === competitor-follower start: target=@<伏せ> (day-rotation index=1/3) cap=30 ===
[2026-11-12T20:02:55.054Z]   @<伏せ>: ✅
[2026-11-12T20:08:30.963Z]   @<伏せ>: ✅
[2026-11-12T20:09:34.725Z] === end: 2/15 OK ===
[2026-11-13T02:30:03.198Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/3) cap=30 ===
[2026-11-13T02:30:31.201Z]   @<伏せ>: ✅
[2026-11-13T02:40:47.808Z] === end: 1/18 OK ===
[2026-11-13T20:00:48.546Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/3) cap=30 ===
[2026-11-13T20:01:10.231Z]   @<伏せ>: ✅
[2026-11-13T20:01:44.824Z]   @<伏せ>: ✅
[2026-11-13T20:09:27.119Z]   @<伏せ>: ✅
[2026-11-13T20:10:34.614Z]   @<伏せ>: ✅
[2026-11-13T20:11:04.632Z] === end: 4/18 OK ===
[2026-11-14T02:30:00.269Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/3) cap=30 ===
```

### comment-warmup.log
```
[2026-11-12T12:00:00] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-12T16:00:05] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-12T16:03:27]   follow @<伏せ>: followed
[2026-11-12T19:00:01] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-12T19:03:42]   follow @<伏せ>: followed
[2026-11-12T19:04:02]   follow @<伏せ>: followed
[2026-11-12T22:00:01] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-12T22:03:38]   follow @<伏せ>: followed
[2026-11-12T22:03:58]   follow @<伏せ>: followed
[2026-11-13T12:00:04] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-13T12:04:10]   follow @<伏せ>: followed
[2026-11-13T16:00:04] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-13T16:04:21]   follow @<伏せ>: followed
[2026-11-13T19:00:03] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
[2026-11-13T22:00:03] === comment orchestrator start (max_picks=5, reply_follow_cap=30) ===
```

## 3. フォロー日時の記録（data/ の *follow* の json）から、この時間帯に記録された件数と出どころ
```
badge-followback-state.json: 15 件 {"(出どころなし)":15}
follow-balance-state.json: 6 件 {"(出どころなし)":6}
followed.json: 12 件 {"badge-followback":12}
reply-followers.json: 33 件 {"comment-orchestrator":17,"competitor-follower:haiji_doctor":8,"competitor-follower:okamiler_pn":7,"incoming-reply-watcher":1}
unfollow-cleanup-state.json: 3 件 {"(出どころなし)":3}
```

## 4. この時間帯に動く launchd ジョブ（StartCalendarInterval の時刻つき・follow を含む名前）
```
ai.openclaw.auto-detect-and-unfollow-inactive | 時刻: Array { Dict { Hour = 22 Minute = 30 } }  | 間隔: なし
ai.openclaw.badge-followback | 時刻: Array { Dict { Hour = 0 Minute = 50 } Dict { Hour = 8 Minute = 50 } Dict { Hour = 16 Minute = 20 } }  | 間隔: なし
ai.openclaw.competitor-follower-follow | 時刻: Array { Dict { Hour = 11 Minute = 30 } Dict { Hour = 20 Minute = 45 } }  | 間隔: なし
ai.openclaw.daily-follow-summary | 時刻: Array { Dict { Hour = 23 Minute = 0 } }  | 間隔: なし
ai.openclaw.follow-balance | 時刻: Array { Dict { Hour = 11 Minute = 45 } Dict { Hour = 20 Minute = 15 } Dict { Hour = 15 Minute = 15 } }  | 間隔: なし
ai.openclaw.follow-watchdog | 時刻: Dict { Hour = 11 Minute = 0 }  | 間隔: なし
ai.openclaw.follower-daily-report | 時刻: Dict { Hour = 8 Minute = 0 }  | 間隔: なし
ai.openclaw.follower-monitor | 時刻: Array { Dict { Hour = 12 Minute = 30 } }  | 間隔: なし
ai.openclaw.follower-snapshot | 時刻: Dict { Hour = 0 Minute = 35 }  | 間隔: なし
ai.openclaw.hashtag-follow | 時刻: Array { Dict { Hour = 10 Minute = 15 } Dict { Hour = 17 Minute = 0 } }  | 間隔: なし
ai.openclaw.refollow-may18-once | 時刻: Array { Dict { Day = 20 Hour = 21 Minute = 0 } Dict { Day = 21 Hour = 9 Minute = 0 } }  | 間隔: なし
ai.openclaw.reply-followback-check | 時刻: Array { Dict { Hour = 1 Minute = 15 } Dict { Hour = 13 Minute = 15 } }  | 間隔: なし
ai.openclaw.reply-followers-cleanup | 時刻: Array { Dict { Hour = 2 Minute = 0 } Dict { Hour = 3 Minute = 0 } Dict { Hour = 4 Minute = 0 } Dict { Hour = 5 Minute = 0 } Dict { Hour = 6 Minute = 0 } Dict {  | 間隔: なし
ai.openclaw.revenge-unfollow | 時刻: Dict { Hour = 13 Minute = 0 }  | 間隔: なし
ai.openclaw.unfollow-cleanup-evening | 時刻: Dict { Hour = 20 Minute = 30 }  | 間隔: なし
ai.openclaw.unfollow-cleanup-morning | 時刻: Dict { Hour = 8 Minute = 30 }  | 間隔: なし
ai.openclaw.unfollow-daily | 時刻: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist  | 間隔: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist
ai.openclaw.unfollow-evening | 時刻: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist  | 間隔: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist
ai.openclaw.unfollow-stats-monitor | 時刻: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-stats-monitor.plist  | 間隔: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-stats-monitor.plist
ai.openclaw.incoming-reply-responder | 時刻: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-responder.plist  | 間隔: Error Reading File: /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-responder.plist
ai.openclaw.incoming-reply-watcher | 時刻: なし | 間隔: 900
ai.openclaw.reply-followback-check | 時刻: Array { Dict { Hour = 1 Minute = 15 } Dict { Hour = 13 Minute = 15 } }  | 間隔: なし
ai.openclaw.reply-followers-cleanup | 時刻: Array { Dict { Hour = 2 Minute = 0 } Dict { Hour = 3 Minute = 0 } Dict { Hour = 4 Minute = 0 } Dict { Hour = 5 Minute = 0 } Dict { Hour = 6 Minute = 0 } Dict {  | 間隔: なし
```
