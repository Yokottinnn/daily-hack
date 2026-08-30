# ポーラーが動いていない原因を出して直す（2026-08-31 01:14:53 JST）

> `t008` は成功したのに `t009` が 21 分 走らなかった。
> **origin/main にあることと、ディスクにあることは別である。**

## 1. 疑いを確かめる

- 作業ツリーの `scripts/ops-run-tasks.sh`: **無い** ← **これが原因**
  plist が指しているのは `/Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh`
- origin/main にはあるか: **ある**

### ポーラーの launchd 状態（直す前）
```
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.ops-poller.plist
	state = not running
	program = /bin/bash
	stdout path = /Users/ny/.openclaw/logs/ops-poller.out.log
	stderr path = /Users/ny/.openclaw/logs/ops-poller.err.log
	runs = 31
	last exit code = 127
		state = active
		state = active
	properties = runatload | inferred program
```

### ポーラーのエラーログ（末尾）
```
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
```

## 2. 直す（**作業ツリーに依存しない場所へ実体を置く**）

- 書き出した: `/Users/ny/.openclaw/bin/ops-run-tasks.sh`（5494 B）
- 構文: **OK**

> `ops-run-tasks.sh` は起動時に origin/main から自分を更新して exec し直すので、
> **この写しは古くなっても自動で最新になる。** 置き場を変える必要は以後無い。

### plist の ProgramArguments を差し替える

- 前: ['/bin/bash', '/Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh']
- 後: ['/bin/bash', '/Users/ny/.openclaw/bin/ops-run-tasks.sh']
- StartInterval: 60 / OPS_PUSH=1

## 3. 読み込み直す（**触るのは ops-poller だけ**）

- ロード: **1** 件

## 4. 実際に走ったか（**90 秒 待って exit status を見る**）

> このタスクはロックを握っているので、待っても `t009` は動けない
> （`ops-run-tasks.sh` はロックが取れなければ黙って終わる）。
> **見るのは「ポーラーが起動して正常終了したか」。**
```
	state = not running
	runs = 2
	last exit code = 0
		state = active
		state = active
```

### ポーラーのログ（直したあと）
```
-- out --
-- err --
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
```

**`last exit code = 0` なら成功。** このタスクが終わってロックが外れれば、
**60 秒以内に `t009` が走る。**

## 5. 稼働ジョブが 20 → 7 に減っている件（**一覧を出すだけ。直さない**）

14:44 UTC は 20 件、15:14 UTC は 6 件。**14 件 消えている。**
原因が分からないので**当て推量で戻さない。**

### いま launchctl に載っているもの
```
PID	Status	Label
-	0	com.dailyhack.ops-poller
-	0	com.dailyhack.rc-keeper
53365	1	ai.openclaw.tab-guard
-	0	com.dailyhack.openclaw.heartbeat
850	0	com.dailyhack.openclaw.listener
56569	0	com.dailyhack.ops-heartbeat
-	0	com.dailyhack.weekly-blog-report
```

### LaunchAgents に plist はあるのに、載っていないもの
```
未ロード: ai.openclaw.auto-detect-and-unfollow-inactive
未ロード: ai.openclaw.auto-thread-chainifier
未ロード: ai.openclaw.badge-followback
未ロード: ai.openclaw.blog-rss-watcher
未ロード: ai.openclaw.bookmark-analyzer
未ロード: ai.openclaw.bookmark-watcher
未ロード: ai.openclaw.canary-silent-gap
未ロード: ai.openclaw.celebrate-100
未ロード: ai.openclaw.chrome-cdp-heal
未ロード: ai.openclaw.chrome-cdp
未ロード: ai.openclaw.chrome-restart-hook
未ロード: ai.openclaw.comment-warmup
未ロード: ai.openclaw.competitor-follower-follow
未ロード: ai.openclaw.cookie-backup
未ロード: ai.openclaw.cost-monitor-health
未ロード: ai.openclaw.cost-monitor
未ロード: ai.openclaw.cost-report-daily
未ロード: ai.openclaw.crd-detect-daemon
未ロード: ai.openclaw.daily-action-norm
未ロード: ai.openclaw.daily-follow-summary
未ロード: ai.openclaw.daily-must-rule-review
未ロード: ai.openclaw.daily-task-audit
未ロード: ai.openclaw.draft-eve
未ロード: ai.openclaw.draft-late
未ロード: ai.openclaw.draft-noon
```
