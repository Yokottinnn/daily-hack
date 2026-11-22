# ai.openclaw.* をまとめて外しているのは誰か（2026-11-05 22:51 JST・読むだけ・$0）

## 1. 外す処理を持つスクリプトの、launchctl を呼ぶ行
```
--- tab-guard.js
69:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
--- daily-supervisor.sh
37:snapshot() { launchctl list 2>/dev/null | awk '{print $3}'; }
38:is_loaded() { printf '%s\n' "$1" | grep -qxF "ai.openclaw.$2"; }
43:# 完璧ではないが、`launchctl list` に出ることより遥かに実態に近い。
82:    [ -f "$LA/ai.openclaw.$j.plist" ] || continue
83:    launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
85:    launchctl bootstrap "gui/${UID_NUM}" "$LA/ai.openclaw.$j.plist" >/dev/null 2>&1 || true
93:    launchctl bootout "gui/${UID_NUM}/$u" >/dev/null 2>&1 || true
95:    launchctl bootstrap "gui/${UID_NUM}" "$LA/$u.plist" >/dev/null 2>&1 || true
--- wave-freeze.sh
62:      if launchctl bootout "gui/$UID_VAL/$label" 2>/dev/null; then
105:        if launchctl bootstrap "gui/$UID_VAL" "$plist_path" 2>/dev/null; then
120:    loaded=$(launchctl list | grep -c "ai.openclaw" || true)
--- emergency-stop-llm.sh
13:  PLIST=~/Library/LaunchAgents/ai.openclaw.$j.plist
15:    launchctl unload "$PLIST" 2>/dev/null || true
--- fire-watchdog.js
40:  const files = fs.readdirSync(PLIST_DIR).filter(f => f.startsWith("ai.openclaw.") && f.endsWith(".plist"));
169:    `\n\n要対応: \`launchctl print gui/$(id -u)/<label>\` で event triggers 確認、欠けてたら \`launchctl bootout gui/$(id -u)/<label> && launchctl bootstrap gui/$(id -u) ~/Library/Laun
--- auto-reply.js
171:        require("child_process").execSync("launchctl bootout gui/501 ~/Library/LaunchAgents/ai.openclaw.comment-warmup.plist", { stdio: "ignore" });
173:      await slackPost(`<@${OWNER_USER_ID}> 🛑 auto-reply 5連続 fail → comment-warmup 自動停止 (last reason: ${streak.last_reason})\n復旧: 原因調査 + \`launchctl bootstrap ~/Library
--- space-approved-posts.js
129:      execSync(`launchctl bootout gui/$(id -u)/${label}`, { stdio: "ignore" });
132:      execSync(`launchctl bootstrap gui/$(id -u) "${plistPath}"`, { stdio: "ignore" });
```

## 2. 朝 4〜5 時台と夜に動くように設定されたジョブ（plist の StartCalendarInterval）
```
ai.openclaw.auto-detect-and-unfollow-inactive: [{"Hour":22,"Minute":30}]
ai.openclaw.badge-followback: [{"Hour":0,"Minute":50},{"Hour":8,"Minute":50},{"Hour":16,"Minute":20}]
ai.openclaw.comment-warmup: [{"Hour":8,"Minute":0},{"Hour":10,"Minute":0},{"Hour":12,"Minute":0},{"Hour":16,"Minute":0},{"Hour":19,"Minute":0},{"Hou
ai.openclaw.cookie-backup: [{"Hour":4,"Minute":0},{"Hour":10,"Minute":0},{"Hour":16,"Minute":0},{"Hour":22,"Minute":0}]
ai.openclaw.daily-supervisor: [{"Hour":5,"Minute":0},{"Hour":17,"Minute":0}]
ai.openclaw.refollow-may18-once: [{"Day":20,"Hour":21,"Minute":0},{"Day":21,"Hour":9,"Minute":0}]
ai.openclaw.reply-followers-cleanup: [{"Hour":2,"Minute":0},{"Hour":3,"Minute":0},{"Hour":4,"Minute":0},{"Hour":5,"Minute":0},{"Hour":6,"Minute":0},{"Hour":7
com.dailyhack.refresh-daily: {"Hour":5,"Minute":30}
```

## 3. 外れた時間帯に、外す系の言葉が出たログ
```
--- competitor-follower-follow.log
[2026-11-03T20:01:43.180Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-03T20:02:21.167Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-03T20:02:59.811Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-03T20:03:50.140Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
--- daily-supervisor.log
[2026-10-28T20:30:19Z] 全部 走った
[2026-10-29T20:03:26Z] 全部 走った
[2026-10-29T20:16:18Z] 全部 走った
[2026-11-02T13:29:24Z] 全部 走った
[2026-11-03T20:04:05Z] 全部 走った
[2026-11-03T20:47:45Z] 全部 走った
--- tab-guard.log
[2026-11-02T13:08:24.652Z] 🚨 Jordan のタブが 22 → 6 枚（一括破壊） → 自動化を全停止
[2026-11-02T13:08:25.042Z] 停止完了
[2026-11-03T20:05:13.197Z] 🚨 Jordan のタブが 23 → 9 枚（一括破壊） → 自動化を全停止
[2026-11-03T20:05:13.823Z] 停止完了
[2026-11-03T20:18:45.693Z] 🚨 Jordan のタブが 9 → 1 枚（一括破壊） → 自動化を全停止
[2026-11-03T20:18:46.012Z] 停止完了
```

## 4. tab-guard の止める仕組み（lock の有無・最近の記録）
```
--- tab-guard.log（最後の 5 行）
[2026-11-03T20:05:13.995Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-03T20:18:45.693Z] 🚨 Jordan のタブが 9 → 1 枚（一括破壊） → 自動化を全停止
[2026-11-03T20:18:46.012Z] 停止完了
[2026-11-03T20:18:46.013Z] 監視終了（要因を確認してください）
[2026-11-03T20:18:46.058Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
--- daily-supervisor.log（最後の 5 行）
[2026-11-04T20:03:53Z] 全部 走った
[2026-11-04T20:03:53Z] === daily-supervisor done ===
[2026-11-05T08:00:05Z] === daily-supervisor start ===
[2026-11-05T08:00:15Z] 全部 走った
[2026-11-05T08:00:15Z] === daily-supervisor done ===
--- fire-watchdog.log（最後の 5 行）
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
alert sent for 1 missed fires
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
```
