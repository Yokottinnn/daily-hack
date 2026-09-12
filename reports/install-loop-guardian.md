# 3 ループを止めない番人を置く

**このレポートが作られた時刻: 2026-09-12 22:21:20 JST**

> **返信・フォロー・アンフォローが最重要。絶対に止めない体制を作る。**

**番人は治すために壊さない。** `chrome-cdp-heal` は「治す」ために Chrome を
5 分おきに kill し、利用者のブラウザを壊し、tab-guard に全停止させた。
**同じ轍は踏まない。**

## 1. 番人スクリプトを置く

```
  置いた: /Users/ny/.openclaw/workspace/scripts/x-loop-guardian.sh
  114 行
  bash -n: OK
```

## 2. launchd に載せる（15 分ごと・`KeepAlive` 付き）

**番人自身が死んでも launchd が起こす。**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>ai.openclaw.x-loop-guardian</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/ny/.openclaw/workspace/scripts/x-loop-guardian.sh</string>
  </array>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/Users/ny/.openclaw/workspace/logs/x-loop-guardian.out</string>
  <key>StandardErrorPath</key><string>/Users/ny/.openclaw/workspace/logs/x-loop-guardian.err</string>
  <key>WorkingDirectory</key><string>/Users/ny/.openclaw/workspace</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>/Users/ny</string>
  </dict>
</dict>
</plist>
```

```
  plutil -lint: OK
  **ロードした**
```

## 3. その場で 1 回 走らせる（**待たない**）

```
  (rc=0)

  --- 番人のログ ---
    [2026-09-12T22:21:20] reloaded hashtag-follow
    [2026-09-12T22:21:20] reloaded hashtag-follow
    [2026-09-12T22:21:20] reloaded badge-followback
    [2026-09-12T22:21:20] reloaded badge-followback
    [2026-09-12T22:21:20] reloaded reply-followback-check
    [2026-09-12T22:21:20] reloaded reply-followback-check
    [2026-09-12T22:21:20] reloaded reply-followers-cleanup
    [2026-09-12T22:21:20] reloaded reply-followers-cleanup
    [2026-09-12T22:21:20] reloaded incoming-reply-watcher
    [2026-09-12T22:21:20] reloaded incoming-reply-watcher
    [2026-09-12T22:21:20] reloaded pipeline-heartbeat
    [2026-09-12T22:21:20] reloaded pipeline-heartbeat
    [2026-09-12T22:21:20] login lock present, chrome running, fresh (0h) — leaving it
    [2026-09-12T22:21:20] login lock present, chrome running, fresh (0h) — leaving it
    [2026-09-12T22:21:28] unresolved: cdp-unhealthy (consecutive=1)
```

## 4. いま 3 ループは戻ったか

```
  **未ロード** comment-warmup                      
  **未ロード** competitor-follower-follow          
  **未ロード** hashtag-follow                      
  **未ロード** badge-followback                    
  **未ロード** reply-followback-check              
  **未ロード** reply-followers-cleanup             
  **未ロード** incoming-reply-watcher              
  **未ロード** pipeline-heartbeat                  

  ロード済み: 0 / 8
  番人:       0 本

  --- CDP ---
  {"ok":false,"healthy":false,"reason":"port_closed","detail":"Chrome not running","port":18810}

  --- login ロック ---
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x28-install-loop-guardian.sh: line 287: LOCK: unbound variable
