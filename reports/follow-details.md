# フォロー施策の詳細（2026-08-22T11:07:18Z）

## 0. 2026-07-04 に何が止まったか

### その日付を名前に持つファイル（.bak / .disabled / .old）
ai.openclaw.chrome-cdp.plist.bak.20260602-keepalive-off
ai.openclaw.chrome-cdp.plist.bak.20260602-throttle
ai.openclaw.comment-warmup.plist.bak.20260511-151918
ai.openclaw.comment-warmup.plist.bak.20260517-5to3-fires
ai.openclaw.comment-warmup.plist.bak.20260615-v6-tactic
ai.openclaw.comment-warmup.plist.bak.20260815-picks8
ai.openclaw.competitor-follower-follow.plist.bak.20260615-v6-tactic
ai.openclaw.cookie-backup.plist.bak.20260704-p1-6h
ai.openclaw.dm-daily.plist.disabled
ai.openclaw.draft-eve.plist.bak.20260515
ai.openclaw.draft-morning.plist.bak.20260515
ai.openclaw.draft-morning.plist.disabled-20260517-newschedule
ai.openclaw.draft-noon.plist.bak.20260515
ai.openclaw.follow-daily.plist.disabled
ai.openclaw.follow-morning.plist.disabled
ai.openclaw.follow-up-reply.plist.disabled-20260517
ai.openclaw.follower-target-monitor.plist.bak.20260704-v7
ai.openclaw.hashtag-follow.plist.bak.20260615-v6-tactic
ai.openclaw.incoming-reply-responder.plist.bak.20260719-skip-post
ai.openclaw.weekly-ab-report.plist.disabled

### LaunchAgents を更新日時の新しい順に（上位 20 件）
   800
Aug 22 2026 ai.openclaw.x-login-monitor.plist
Aug 22 2026 ai.openclaw.unfollow-evening.plist
Aug 22 2026 ai.openclaw.unfollow-daily.plist
Aug 22 2026 ai.openclaw.sheet-sync.plist
Aug 22 2026 ai.openclaw.revenge-unfollow.plist
Aug 22 2026 ai.openclaw.qt-daily.plist
Aug 22 2026 ai.openclaw.memory-review.plist
Aug 22 2026 ai.openclaw.incoming-reply-responder.plist
Aug 22 2026 ai.openclaw.hashtag-follow.plist
Aug 22 2026 ai.openclaw.follow-watchdog.plist
Aug 22 2026 ai.openclaw.daily-task-audit.plist
Aug 22 2026 ai.openclaw.competitor-follower-follow.plist
Aug 22 2026 ai.openclaw.comment-warmup.plist
Aug 22 2026 ai.openclaw.chrome-restart-hook.plist
Aug 22 2026 ai.openclaw.celebrate-100.plist
Aug 22 2026 ai.openclaw.blog-rss-watcher.plist
Aug 22 2026 ai.openclaw.auto-thread-chainifier.plist
Aug 22 2026 com.adobe.ccxprocess.plist
Aug 16 2026 com.bubblesnow.daily.plist
Aug 15 2026 ai.openclaw.comment-warmup.plist.bak.20260815-picks8

## 1. x-follower（能動フォロー・7/04 が最後）

### 名前に x-follower-cron を含むもの
- scripts: x-follower-cron.sh 
- 直下:    
- plist:   
- logs:    x-follower-cron.log 
- crontab: 0 行
### 名前に x-follower を含むもの
- scripts: x-follower-cron.sh 
- 直下:    
- plist:   
- logs:    x-follower-cron.log x-follower-follow-err.log x-follower-follow.log x-follower-unfollow-err.log x-follower-unfollow.log 
- crontab: 0 行
### 名前に follower-cron を含むもの
- scripts: x-follower-cron.sh 
- 直下:    
- plist:   
- logs:    x-follower-cron.log 
- crontab: 0 行

### crontab 全体（コメント除く・パスは出す・値は伏せる）
（crontab が空なら launchd 側にある）

### x-follower のスクリプト本体（見つかったもの）

#### /Users/ny/.openclaw/workspace/scripts/x-follower-cron.sh  55 行
先頭コメント:
#!/bin/bash
# x-follower-cron.sh
# launchdから呼び出されるXフォロー自動実行スクリプト
# 毎日9:00 JST にフォロー実行、22:00 JST にアンフォローチェック
上限・間隔:

### x-follower のログ（最終 5 行・いつ・何件打ったか）
#### x-follower-cron.log  更新=2026-07-04T14:54Z  111 行

効率を上げるため、サブエージェントで複数の候補アカウントを並行評価＆フォローする
サブエージェントが作業開始しました。アンフォロー（money_yossy）はすでに完了している�
データを更新しました。サブエージェントのフォロー完了を待ちます。
[2026-07-04 23:54:03 JST] x-follower-cron done (follow, exit: 0)
#### x-follower-follow-err.log  更新=2026-05-08T16:48Z  0 行
#### x-follower-follow.log  更新=2026-05-08T16:48Z  0 行
#### x-follower-unfollow-err.log  更新=2026-05-09T13:00Z  0 行
#### x-follower-unfollow.log  更新=2026-05-09T13:00Z  0 行

## 2. chainifier（ループ①・8/08 まで動いて no entries）
- StartInterval: 無し
- StartCalendarInterval: 無し
- 行数: 83
- 上限・しきい値:
- モデル: 
- env: 
- 「no entries to chainify」を出す条件（前後 4 行）:
47-    e.status &&
48-    !["posted", "posted_pre_queue", "<MASKED>", "skipped_v3_redraft", "cancelled_redundant", "<MASKED>"].includes(e.s
49-  );
50-
51:  if (targets.length === 0) { log("no entries to chainify"); return; }

## 3. unfollow（ループ③・一度も動いていない）
- 行数: 157
- 上限・待機日数:
22:const <MASKED> = 30; // days
- 除外判定:
- env: 
- 実行方法（先頭コメント）:
#!/usr/bin/env node
/**
 * Auto Detect & Unfollow Inactive Accounts
 * 
 * Complete workflow:
 * 1. Scan all followed accounts via browser
 * 2. Extract last post dates from snapshots
 * 3. Identify accounts inactive 30+ days
