# 11/4 8:00 の予約ジョブが走らなかった理由（2026-11-05 22:46 JST・読むだけ・$0）

## 1. 再起動・ログイン・スリープ
```
{ sec = 1789831206, usec = 319152 } Sun Sep 20 00:20:06 2026
2026-11-04 07:16:56 +0900 Assertions          	PID 26015(Google Chrome for Testing) Created NoDisplaySleepAssertion "Video Wake Lock" 00:00:
2026-11-04 07:16:57 +0900 Assertions          	PID 26015(Google Chrome for Testing) Released NoDisplaySleepAssertion "Video Wake Lock" 00:00
2026-11-04 07:16:57 +0900 Assertions          	PID 26015(Google Chrome for Testing) Created NoDisplaySleepAssertion "Video Wake Lock" 00:00:
2026-11-04 07:16:57 +0900 Assertions          	PID 26015(Google Chrome for Testing) Released NoDisplaySleepAssertion "Video Wake Lock" 00:00
```

## 2. macOS のログで、このジョブの名前が出た行（11/3 23:10〜11/4 08:25）
```
```

## 3. 同じ時間に launchd が外した（bootout / removing）ジョブ
```
--- 時刻つき（先頭 15 行）
```

## 4. ジョブを外す処理を持つスクリプトのログ（同じ時間帯）
```
~/.openclaw/workspace/scripts/auto-reply.js
~/.openclaw/workspace/scripts/fire-watchdog.js
~/.openclaw/workspace/scripts/space-approved-posts.js
~/.openclaw/workspace/scripts/tab-guard.js
~/.openclaw/workspace/scripts/daily-supervisor.sh
~/.openclaw/workspace/scripts/emergency-stop-llm.sh
~/.openclaw/workspace/scripts/publish-hanabi-oneshot.sh
~/.openclaw/workspace/scripts/publish-payid-oneshot.sh
~/.openclaw/workspace/scripts/publish-points-oneshot.sh
~/.openclaw/workspace/scripts/publish-prime-oneshot.sh
~/.openclaw/workspace/scripts/publish-scheduled-entry.sh
~/.openclaw/workspace/scripts/publish-wangan5-oneshot.sh
~/.openclaw/workspace/scripts/wave-freeze.sh
```

## 5. いま ai.openclaw.* はどれだけ載っているか（plist の数との比較）
```
plist 77 本 / launchctl print に出る ai.openclaw 37 件
--- 載っていない plist
ai.openclaw.auto-detect-and-unfollow-inactive
ai.openclaw.auto-thread-chainifier
ai.openclaw.blog-rss-watcher
ai.openclaw.bookmark-analyzer
ai.openclaw.bookmark-watcher
ai.openclaw.canary-silent-gap
ai.openclaw.celebrate-100
ai.openclaw.chrome-cdp-heal
ai.openclaw.chrome-cdp
ai.openclaw.chrome-restart-hook
ai.openclaw.cookie-backup
ai.openclaw.cost-monitor-health
ai.openclaw.cost-monitor
ai.openclaw.cost-report-daily
ai.openclaw.crd-detect-daemon
ai.openclaw.daily-action-norm
ai.openclaw.daily-follow-summary
ai.openclaw.daily-must-rule-review
ai.openclaw.daily-task-audit
ai.openclaw.draft-eve
```

## 6. 前に同じ作りで成功した予約（11/1 ポイント経済圏・x391）との違い
```
-rw-r--r--  1 ny  staff  866 Oct 30 00:44 ~/Library/LaunchAgents/ai.openclaw.publish-hanabi-oneshot.plist
-rw-r--r--  1 ny  staff  826 Jul  6 00:03 ~/Library/LaunchAgents/ai.openclaw.publish-hanabi-oneshot.plist.bak-x352
-rw-r--r--  1 ny  staff  898 Oct 30 00:44 ~/Library/LaunchAgents/ai.openclaw.publish-payid-oneshot.plist
-rw-r--r--  1 ny  staff  846 Sep 27 00:33 ~/Library/LaunchAgents/ai.openclaw.publish-payid-oneshot.plist.bak-x352
-rw-r--r--  1 ny  staff  854 Oct 31 21:19 ~/Library/LaunchAgents/ai.openclaw.publish-points-oneshot.plist
-rw-r--r--  1 ny  staff  908 Oct 30 00:44 ~/Library/LaunchAgents/com.dailyhack.publish-hanabi-oneshot.plist
-rw-r--r--  1 ny  staff  856 Oct 23 00:18 ~/Library/LaunchAgents/com.dailyhack.publish-hanabi-oneshot.plist.bak-x352
-rw-r--r--  1 ny  staff  905 Oct 30 00:44 ~/Library/LaunchAgents/com.dailyhack.publish-prime-oneshot.plist
-rw-r--r--  1 ny  staff  853 Oct 18 00:17 ~/Library/LaunchAgents/com.dailyhack.publish-prime-oneshot.plist.bak-x352
{"ok":true,"tweet_id":"2116727000358646078","url":"https://x.com/heng_ji31590/status/2116727000358646078","thread_count":2,"thread_results":[{"index":0,"role":"
[wb] t1=2116727000358646078 t2=2116727081791013170 ok=true
[2026-11-01 12:00:40] done rc=0
```
