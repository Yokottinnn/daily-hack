# plist の忠実な再生（2026-08-22T17:09:25Z）

原本は `launchctl-dump.md` に丸ごと残した。

## ai.openclaw.auto-detect-and-unfollow-inactive
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/auto_detect_and_unfollow_inactive.js
- 環境変数: PATH=/usr/local/bin:/usr/bin:/bin
- 発火: 22:30
- 現行 plist は既に正常。触らない。
## ai.openclaw.auto-thread-chainifier
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/auto-thread-chainifier.js
- 環境変数: PATH=/usr/local/bin:/usr/bin:/bin
- 発火: 02:00
- 現行 plist は既に正常。触らない。
## ai.openclaw.badge-followback
- 実行: /bin/bash -lc
- 環境変数: なし
- 発火: 00:50
- **書き戻した**（元は .broken.20260822-170925 へ退避）
## ai.openclaw.comment-warmup
- 実行: /bin/bash /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
- 環境変数: MIN_LIKES=2, MAX_AGE_HOURS=18, REPLY_FOLLOW_DAILY_CAP=30, MAX_PICKS_PER_FIRE=2
- 発火: 16:00 / 12:00 / 22:00 / 19:00
- **書き戻した**（元は .broken.20260822-170925 へ退避）
## ai.openclaw.competitor-follower-follow
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js
- 環境変数: PATH=/usr/local/bin:/usr/bin:/bin, COMPETITOR_FOLLOW_DAILY_CAP=5
- 発火: 18:30 / 11:30
- 現行 plist は既に正常。触らない。
## ai.openclaw.follower-snapshot
- 実行: /bin/bash -lc
- 環境変数: なし
- 発火: 00:35
- 現行 plist は既に正常。触らない。
## ai.openclaw.gateway
- 実行: /Users/ny/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh /Users/ny/.openclaw/service-env/ai.openclaw.gateway.env
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## ai.openclaw.hashtag-follow
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/hashtag-follow.js
- 環境変数: PATH=/usr/local/bin:/usr/bin:/bin, HASHTAG_FOLLOW_DAILY_CAP=90
- 発火: 10:15 / 17:00
- 現行 plist は既に正常。触らない。
## ai.openclaw.import-manual-image
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/import-manual-image.js
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## ai.openclaw.incoming-reply-watcher
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## ai.openclaw.node
- 実行: /Users/ny/.openclaw/service-env/ai.openclaw.node-env-wrapper.sh /Users/ny/.openclaw/service-env/ai.openclaw.node.env
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## ai.openclaw.seo-health
- 実行: /bin/bash -lc
- 環境変数: なし
- 発火: 08:10
- 現行 plist は既に正常。触らない。
## ai.openclaw.sitemap-autosubmit
- 実行: /bin/bash -lc
- 環境変数: なし
- 発火: 19:40 / 07:40
- 現行 plist は既に正常。触らない。
## ai.openclaw.slack-watchdog
- 実行: /bin/bash /Users/ny/.openclaw/workspace/scripts/run-slack-watchdog.sh
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## ai.openclaw.tab-guard
- 実行: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/tab-guard.js
- 環境変数: なし
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## com.dailyhack.openclaw.heartbeat
- 実行: /Users/ny/openclaw/venv/bin/python3 /Users/ny/openclaw/heartbeat.py
- 環境変数: PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## com.dailyhack.openclaw.listener
- 実行: /Users/ny/openclaw/venv/bin/python3 /Users/ny/openclaw/listener.py
- 環境変数: PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## com.dailyhack.ops-heartbeat
- 実行: /bin/bash /Users/ny/projects/anta-baka-x/blog/scripts/ops-heartbeat.sh
- 環境変数: PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## com.dailyhack.rc-keeper
- 実行: /Users/ny/bin/dh-rc-keeper
- 環境変数: PATH=/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin
- 発火: **カレンダー無し（常駐 or 間隔起動）**
- 現行 plist は既に正常。触らない。
## com.dailyhack.weekly-blog-report
- 実行: /opt/homebrew/bin/python3.11 /Users/ny/scripts/weekly-blog-report.py
- 環境変数: PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
- 発火: 08:00
- 現行 plist は既に正常。触らない。

## 結果

ai.openclaw.auto-detect-and-unfollow-inactive    plist 正常
ai.openclaw.auto-thread-chainifier               plist 正常
ai.openclaw.badge-followback                     plist 正常
ai.openclaw.comment-warmup                       plist 正常
ai.openclaw.competitor-follower-follow           plist 正常
ai.openclaw.follower-snapshot                    plist 正常
ai.openclaw.gateway                              plist 正常
ai.openclaw.hashtag-follow                       plist 正常
ai.openclaw.import-manual-image                  plist 正常
ai.openclaw.incoming-reply-watcher               plist 正常
ai.openclaw.node                                 plist 正常
ai.openclaw.seo-health                           plist 正常
ai.openclaw.sitemap-autosubmit                   plist 正常
ai.openclaw.slack-watchdog                       plist 正常
ai.openclaw.tab-guard                            plist 正常
com.dailyhack.openclaw.heartbeat                 plist 正常
com.dailyhack.openclaw.listener                  plist 正常
com.dailyhack.ops-heartbeat                      plist 正常
com.dailyhack.rc-keeper                          plist 正常
com.dailyhack.weekly-blog-report                 plist 正常

正常 20 件 / 壊れたまま 0 件

> **未ロードのジョブは触っていない。** メモリに設定が無く忠実に再生できないため。
