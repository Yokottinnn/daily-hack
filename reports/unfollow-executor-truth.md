# アンフォローの実行役はどれか（2026-09-06 20:15 JST・費用 $0）

> **判定側は動いている。外す側が動いていない。**
> 予約 207 件のうち **196 件が期限を過ぎたまま残っている。**
> 同時にフォローは今日 16 件 増えている。**入れるだけで出さない状態。**
> **何も触らない。読むだけ。**

## 1. `scheduled_unfollow_at` を読むのはどのスクリプトか

**`reply-followback-check.js` は予約するだけ。実行役は別にいる。**

```
  reply-followers-cleanup.js                   3253 B  更新 2026-05-13 16:00
  comment-orchestrator.sh.pre-tonegate.20260828-155126   8483 B  更新 2026-08-29 00:51
  comment-orchestrator.sh.pre-ngfilter.20260827-133807   8256 B  更新 2026-08-27 22:38
  comment-orchestrator.sh                      8693 B  更新 2026-08-29 00:51
  reply-followback-check.js                    3131 B  更新 2026-08-02 20:31
```

### そのうち「外す」動作を持つもの（`unfollow` を呼んでいる）

```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t058-unfollow-executor-truth.sh: line 84: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t058-unfollow-executor-truth.sh: line 84: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t058-unfollow-executor-truth.sh: line 84: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t058-unfollow-executor-truth.sh: line 84: [: 0
0: integer expression expected
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/t058-unfollow-executor-truth.sh: line 84: [: 0
0: integer expression expected
```

### 実行役の候補を全文で読む


## 2. どのスクリプトが どの CDP ポートを見ているか

**18810 が正しい**（`ensure-chrome.sh:PORT`）。**18800 は存在しない。**

```
   130 18810

  ポート別の内訳:
    :18810 を見ているファイル
      _cmr.js
      a8net_login.js
      audit-wrong-unfollows.js
      badge-followback.js
      bookmark-watcher.js
      canary-silent-gap.js
      capture-design-now.js
      capture-design-v2.js
      capture-design-v3.js
      capture-design-v4.js
      capture-design-v5.js
      cdp-health.js
      check-claude-state.js
      check-current-follower.js
      check-followback.js
      check-follower-v2.js
      check-recent-posts.js
      check-tweets.js
      check-unfollowed-status.js
      chrome-diag.js
      claude-ai-login-debug.js
      claude-ai-login.js
      claude-artifact-v2.js
      claude-console-login.js
      claude-design-smoke.js
      claude-design-submit.js
      claude-design-wait-artifact.js
      claude-test-small.js
      competitor-follower-follow.js
      compose-page-test.js
      delete-tweets.js
      dm-lib.js
      engage-via-playwright.js
      ensure-x-login.js
      extract-and-render.js
      extract-render-v2.js
      fetch-4-tweets.js
      fetch-cost-csv.js
      fetch-ffbuncho.js
      fetch-following.js
      find-wangan-post.js
      follow-handle.js
      follow-via-playwright.js
      follow-watchdog.js
      follower-snapshot.js
      full-flow-v2.js
      full-flow.js
      gen-card-design-v2.js
      gen-card-design.js
      gen-card-pattern.js
      gen-card-template.js
      gen-card.js
      gen-day12-2.js
      google-login.js
      grok-trending-daily.js
      incoming-reply-responder.js
      incoming-reply-watcher.js
      monthly-kpi-report.js
      pipeline-guardian.js
      pipeline-heartbeat.js
      post-comment.js
      post-metrics-collector.js
      post-pinned-tweet.js
      post-publish-watchdog.js
      post-qt-manual.js
      post-qt-v2.js
      post-quote-tweet.js
      post-via-playwright.js
      probe-add-to-chat.js
      probe-attach-deep.js
      probe-attach-flow.js
      probe-claude-design-2.js
      probe-claude-design-3.js
      probe-claude-design.js
      probe-design-upload.js
      probe-followback-truth.js
      probe-upload-flow.js
      qt-probe-v2.js
      qt-probe.js
      quick-reply-watcher.js
      render-via-cdp.js
      respond-to-2-replies.js
      retry-2-replies.js
      revenge-unfollow.js
      sc-execute-v2.js
      sc-execute.js
      sc-extract-all.js
      sc-extract-v3.js
      sc-fix-memos.js
      sc-goto-page1.js
      sc-login-test.js
      sc-probe-card.js
      sc-probe-memo-edit.js
      sc-probe-pager.js
      sc-probe-star.js
      sc-probe-star2.js
      sc-screenshot-memo-edit.js
      sc-test-flow.js
      sc-test-memo.js
      sc-test-select-job.js
      sc-verify-memos.js
      sc-view-list.js
      scrape-tweet-engagement.js
      scrape-tweet-replies-2063979763619021022.js
      scrape-x-images.js
      selfback_scrape.js
      tab-guard.js
      test-image-upload.js
      test-post-sweeper.js
      tmp-debug-scrape.js
      tmp-debug-scrape2.js
      tmp-verify-x-post.js
      trend-detect.js
      unfollow-cleanup.js
      unfollow-handle.js
      unfollow-via-playwright.js
      x-error-probe.js
      x-form-probe.js
      x-login-compat-test.js
      x-login-probe.js
      x-login.js
      x-pinned-dom-probe.js
      x-ref-fetch.js
      x-search-discover.js
      x-submit-probe.js
      cookie-restore.sh
      dm-orchestrator.sh
      ensure-chrome.sh
      qt-orchestrator.sh
      qt-past-articles-orchestrator.sh
      restore-cookies-and-relaunch.sh
      run-dm-reply.sh
      wave-freeze.sh
      x-login-monitor.sh
    :18800 を見ているファイル
      ensure-chrome.sh
    :9222 を見ているファイル
```

## 3. 壊れている 6 本の plist の中身（**実物**）

`plutil -lint` が `Unexpected character {` と言う＝**XML ではなく JSON**。
何を書こうとしたのかが読めれば、**正しい XML に起こし直せる。**

### `follow-watchdog`

- 87 B / 更新 2026-08-22 20:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.follow-watchdog.plist: (Unexpected character { at line 1)

```
{"PATH":"\/usr\/local\/bin:\/opt\/homebrew\/bin:\/usr\/bin:\/bin","HOME":"\/Users\/ny"}```

### `unfollow-daily`

- 126 B / 更新 2026-08-22 20:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist: (Unexpected character { at line 1)

```
{"UNFOLLOW_DRY_RUN":"false","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","UNFOLLOW_STALE_DAYS":"1","UNFOLLOW_MAX_PER_RUN":"20"}```

### `unfollow-evening`

- 126 B / 更新 2026-08-22 20:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist: (Unexpected character { at line 1)

```
{"UNFOLLOW_DRY_RUN":"false","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","UNFOLLOW_STALE_DAYS":"1","UNFOLLOW_MAX_PER_RUN":"20"}```

### `unfollow-cleanup-morning`

- 409 B / 更新 2026-08-22 22:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-morning.plist: (Unexpected character [ at line 1)

```
["\/bin\/bash","-c","eval \"$(\/usr\/local\/bin\/node -e \"const c=require('\/Users\/ny\/.openclaw\/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c.channels.slack.botToken)||''));\")\"; cd \/Users\/ny\/.openclaw\/workspace; \/Users\/ny\/.openclaw\/workspace\/scripts\/ensure-chrome.sh; MAX_PER_FIRE=3 \/usr\/local\/bin\/node scripts\/unfollow-cleanup.js"]```

### `unfollow-cleanup-evening`

- 409 B / 更新 2026-08-22 22:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-evening.plist: (Unexpected character [ at line 1)

```
["\/bin\/bash","-c","eval \"$(\/usr\/local\/bin\/node -e \"const c=require('\/Users\/ny\/.openclaw\/openclaw.json');console.log('export SLACK_BOT_TOKEN='+JSON.stringify((c.channels&&c.channels.slack&&c.channels.slack.botToken)||''));\")\"; cd \/Users\/ny\/.openclaw\/workspace; \/Users\/ny\/.openclaw\/workspace\/scripts\/ensure-chrome.sh; MAX_PER_FIRE=2 \/usr\/local\/bin\/node scripts\/unfollow-cleanup.js"]```

### `revenge-unfollow`

- 54 B / 更新 2026-08-22 20:07
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.revenge-unfollow.plist: (Unexpected character { at line 1)

```
{"REVENGE_DRY_RUN":"false","REVENGE_MAX_PER_RUN":"10"}```


## 4. 生きている plist（**作り直しの雛形**）

同じ系統で**実際にロードできているもの**を雛形にする。当て推量で書かない。

### `reply-followback-check`（965 B・lint OK）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.reply-followback-check</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/ny/.openclaw/workspace/scripts/reply-followback-check.js</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Hour</key>
      <integer>1</integer>
      <key>Minute</key>
      <integer>15</integer>
    </dict>
    <dict>
      <key>Hour</key>
      <integer>13</integer>
      <key>Minute</key>
      <integer>15</integer>
    </dict>
  </array>
  <key>StandardOutPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/reply-followback-check.out</string>
  <key>StandardErrorPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/reply-followback-check.err</string>
</dict>
</plist>
```

### `auto-detect-and-unfollow-inactive`（973 B・lint OK）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>/usr/local/bin:/usr/bin:/bin</string>
	</dict>
	<key>Label</key>
	<string>ai.openclaw.auto-detect-and-unfollow-inactive</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/local/bin/node</string>
		<string>/Users/ny/.openclaw/workspace/scripts/auto_detect_and_unfollow_inactive.js</string>
	</array>
	<key>StandardErrorPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/auto-detect-and-unfollow-inactive-err.log</string>
	<key>StandardOutPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/auto-detect-and-unfollow-inactive.log</string>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
			<key>Hour</key>
			<integer>22</integer>
			<key>Minute</key>
			<integer>30</integer>
		</dict>
	</array>
</dict>
</plist>
```

### `badge-followback`（892 B・lint OK）

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>ai.openclaw.badge-followback</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>-lc</string>
		<string>/Users/ny/.openclaw/workspace/scripts/run-badge-followback.sh &gt;&gt; /Users/ny/.openclaw/workspace/logs/badge-followback.log 2&gt;&amp;1</string>
	</array>
	<key>StandardErrorPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/badge-followback.stderr.log</string>
	<key>StandardOutPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/badge-followback.stdout.log</string>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
			<key>Hour</key>
			<integer>0</integer>
			<key>Minute</key>
			<integer>50</integer>
		</dict>
	</array>
</dict>
</plist>
```


## 5. 期限が来ている 196 件の内訳（**どれくらい古いか**）

```
  期限到来: 197 件
    0日        1 件 放置
    1〜2日      3 件 放置
    3〜6日      1 件 放置
    7〜13日     4 件 放置
    14〜29日    24 件 放置
    30日以上     164 件 放置
  いちばん古い期限: 2026-05-20
```

**古いものほど、フォロバが無いまま長くフォローし続けている。**

---

**何も触っていない。アンフォローもフォローもしていない（$0）。**
