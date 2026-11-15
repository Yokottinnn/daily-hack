# plist の救出（2026-08-22T14:08:01Z）

**読むだけ。何も書き換えない。**

## 1. 稼働中ジョブの完全な設定（メモリ上の唯一の正解）

### ai.openclaw.badge-followback
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.badge-followback.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/badge-followback.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/badge-followback.stderr.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.badge-followback
		ai.openclaw.badge-followback.268435595 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 50
				"Hour" => 0
		"com.apple.launchd.calendarinterval" = {
	properties = inferred program
```
### ai.openclaw.comment-warmup
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/comment-warmup.log
	stderr path = /Users/ny/.openclaw/workspace/logs/comment-warmup-err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		MIN_LIKES => 2
		MAX_AGE_HOURS => 18
		REPLY_FOLLOW_DAILY_CAP => 30
		MAX_PICKS_PER_FIRE => 2
		XPC_SERVICE_NAME => ai.openclaw.comment-warmup
		ai.openclaw.comment-warmup.268435559 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 0
				"Hour" => 16
		ai.openclaw.comment-warmup.268435558 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 0
				"Hour" => 12
		ai.openclaw.comment-warmup.268435561 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 0
				"Hour" => 22
		ai.openclaw.comment-warmup.268435560 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 0
				"Hour" => 19
		"com.apple.launchd.calendarinterval" = {
	properties = inferred program
```
### ai.openclaw.follower-snapshot
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.follower-snapshot.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stderr.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.follower-snapshot
		ai.openclaw.follower-snapshot.268435587 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 35
				"Hour" => 0
		"com.apple.launchd.calendarinterval" = {
	properties = inferred program
```
### ai.openclaw.gateway
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.gateway.plist
	program = /Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh
	arguments = {
	stdout path = /Users/ny/.openclaw/logs/gateway.log
	stderr path = /Users/ny/.openclaw/logs/gateway.err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.gateway
	properties = partial import | keepalive | runatload | inferred program
```
### ai.openclaw.import-manual-image
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.import-manual-image.plist
	program = /usr/local/bin/node
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/import-manual-image.out
	stderr path = /Users/ny/.openclaw/workspace/logs/import-manual-image.err
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.import-manual-image
	run interval = 1800 seconds
	properties = inferred program
```
### ai.openclaw.incoming-reply-watcher
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-watcher.plist
	program = /usr/local/bin/node
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.out
	stderr path = /Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.err
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.incoming-reply-watcher
	run interval = 900 seconds
	properties = inferred program
```
### ai.openclaw.node
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.node.plist
	program = /Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh
	arguments = {
	stdout path = /Users/ny/.openclaw/logs/node.log
	stderr path = /Users/ny/.openclaw/logs/node.err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.node
	properties = partial import | keepalive | runatload | inferred program
```
### ai.openclaw.seo-health
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.seo-health.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/seo-health.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/seo-health.stderr.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.seo-health
		ai.openclaw.seo-health.268435590 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 10
				"Hour" => 8
				"Weekday" => 1
		"com.apple.launchd.calendarinterval" = {
	properties = inferred program
```
### ai.openclaw.sitemap-autosubmit
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.sitemap-autosubmit.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stderr.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.sitemap-autosubmit
		ai.openclaw.sitemap-autosubmit.268435589 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 40
				"Hour" => 19
		ai.openclaw.sitemap-autosubmit.268435588 => {
			stream = com.apple.launchd.calendarinterval
				"Minute" => 40
				"Hour" => 7
		"com.apple.launchd.calendarinterval" = {
	properties = inferred program
```
### ai.openclaw.slack-watchdog
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.slack-watchdog.plist
	program = /bin/bash
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/slack-watchdog.log
	stderr path = /Users/ny/.openclaw/workspace/logs/slack-watchdog-err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.slack-watchdog
	properties = keepalive | runatload | inferred program
```
### ai.openclaw.tab-guard
```
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.tab-guard.plist
	program = /usr/local/bin/node
	arguments = {
	stdout path = /Users/ny/.openclaw/workspace/logs/tab-guard.out
	stderr path = /Users/ny/.openclaw/workspace/logs/tab-guard-err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.tab-guard
	properties = keepalive | runatload | inferred program
```

## 2. Time Machine のローカルスナップショット

スナップショットがあれば、そこから壊す前の plist を取り出せる。
```
Snapshots for disk /:
```

TimeMachine の設定:
```
tmutil: No destinations configured.
```

## 3. 潰れた plist に残っている中身（環境変数は生きている）

> `plutil -p` は読み取り専用なので安全。**`-extract` は使わない。**

### ai.openclaw.auto-thread-chainifier  更新=08-22 19:37  21 B
{
  "Hour" => 2
  "Minute" => 0
}
### ai.openclaw.badge-followback  更新=08-22 22:07  161 B
[
  0 => "/bin/bash"
  1 => "-lc"
  2 => "/Users/ny/.openclaw/workspace/scripts/run-badge-followback.sh >> /Users/ny/.openclaw/workspace/logs/badge-followback.log 2>&1"
]
### ai.openclaw.blog-rss-watcher  更新=08-22 20:07  40 B
{
  "SLACK_BOT_TOKEN" => "SET_BY_DRAFT_TREND"
}
### ai.openclaw.bookmark-analyzer  更新=05-15 23:58  835 B
{
  "Label" => "ai.openclaw.bookmark-analyzer"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/bookmark-analyzer.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/bookmark-analyzer.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/bookmark-analyzer.out"
  "StartCalendarInterval" => {
    "Hour" => 9
    "Minute" => 30
    "Weekday" => 1
  }
}
### ai.openclaw.bookmark-watcher  更新=05-15 22:56  830 B
{
  "Label" => "ai.openclaw.bookmark-watcher"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/bookmark-watcher.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/bookmark-watcher.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/bookmark-watcher.out"
  "StartCalendarInterval" => {
    "Hour" => 9
    "Minute" => 5
    "Weekday" => 1
  }
}
### ai.openclaw.canary-silent-gap  更新=07-25 16:03  780 B
{
  "Label" => "ai.openclaw.canary-silent-gap"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "cd /Users/ny/.openclaw/workspace && /usr/local/bin/node scripts/canary-silent-gap.js"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/canary-silent-gap-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/canary-silent-gap.log"
  "StartInterval" => 21600
}
### ai.openclaw.celebrate-100  更新=08-22 20:07  107 B
{
  "PATH" => "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}
### ai.openclaw.chrome-cdp-heal  更新=07-08 18:06  705 B
{
  "Label" => "ai.openclaw.chrome-cdp-heal"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/openclaw/chrome-cdp-heal.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/openclaw/chrome-cdp-heal.stderr.log"
  "StandardOutPath" => "/Users/ny/openclaw/chrome-cdp-heal.stdout.log"
  "StartInterval" => 300
}
### ai.openclaw.chrome-cdp  更新=08-22 22:07  451 B
[
  0 => "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  1 => "--remote-debugging-port=18800"
  2 => "--user-data-dir=/Users/ny/.openclaw/browser/openclaw/user-data"
  3 => "--no-first-run"
  4 => "--no-default-browser-check"
  5 => "--disable-sync"
  6 => "--disable-background-networking"
  7 => "--disable-component-update"
  8 => "--disable-features=Translate,MediaRouter"
  9 => "--disable-session-crashed-bubble"
  10 => "--hide-crash-restore-bubble"
  11 => "--password-store=basic"
  12 => "--no-proxy-server"
### ai.openclaw.chrome-restart-hook  更新=08-22 20:07  66 B
{
  "PATH" => "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
}
### ai.openclaw.comment-warmup  更新=08-22 20:07  93 B
{
  "MAX_AGE_HOURS" => "18"
  "MAX_PICKS_PER_FIRE" => "2"
  "MIN_LIKES" => "2"
  "REPLY_FOLLOW_DAILY_CAP" => "30"
}
### ai.openclaw.competitor-follower-follow  更新=08-22 22:07  103 B
[
  0 => "/usr/local/bin/node"
  1 => "/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js"
]
### ai.openclaw.cookie-backup  更新=07-04 21:46  968 B
{
  "Label" => "ai.openclaw.cookie-backup"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/cookie-backup.sh"
  ]
  "StandardErrorPath" => "/tmp/cookie-backup.err.log"
  "StandardOutPath" => "/tmp/cookie-backup.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 4
      "Minute" => 0
    }
    1 => {
### ai.openclaw.cost-monitor-health  更新=05-10 15:28  735 B
{
  "Label" => "ai.openclaw.cost-monitor-health"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/health-check-cost-monitor.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/cost-monitor-health-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/cost-monitor-health.log"
  "StartInterval" => 7200
}
### ai.openclaw.cost-monitor  更新=05-10 15:28  715 B
{
  "Label" => "ai.openclaw.cost-monitor"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-cost-monitor.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/cost-monitor-stderr.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/cost-monitor-stdout.log"
  "StartInterval" => 3600
}
### ai.openclaw.cost-report-daily  更新=05-09 23:57  784 B
{
  "Label" => "ai.openclaw.cost-report-daily"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-daily-cost-report.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/cost-report-daily-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/cost-report-daily.log"
  "StartCalendarInterval" => {
    "Hour" => 0
    "Minute" => 5
  }
}
### ai.openclaw.crd-detect-daemon  更新=07-11 19:10  686 B
{
  "KeepAlive" => true
  "Label" => "ai.openclaw.crd-detect-daemon"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/crd-detect-daemon.js"
  ]
  "RunAtLoad" => true
  "StandardErrorPath" => "/tmp/crd-detect-daemon.err.log"
  "StandardOutPath" => "/tmp/crd-detect-daemon.log"
  "ThrottleInterval" => 60
}
### ai.openclaw.daily-action-norm  更新=05-15 16:02  786 B
{
  "Label" => "ai.openclaw.daily-action-norm"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/daily-action-norm.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/daily-action-norm.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/daily-action-norm.out"
  "StartCalendarInterval" => {
    "Hour" => 6
    "Minute" => 0
  }
}
### ai.openclaw.daily-follow-summary  更新=06-07 15:19  1078 B
{
  "Label" => "ai.openclaw.daily-follow-summary"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/daily-follow-summary-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/daily-follow-summary.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 23
      "Minute" => 0
### ai.openclaw.daily-must-rule-review  更新=06-14 14:56  786 B
{
  "Label" => "ai.openclaw.daily-must-rule-review"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/daily-must-rule-review.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/daily-must-rule-review-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/daily-must-rule-review.log"
  "StartCalendarInterval" => {
    "Hour" => 9
    "Minute" => 0
  }
}
### ai.openclaw.daily-task-audit  更新=08-22 20:07  87 B
{
  "HOME" => "/Users/ny"
  "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
}
### ai.openclaw.draft-eve  更新=05-09 20:05  777 B
{
  "Label" => "ai.openclaw.draft-eve"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-draft.sh"
    2 => "19:00"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/draft-eve-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/draft-eve.log"
  "StartCalendarInterval" => {
    "Hour" => 18
    "Minute" => 30
  }
}
### ai.openclaw.draft-late  更新=05-17 02:59  770 B
{
  "Label" => "ai.openclaw.draft-late"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-draft.sh"
    2 => "21:00"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/draft-late-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/draft-late.log"
  "StartCalendarInterval" => {
    "Hour" => 20
    "Minute" => 30
  }
}
### ai.openclaw.draft-noon  更新=05-15 15:56  779 B
{
  "Label" => "ai.openclaw.draft-noon"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-draft.sh"
    2 => "12:30"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/draft-noon-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/draft-noon.log"
  "StartCalendarInterval" => {
    "Hour" => 12
    "Minute" => 0
  }
}
### ai.openclaw.engage-daily  更新=05-09 19:55  759 B
{
  "Label" => "ai.openclaw.engage-daily"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-engage.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/engage-daily-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/engage-daily.log"
  "StartCalendarInterval" => {
    "Hour" => 18
    "Minute" => 0
  }
}
### ai.openclaw.fire-watchdog  更新=05-11 16:44  709 B
{
  "Label" => "ai.openclaw.fire-watchdog"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-fire-watchdog.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/fire-watchdog-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/fire-watchdog.log"
  "StartInterval" => 3600
}
### ai.openclaw.follow-watchdog  更新=08-22 20:07  87 B
{
  "HOME" => "/Users/ny"
  "PATH" => "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
}
### ai.openclaw.follower-daily-report  更新=07-04 22:20  1066 B
{
  "Label" => "ai.openclaw.follower-daily-report"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/follower-daily-report-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/follower-daily-report.log"
  "StartCalendarInterval" => {
    "Hour" => 8
    "Minute" => 0
  }
### ai.openclaw.follower-monitor  更新=06-04 01:14  1109 B
{
  "Label" => "ai.openclaw.follower-monitor"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/follower-monitor-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/follower-monitor.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 12
      "Minute" => 30
### ai.openclaw.follower-snapshot  更新=05-24 01:16  982 B
{
  "Label" => "ai.openclaw.follower-snapshot"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-lc"
    2 => "cd /Users/ny/.openclaw/workspace && SLACK_BOT_TOKEN=$(jq -r .channels.slack.botToken /Users/ny/.openclaw/openclaw.json) /usr/local/bin/node scripts/follower-snapshot.js >
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/follower-snapshot.stderr.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/follower-snapshot.stdout.log"
  "StartCalendarInterval" => {
    "Hour" => 0
    "Minute" => 35
  }
}
### ai.openclaw.gateway  更新=05-17 18:46  1263 B
{
  "Comment" => "OpenClaw Gateway (v2026.5.7)"
  "KeepAlive" => true
  "Label" => "ai.openclaw.gateway"
  "ProgramArguments" => [
    0 => "/Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh"
    1 => "/Users/ny/.openclaw/service-env/ai.openclaw.gateway.env"
    2 => "/Users/ny/.openclaw/tools/node-v22.22.0/bin/node"
    3 => "/Users/ny/.openclaw/tools/node-v22.22.<MASKED>.js"
    4 => "gateway"
    5 => "--port"
    6 => "18789"
  ]
  "RunAtLoad" => true
### ai.openclaw.grok-trending-daily  更新=07-20 15:49  1149 B
{
  "Label" => "ai.openclaw.grok-trending-daily"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/grok-trending-daily-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/grok-trending-daily.log"
  "StartCalendarInterval" => {
    "Hour" => 8
    "Minute" => 0
  }
### ai.openclaw.hashtag-follow  更新=08-22 22:07  91 B
[
  0 => "/usr/local/bin/node"
  1 => "/Users/ny/.openclaw/workspace/scripts/hashtag-follow.js"
]
### ai.openclaw.import-manual-image  更新=05-14 00:46  701 B
{
  "Label" => "ai.openclaw.import-manual-image"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/import-manual-image.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/import-manual-image.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/import-manual-image.out"
  "StartInterval" => 1800
}
### ai.openclaw.incoming-reply-responder  更新=08-22 20:07  42 B
{
  "INCOMING_REPLY_MAX" => "5"
  "SKIP_POST" => "1"
}
### ai.openclaw.incoming-reply-watcher  更新=05-17 02:31  712 B
{
  "Label" => "ai.openclaw.incoming-reply-watcher"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.out"
  "StartInterval" => 900
}
### ai.openclaw.memory-review  更新=08-22 20:07  66 B
{
  "PATH" => "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
}
### ai.openclaw.monthly-kpi-report  更新=05-15 16:01  834 B
{
  "Label" => "ai.openclaw.monthly-kpi-report"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/monthly-kpi-report.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/monthly-kpi-report.out"
  "StartCalendarInterval" => {
    "Day" => 1
    "Hour" => 9
    "Minute" => 0
  }
}
### ai.openclaw.node  更新=05-09 11:42  1226 B
{
  "Comment" => "OpenClaw Gateway (v2026.5.7)"
  "KeepAlive" => true
  "Label" => "ai.openclaw.node"
  "ProgramArguments" => [
    0 => "/Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh"
    1 => "/Users/ny/.openclaw/service-env/ai.openclaw.node.env"
    2 => "/usr/local/bin/node"
    3 => "/Users/ny/.<MASKED>.js"
    4 => "node"
    5 => "run"
    6 => "--host"
    7 => "127.0.0.1"
    8 => "--port"
### ai.openclaw.pipeline-guardian  更新=08-07 06:36  791 B
{
  "Label" => "ai.openclaw.pipeline-guardian"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/pipeline-guardian.js"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-guardian-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-guardian.out"
  "StartInterval" => 900
  "WorkingDirectory" => "/Users/ny/.openclaw/workspace"
}
### ai.openclaw.pipeline-heartbeat  更新=07-25 16:03  1033 B
{
  "Label" => "ai.openclaw.pipeline-heartbeat"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "cd /Users/ny/.openclaw/workspace && /usr/local/bin/node scripts/pipeline-heartbeat.js"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-heartbeat-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/pipeline-heartbeat.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 8
      "Minute" => 0
### ai.openclaw.poll-approvals  更新=05-09 11:27  706 B
{
  "Label" => "ai.openclaw.poll-approvals"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/poll-approvals.sh"
  ]
  "RunAtLoad" => true
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/poll-approvals-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/poll-approvals.log"
  "StartInterval" => 60
}
### ai.openclaw.post-metrics-collector  更新=05-15 23:53  714 B
{
  "Label" => "ai.openclaw.post-metrics-collector"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/post-metrics-collector.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/post-metrics-collector.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/post-metrics-collector.out"
  "StartInterval" => 21600
}
### ai.openclaw.publish-hanabi-oneshot  更新=07-06 00:03  826 B
{
  "Label" => "ai.openclaw.publish-hanabi-oneshot"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/publish-hanabi-oneshot.sh"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/tmp/hanabi-oneshot-stderr.log"
  "StandardOutPath" => "/tmp/hanabi-oneshot-stdout.log"
  "StartCalendarInterval" => {
    "Day" => 6
    "Hour" => 8
    "Minute" => 0
    "Month" => 7
### ai.openclaw.qt-daily  更新=08-22 20:07  25 B
{
  "QT_PICKS_PER_FIRE" => "2"
}
### ai.openclaw.qt-past-daily  更新=06-13 18:21  757 B
{
  "Label" => "ai.openclaw.qt-past-daily"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/qt-past-articles-orchestrator.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/qt-past-daily-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/qt-past-daily.log"
  "StartCalendarInterval" => {
    "Hour" => 10
    "Minute" => 0
  }
}
### ai.openclaw.refollow-may18-once  更新=05-18 23:02  1067 B
{
  "Label" => "ai.openclaw.refollow-may18-once"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/refollow-may18-incident.js"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/logs/refollow-may18-once.err"
  "StandardOutPath" => "/Users/ny/.openclaw/logs/refollow-may18-once.log"
  "StartCalendarInterval" => [
    0 => {
      "Day" => 20
      "Hour" => 21
      "Minute" => 0
### ai.openclaw.reply-followback-check  更新=05-13 16:01  965 B
{
  "Label" => "ai.openclaw.reply-followback-check"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/reply-followback-check.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/reply-followback-check.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/reply-followback-check.out"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 1
      "Minute" => 15
    }
    1 => {
### ai.openclaw.reply-followers-cleanup  更新=05-13 16:01  717 B
{
  "Label" => "ai.openclaw.reply-followers-cleanup"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.out"
  "StartInterval" => 3600
}
### ai.openclaw.revenge-unfollow  更新=08-22 20:07  54 B
{
  "REVENGE_DRY_RUN" => "false"
  "REVENGE_MAX_PER_RUN" => "10"
}
### ai.openclaw.scheduled-entry-watchdog  更新=07-11 18:47  682 B
{
  "Label" => "ai.openclaw.scheduled-entry-watchdog"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/scheduled-entry-watchdog.js"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/tmp/scheduled-entry-watchdog.err.log"
  "StandardOutPath" => "/tmp/scheduled-entry-watchdog.log"
  "StartInterval" => 60
}
### ai.openclaw.seo-health  更新=08-08 09:42  984 B
{
  "Label" => "ai.openclaw.seo-health"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-lc"
    2 => "/opt/homebrew/bin/python3.11 /Users/ny/projects/anta-baka-x/blog/scripts/seo-health-monitor.py >> /Users/ny/.openclaw/workspace/logs/seo-health.log 2>&1"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/seo-health.stderr.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/seo-health.stdout.log"
  "StartCalendarInterval" => {
    "Hour" => 8
    "Minute" => 10
    "Weekday" => 1
### ai.openclaw.sheet-sync  更新=08-22 20:07  66 B
{
  "PATH" => "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
}
### ai.openclaw.sitemap-autosubmit  更新=08-08 10:09  1060 B
{
  "Label" => "ai.openclaw.sitemap-autosubmit"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-lc"
    2 => "/opt/homebrew/bin/python3.11 /Users/ny/projects/anta-baka-x/blog/scripts/sitemap-autosubmit.py >> /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.log 2>&1"
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stderr.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stdout.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 7
      "Minute" => 40
### ai.openclaw.slack-watchdog  更新=05-11 02:06  746 B
{
  "KeepAlive" => true
  "Label" => "ai.openclaw.slack-watchdog"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/run-slack-watchdog.sh"
  ]
  "RunAtLoad" => true
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/slack-watchdog-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/slack-watchdog.log"
  "ThrottleInterval" => 10
}
### ai.openclaw.tab-guard  更新=08-09 18:19  768 B
{
  "KeepAlive" => true
  "Label" => "ai.openclaw.tab-guard"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/tab-guard.js"
    2 => "--watch"
  ]
  "RunAtLoad" => true
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard.out"
  "WorkingDirectory" => "/Users/ny/.openclaw/workspace"
}
### ai.openclaw.trend-daily  更新=05-18 12:19  764 B
{
  "Label" => "ai.openclaw.trend-daily"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/trend-orchestrator.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/trend-daily-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/trend-daily.log"
  "StartCalendarInterval" => {
    "Hour" => 9
    "Minute" => 30
  }
}
### ai.openclaw.unfollow-cleanup-evening  更新=08-22 22:07  409 B
[
  0 => "/bin/bash"
  1 => "-c"
  2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c.c
]
### ai.openclaw.unfollow-cleanup-morning  更新=08-22 22:07  409 B
[
  0 => "/bin/bash"
  1 => "-c"
  2 => "eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c.c
]
### ai.openclaw.unfollow-daily  更新=08-22 20:07  126 B
{
  "PATH" => "/usr/local/bin:/usr/bin:/bin"
  "UNFOLLOW_DRY_RUN" => "false"
  "UNFOLLOW_MAX_PER_RUN" => "20"
  "UNFOLLOW_STALE_DAYS" => "1"
}
### ai.openclaw.unfollow-evening  更新=08-22 20:07  126 B
{
  "PATH" => "/usr/local/bin:/usr/bin:/bin"
  "UNFOLLOW_DRY_RUN" => "false"
  "UNFOLLOW_MAX_PER_RUN" => "20"
  "UNFOLLOW_STALE_DAYS" => "1"
}
### ai.openclaw.unfollow-stats-monitor  更新=08-22 22:07  251 B
[
  0 => "/bin/bash"
  1 => "-lc"
  2 => "cd /Users/ny/.openclaw/workspace && SLACK_BOT_TOKEN=$(jq -r .channels.slack.botToken /Users/ny/.openclaw/openclaw.json) /usr/local/bin/node scripts/unfollow-stats-monitor.j
]
### ai.openclaw.v3-violation-watchdog  更新=05-15 15:57  710 B
{
  "Label" => "ai.openclaw.v3-violation-watchdog"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/v3-violation-watchdog.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/v3-violation-watchdog.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/v3-violation-watchdog.out"
  "StartInterval" => 21600
}
### ai.openclaw.variety-audit  更新=06-13 19:30  796 B
{
  "Label" => "ai.openclaw.variety-audit"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/variety-audit.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/variety-audit-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/variety-audit.log"
  "StartCalendarInterval" => {
    "Hour" => 10
    "Minute" => 30
    "Weekday" => 1
  }
}
### ai.openclaw.weekly-design-reminder  更新=05-14 00:46  845 B
{
  "Label" => "ai.openclaw.weekly-design-reminder"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "/Users/ny/.openclaw/workspace/scripts/weekly-design-reminder.sh"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/weekly-design-reminder.err"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/weekly-design-reminder.out"
  "StartCalendarInterval" => {
    "Hour" => 10
    "Minute" => 0
    "Weekday" => 1
  }
}
### ai.openclaw.x-login-compat-test  更新=07-04 21:49  1021 B
{
  "Label" => "ai.openclaw.x-login-compat-test"
  "ProgramArguments" => [
    0 => "/bin/bash"
    1 => "-c"
    2 => "source /Users/ny/openclaw/config/.env; SLACK_BOT_TOKEN="$OPENCLAW_BOT_TOKEN" /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/x-login-compat-test.js >> /Users/ny
  ]
  "RunAtLoad" => false
  "StandardErrorPath" => "/tmp/x-login-compat-test.stderr.log"
  "StandardOutPath" => "/tmp/x-login-compat-test.stdout.log"
  "StartCalendarInterval" => {
    "Hour" => 3
    "Minute" => 0
    "Weekday" => 2
### ai.openclaw.x-login-monitor  更新=08-22 20:07  66 B
{
  "PATH" => "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
}

## 4. scripts の実在（復元先の確認）

- auto-thread-chainifier.js: あり（83 行）
- badge-followback.js: あり（222 行）
- competitor-follower-follow.js: あり（168 行）
- hashtag-follow.js: あり（174 行）
- revenge-unfollow.js: あり（212 行）
- auto_detect_and_unfollow_inactive.js: あり（157 行）

## 5. Chrome CDP

016 の実測で **18810 が応答している**（18800 ではなかった）。
```
{
   "Browser": "Chrome/140.0.7339.207",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/```
