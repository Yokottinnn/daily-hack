# launchctl print の原本（2026-08-22T17:09:25Z）

> plist を潰したため、**これが唯一の復元元**。再起動すると失われる。

## ai.openclaw.auto-detect-and-unfollow-inactive
```
gui/501/ai.openclaw.auto-detect-and-unfollow-inactive = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.auto-detect-and-unfollow-inactive.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/auto_detect_and_unfollow_inactive.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/auto-detect-and-unfollow-inactive.log
	stderr path = /Users/ny/.openclaw/workspace/logs/auto-detect-and-unfollow-inactive-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /usr/local/bin:/usr/bin:/bin
		XPC_SERVICE_NAME => ai.openclaw.auto-detect-and-unfollow-inactive
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 0
	last exit code = (never exited)

	event triggers = {
		ai.openclaw.auto-detect-and-unfollow-inactive.268435607 => {
			keepalive = 0
			service = ai.openclaw.auto-detect-and-unfollow-inactive
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 30
				"Hour" => 22
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x0
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.auto-thread-chainifier
```
gui/501/ai.openclaw.auto-thread-chainifier = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.auto-thread-chainifier.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/auto-thread-chainifier.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/auto-thread-chainifier.log
	stderr path = /Users/ny/.openclaw/workspace/logs/auto-thread-chainifier-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /usr/local/bin:/usr/bin:/bin
		XPC_SERVICE_NAME => ai.openclaw.auto-thread-chainifier
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 1
	last exit code = 0

	event triggers = {
		ai.openclaw.auto-thread-chainifier.268435606 => {
			keepalive = 0
			service = ai.openclaw.auto-thread-chainifier
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 2
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0xb779b
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 97622
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.auto-thread-chainifier
	}

	jetsam coalition = {
		ID = 97623
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.auto-thread-chainifier
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.badge-followback
```
gui/501/ai.openclaw.badge-followback = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.badge-followback.plist
	type = LaunchAgent
	state = not running

	program = /bin/bash
	arguments = {
		/bin/bash
		-lc
		/Users/ny/.openclaw/workspace/scripts/run-badge-followback.sh >> /Users/ny/.openclaw/workspace/logs/badge-followback.log 2>&1
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/badge-followback.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/badge-followback.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.badge-followback
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 1
	last exit code = 0

	event triggers = {
		ai.openclaw.badge-followback.268435595 => {
			keepalive = 0
			service = ai.openclaw.badge-followback
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 50
				"Hour" => 0
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x84213
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 97091
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.badge-followback
	}

	jetsam coalition = {
		ID = 97092
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.badge-followback
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.comment-warmup
```
gui/501/ai.openclaw.comment-warmup = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
	type = LaunchAgent
	state = not running

	program = /bin/bash
	arguments = {
		/bin/bash
		/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/comment-warmup.log
	stderr path = /Users/ny/.openclaw/workspace/logs/comment-warmup-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		MIN_LIKES => 2
		MAX_AGE_HOURS => 18
		REPLY_FOLLOW_DAILY_CAP => 30
		MAX_PICKS_PER_FIRE => 2
		XPC_SERVICE_NAME => ai.openclaw.comment-warmup
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 29
	last exit code = 0

	event triggers = {
		ai.openclaw.comment-warmup.268435559 => {
			keepalive = 0
			service = ai.openclaw.comment-warmup
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 16
			}
		}
		ai.openclaw.comment-warmup.268435558 => {
			keepalive = 0
			service = ai.openclaw.comment-warmup
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 12
			}
		}
		ai.openclaw.comment-warmup.268435561 => {
			keepalive = 0
			service = ai.openclaw.comment-warmup
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 22
			}
		}
		ai.openclaw.comment-warmup.268435560 => {
			keepalive = 0
			service = ai.openclaw.comment-warmup
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 19
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x1157d3
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 37078
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.comment-warmup
	}

	jetsam coalition = {
		ID = 37079
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.comment-warmup
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.competitor-follower-follow
```
gui/501/ai.openclaw.competitor-follower-follow = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.competitor-follower-follow.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/competitor-follower-follow.log
	stderr path = /Users/ny/.openclaw/workspace/logs/competitor-follower-follow-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /usr/local/bin:/usr/bin:/bin
		COMPETITOR_FOLLOW_DAILY_CAP => 5
		XPC_SERVICE_NAME => ai.openclaw.competitor-follower-follow
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 0
	last exit code = (never exited)

	event triggers = {
		ai.openclaw.competitor-follower-follow.268435603 => {
			keepalive = 0
			service = ai.openclaw.competitor-follower-follow
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 30
				"Hour" => 18
			}
		}
		ai.openclaw.competitor-follower-follow.268435602 => {
			keepalive = 0
			service = ai.openclaw.competitor-follower-follow
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 30
				"Hour" => 11
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x0
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.follower-snapshot
```
gui/501/ai.openclaw.follower-snapshot = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.follower-snapshot.plist
	type = LaunchAgent
	state = not running

	program = /bin/bash
	arguments = {
		/bin/bash
		-lc
		cd /Users/ny/.openclaw/workspace && SLACK_BOT_TOKEN=$(jq -r .channels.slack.botToken /Users/ny/.openclaw/openclaw.json) /usr/local/bin/node scripts/follower-snapshot.js >> logs/follower-snapshot.log 2>&1
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/follower-snapshot.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.follower-snapshot
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 2
	last exit code = 0

	event triggers = {
		ai.openclaw.follower-snapshot.268435587 => {
			keepalive = 0
			service = ai.openclaw.follower-snapshot
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 35
				"Hour" => 0
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x10a5e7
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 88070
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.follower-snapshot
	}

	jetsam coalition = {
		ID = 88071
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.follower-snapshot
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.gateway
```
gui/501/ai.openclaw.gateway = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.gateway.plist
	type = LaunchAgent
	state = running

	program = /Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh
	arguments = {
		/Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh
		/Users/ny/.openclaw/service-env/ai.openclaw.gateway.env
		/Users/ny/.openclaw/tools/node-v22.22.0/bin/node
		/Users/ny/.openclaw/tools/node-v22.22.<MASKED>.js
		gateway
		--port
		18789
	}

	working directory = /Users/ny/.openclaw

	stdout path = /Users/ny/.openclaw/logs/gateway.log
	stderr path = /Users/ny/.openclaw/logs/gateway.err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.gateway
	}

	domain = gui/501 [100002]
	umask = 77
	asid = 100002
	minimum runtime = 1
	exit timeout = 5
	runs = 1
	pid = 94358
	immediate reason = speculative
	forks = 20677
	execs = 3
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = (never exited)

	resource coalition = {
		ID = 34603
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.gateway
	}

	jetsam coalition = {
		ID = 34604
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.gateway
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = partial import | keepalive | runatload | inferred program
}
```

## ai.openclaw.hashtag-follow
```
gui/501/ai.openclaw.hashtag-follow = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.hashtag-follow.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/hashtag-follow.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/hashtag-follow.log
	stderr path = /Users/ny/.openclaw/workspace/logs/hashtag-follow-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /usr/local/bin:/usr/bin:/bin
		HASHTAG_FOLLOW_DAILY_CAP => 90
		XPC_SERVICE_NAME => ai.openclaw.hashtag-follow
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 0
	last exit code = (never exited)

	event triggers = {
		ai.openclaw.hashtag-follow.268435604 => {
			keepalive = 0
			service = ai.openclaw.hashtag-follow
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 15
				"Hour" => 10
			}
		}
		ai.openclaw.hashtag-follow.268435605 => {
			keepalive = 0
			service = ai.openclaw.hashtag-follow
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 17
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x0
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.import-manual-image
```
gui/501/ai.openclaw.import-manual-image = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.import-manual-image.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/import-manual-image.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/import-manual-image.out
	stderr path = /Users/ny/.openclaw/workspace/logs/import-manual-image.err
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.import-manual-image
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 360
	last exit code = 0

	resource coalition = {
		ID = 34799
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.import-manual-image
	}

	jetsam coalition = {
		ID = 34800
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.import-manual-image
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	run interval = 1800 seconds

	properties = inferred program
}
```

## ai.openclaw.incoming-reply-watcher
```
gui/501/ai.openclaw.incoming-reply-watcher = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.incoming-reply-watcher.plist
	type = LaunchAgent
	state = not running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.out
	stderr path = /Users/ny/.openclaw/workspace/logs/incoming-reply-watcher.err
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.incoming-reply-watcher
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 696
	last exit code = 0

	resource coalition = {
		ID = 35002
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.incoming-reply-watcher
	}

	jetsam coalition = {
		ID = 35003
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.incoming-reply-watcher
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	run interval = 900 seconds

	properties = inferred program
}
```

## ai.openclaw.node
```
gui/501/ai.openclaw.node = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.node.plist
	type = LaunchAgent
	state = running

	program = /Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh
	arguments = {
		/Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh
		/Users/ny/.openclaw/service-env/ai.openclaw.node.env
		/usr/local/bin/node
		/Users/ny/.<MASKED>.js
		node
		run
		--host
		127.0.0.1
		--port
		18789
	}

	stdout path = /Users/ny/.openclaw/logs/node.log
	stderr path = /Users/ny/.openclaw/logs/node.err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.node
	}

	domain = gui/501 [100002]
	umask = 77
	asid = 100002
	minimum runtime = 1
	exit timeout = 5
	runs = 1
	pid = 94364
	immediate reason = speculative
	forks = 0
	execs = 3
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = (never exited)

	resource coalition = {
		ID = 34605
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.node
	}

	jetsam coalition = {
		ID = 34606
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.node
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	job state = running

	properties = partial import | keepalive | runatload | inferred program
}
```

## ai.openclaw.seo-health
```
gui/501/ai.openclaw.seo-health = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.seo-health.plist
	type = LaunchAgent
	state = not running

	program = /bin/bash
	arguments = {
		/bin/bash
		-lc
		/opt/homebrew/bin/python3.11 /Users/ny/projects/anta-baka-x/blog/scripts/seo-health-monitor.py >> /Users/ny/.openclaw/workspace/logs/seo-health.log 2>&1
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/seo-health.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/seo-health.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.seo-health
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 0
	last exit code = (never exited)

	event triggers = {
		ai.openclaw.seo-health.268435590 => {
			keepalive = 0
			service = ai.openclaw.seo-health
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 10
				"Hour" => 8
				"Weekday" => 1
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x0
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.sitemap-autosubmit
```
gui/501/ai.openclaw.sitemap-autosubmit = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.sitemap-autosubmit.plist
	type = LaunchAgent
	state = not running

	program = /bin/bash
	arguments = {
		/bin/bash
		-lc
		/opt/homebrew/bin/python3.11 /Users/ny/projects/anta-baka-x/blog/scripts/sitemap-autosubmit.py >> /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.log 2>&1
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stdout.log
	stderr path = /Users/ny/.openclaw/workspace/logs/sitemap-autosubmit.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.sitemap-autosubmit
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 2
	last exit code = 0

	event triggers = {
		ai.openclaw.sitemap-autosubmit.268435589 => {
			keepalive = 0
			service = ai.openclaw.sitemap-autosubmit
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 40
				"Hour" => 19
			}
		}
		ai.openclaw.sitemap-autosubmit.268435588 => {
			keepalive = 0
			service = ai.openclaw.sitemap-autosubmit
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 40
				"Hour" => 7
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x10e88b
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 90523
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.sitemap-autosubmit
	}

	jetsam coalition = {
		ID = 90524
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.sitemap-autosubmit
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program
}
```

## ai.openclaw.slack-watchdog
```
gui/501/ai.openclaw.slack-watchdog = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.slack-watchdog.plist
	type = LaunchAgent
	state = running

	program = /bin/bash
	arguments = {
		/bin/bash
		/Users/ny/.openclaw/workspace/scripts/run-slack-watchdog.sh
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/slack-watchdog.log
	stderr path = /Users/ny/.openclaw/workspace/logs/slack-watchdog-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.slack-watchdog
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 1
	pid = 94377
	immediate reason = speculative
	forks = 1
	execs = 2
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = (never exited)

	resource coalition = {
		ID = 34609
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.slack-watchdog
	}

	jetsam coalition = {
		ID = 34610
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.slack-watchdog
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = keepalive | runatload | inferred program
}
```

## ai.openclaw.tab-guard
```
gui/501/ai.openclaw.tab-guard = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/ai.openclaw.tab-guard.plist
	type = LaunchAgent
	state = running

	program = /usr/local/bin/node
	arguments = {
		/usr/local/bin/node
		/Users/ny/.openclaw/workspace/scripts/tab-guard.js
		--watch
	}

	working directory = /Users/ny/.openclaw/workspace

	stdout path = /Users/ny/.openclaw/workspace/logs/tab-guard.out
	stderr path = /Users/ny/.openclaw/workspace/logs/tab-guard-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => ai.openclaw.tab-guard
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 1
	pid = 94306
	immediate reason = speculative
	forks = 21612
	execs = 1
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = (never exited)

	resource coalition = {
		ID = 34599
		type = resource
		state = active
		active count = 1
		name = ai.openclaw.tab-guard
	}

	jetsam coalition = {
		ID = 34600
		type = jetsam
		state = active
		active count = 1
		name = ai.openclaw.tab-guard
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = keepalive | runatload | inferred program
}
```

## com.dailyhack.openclaw.heartbeat
```
gui/501/com.dailyhack.openclaw.heartbeat = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.openclaw.heartbeat.plist
	type = LaunchAgent
	state = not running

	program = /Users/ny/openclaw/venv/bin/python3
	arguments = {
		/Users/ny/openclaw/venv/bin/python3
		/Users/ny/openclaw/heartbeat.py
	}

	working directory = /Users/ny/openclaw

	stdout path = /Users/ny/openclaw/heartbeat.stdout.log
	stderr path = /Users/ny/openclaw/heartbeat.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
		XPC_SERVICE_NAME => com.dailyhack.openclaw.heartbeat
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 3543
	last exit code = 0

	resource coalition = {
		ID = 965
		type = resource
		state = active
		active count = 1
		name = com.dailyhack.openclaw.heartbeat
	}

	jetsam coalition = {
		ID = 966
		type = jetsam
		state = active
		active count = 1
		name = com.dailyhack.openclaw.heartbeat
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	run interval = 300 seconds

	properties = runatload | inferred program | managed LWCR | has LWCR
}
```

## com.dailyhack.openclaw.listener
```
gui/501/com.dailyhack.openclaw.listener = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.openclaw.listener.plist
	type = LaunchAgent
	state = running

	program = /Users/ny/openclaw/venv/bin/python3
	arguments = {
		/Users/ny/openclaw/venv/bin/python3
		/Users/ny/openclaw/listener.py
	}

	working directory = /Users/ny/openclaw

	stdout path = /Users/ny/openclaw/launchd.stdout.log
	stderr path = /Users/ny/openclaw/launchd.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
		XPC_SERVICE_NAME => com.dailyhack.openclaw.listener
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 15
	exit timeout = 5
	runs = 1
	pid = 850
	immediate reason = speculative
	forks = 8
	execs = 2
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = (never exited)

	resource coalition = {
		ID = 937
		type = resource
		state = active
		active count = 1
		name = com.dailyhack.openclaw.listener
	}

	jetsam coalition = {
		ID = 938
		type = jetsam
		state = active
		active count = 1
		name = com.dailyhack.openclaw.listener
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = keepalive | runatload | inferred program | managed LWCR | has LWCR
}
```

## com.dailyhack.ops-heartbeat
```
gui/501/com.dailyhack.ops-heartbeat = {
	active count = 1
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.ops-heartbeat.plist
	type = LaunchAgent
	state = running

	program = /bin/bash
	arguments = {
		/bin/bash
		/Users/ny/projects/anta-baka-x/blog/scripts/ops-heartbeat.sh
	}

	stdout path = /Users/ny/.openclaw/workspace/logs/ops-heartbeat.log
	stderr path = /Users/ny/.openclaw/workspace/logs/ops-heartbeat-err.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
		HOME => /Users/ny
		XPC_SERVICE_NAME => com.dailyhack.ops-heartbeat
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 358
	pid = 32062
	immediate reason = interval
	forks = 16
	execs = 2
	initialized = 1
	trampolined = 1
	started suspended = 0
	proxy started suspended = 0
	checked allocations = 0 (queried = 1)
	checked allocations reason = no host
	checked allocations flags = 0x0
	last exit code = 0

	resource coalition = {
		ID = 35052
		type = resource
		state = active
		active count = 1
		name = com.dailyhack.ops-heartbeat
	}

	jetsam coalition = {
		ID = 35053
		type = jetsam
		state = active
		active count = 1
		name = com.dailyhack.ops-heartbeat
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	run interval = 1800 seconds

	properties = runatload | inferred program
}
```

## com.dailyhack.rc-keeper
```
gui/501/com.dailyhack.rc-keeper = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.rc-keeper.plist
	type = LaunchAgent
	state = not running

	program = /Users/ny/bin/dh-rc-keeper
	arguments = {
		/Users/ny/bin/dh-rc-keeper
	}

	stdout path = /Users/ny/.dh-rc-keeper.stdout.log
	stderr path = /Users/ny/.dh-rc-keeper.stderr.log
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin
		HOME => /Users/ny
		XPC_SERVICE_NAME => com.dailyhack.rc-keeper
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	nice = 5
	runs = 3543
	last exit code = 0

	resource coalition = {
		ID = 911
		type = resource
		state = active
		active count = 1
		name = com.dailyhack.rc-keeper
	}

	jetsam coalition = {
		ID = 912
		type = jetsam
		state = active
		active count = 1
		name = com.dailyhack.rc-keeper
	}

	spawn type = background (5)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default
	run interval = 300 seconds

	properties = runatload | low priority i/o | inferred program | managed LWCR
}
```

## com.dailyhack.weekly-blog-report
```
gui/501/com.dailyhack.weekly-blog-report = {
	active count = 0
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.weekly-blog-report.plist
	type = LaunchAgent
	state = not running

	program = /opt/homebrew/bin/python3.11
	arguments = {
		/opt/homebrew/bin/python3.11
		/Users/ny/scripts/weekly-blog-report.py
	}

	stdout path = /Users/ny/Library/Logs/weekly-blog-report.log
	stderr path = /Users/ny/Library/Logs/weekly-blog-report.err
	inherited environment = {
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.LWzrqsUBP4/Listeners
	}

	default environment = {
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
	}

	environment = {
		OSLogRateLimit => 64
		PATH => /opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
		XPC_SERVICE_NAME => com.dailyhack.weekly-blog-report
	}

	domain = gui/501 [100002]
	asid = 100002
	minimum runtime = 10
	exit timeout = 5
	runs = 1
	last exit code = 0

	event triggers = {
		com.dailyhack.weekly-blog-report.268435508 => {
			keepalive = 0
			service = com.dailyhack.weekly-blog-report
			stream = com.apple.launchd.calendarinterval
			monitor = com.apple.UserEventAgent-Aqua
			descriptor = {
				"Minute" => 0
				"Hour" => 8
				"Weekday" => 1
			}
		}
	}

	event channels = {
		"com.apple.launchd.calendarinterval" = {
			port = 0x12031b
			active = 0
			managed = 1
			reset = 0
			hide = 0
			watching = 1
		}
	}

	resource coalition = {
		ID = 48308
		type = resource
		state = active
		active count = 1
		name = com.dailyhack.weekly-blog-report
	}

	jetsam coalition = {
		ID = 48309
		type = jetsam
		state = active
		active count = 1
		name = com.dailyhack.weekly-blog-report
	}

	spawn type = daemon (3)
	jetsam priority = 40
	jetsam memory limit (active) = (unlimited)
	jetsam memory limit (inactive) = (unlimited)
	jetsamproperties category = daemon
	jetsam thread limit = 32
	cpumon = default

	properties = inferred program | managed LWCR | has LWCR
}
```
