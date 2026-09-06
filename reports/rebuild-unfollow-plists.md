# 壊れた plist を作り直す（2026-09-06 21:23 JST・費用 $0）

> **2026-08-22 に plist の一部だけが JSON で書き出され、本体を上書きしていた。**
> `launchctl enable` で直らないのは当然で、**ファイルが plist ではない。**
> **当て推量で埋めない。分かったものだけ作り直す。**
> **作り直しても load しない。** 起動は次のタスクで、少数から。

## 1. 実行役 `reply-followers-cleanup.js` を読む

`scheduled_unfollow_at` を読むのはこれ。**滞留 196 件を処理する当人。**

- 95 行 / 3253 B / 更新 2026-05-13 16:00

```javascript
     1	#!/usr/bin/env node
     2	// reply-followers-cleanup.js — every 1h cron.
     3	// For each entry with scheduled_unfollow_at <= now:
     4	//   - 直前再check (master rule): if follows_us → cancel unfollow, status=yes_late
     5	//   - else → call unfollow-handle, status=unfollowed
     6	const fs = require("fs");
     7	const { execSync } = require("child_process");
     8	
     9	const STATE_PATH = "/Users/ny/.openclaw/workspace/data/reply-followers.json";
    10	const CHECK_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/check-followback.js";
    11	const UNFOLLOW_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/unfollow-handle.js";
    12	const LOG_PATH = "/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.log";
    13	
    14	function log(s) {
    15	  const line = `[${new Date().toISOString()}] ${s}\n`;
    16	  try { fs.appendFileSync(LOG_PATH, line); } catch {}
    17	  console.log(line.trim());
    18	}
    19	
    20	function loadState() {
    21	  if (!fs.existsSync(STATE_PATH)) return {};
    22	  return JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
    23	}
    24	function saveState(s) {
    25	  const tmp = STATE_PATH + ".tmp";
    26	  fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
    27	  fs.renameSync(tmp, STATE_PATH);
    28	}
    29	
    30	async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }
    31	
    32	async function main() {
    33	  const state = loadState();
    34	  const now = Date.now();
    35	
    36	  const due = [];
    37	  for (const [handle, e] of Object.entries(state)) {
    38	    if (!e.scheduled_unfollow_at) continue;
    39	    if (e.followback_status !== "no") continue;
    40	    const sat = new Date(e.scheduled_unfollow_at).getTime();
    41	    if (sat > now) continue;
    42	    due.push(handle);
    43	  }
    44	  if (due.length === 0) {
    45	    log("nothing due");
    46	    return;
    47	  }
    48	  log(`due unfollows: ${due.length} → ${due.join(",")}`);
    49	
    50	  // Master rule: 直前再check (batch)
    51	  let recheck;
    52	  try {
    53	    const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${due.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
    54	    recheck = JSON.parse(out.trim().split("\n").pop());
    55	  } catch (e) {
    56	    log(`recheck failed: ${e.message} — abort cleanup`);
    57	    return;
    58	  }
    59	
    60	  for (const r of recheck.results || []) {
    61	    const e = state[r.handle];
    62	    if (!e) continue;
    63	    if (r.follows_us === true) {
    64	      e.followback_status = "yes_late";
    65	      e.scheduled_unfollow_at = null;
    66	      e.late_followback_at = new Date().toISOString();
    67	      log(`@${r.handle}: late followback detected — unfollow cancelled (yes_late)`);
    68	      continue;
    69	    }
    70	    if (r.follows_us !== false) {
    71	      log(`@${r.handle}: recheck error, skip this cycle`);
    72	      continue;
    73	    }
    74	    // Confirmed no followback → unfollow
    75	    try {
    76	      const out = execSync(`/usr/local/bin/node ${UNFOLLOW_SCRIPT} ${r.handle}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
    77	      const uo = JSON.parse(out.trim().split("\n").pop());
    78	      if (uo.ok) {
    79	        e.followback_status = "unfollowed";
    80	        e.unfollowed_at = new Date().toISOString();
    81	        e.scheduled_unfollow_at = null;
    82	        log(`@${r.handle}: unfollowed`);
    83	      } else {
    84	        log(`@${r.handle}: unfollow failed (${uo.reason || "unknown"})`);
    85	      }
    86	    } catch (e2) {
    87	      log(`@${r.handle}: unfollow exec error: ${e2.message}`);
    88	    }
    89	    await sleep(2500);
    90	  }
    91	  saveState(state);
    92	  log("done");
    93	}
    94	
    95	main().catch(e => { log(`fatal: ${e.message}`); process.exit(1); });
```

### これを呼ぶジョブは存在するか

**存在しなければ、滞留 196 件はそもそも誰も処理していない。**

```
  呼んでいる: ai.openclaw.reply-followers-cleanup

  参考: scripts/ の中で呼んでいるもの
    reply-followers-cleanup.js
    wave-freeze.sh
    wave-freeze.sh.bak18800
```

## 2. 作り直しの材料を集める

### `follow-watchdog`

- 残っているのは: **環境変数（EnvironmentVariables）**
- `.bak` の有無: 
- 同名スクリプト: /Users/ny/.openclaw/workspace/scripts/follow-watchdog.js 無し
- ログの実行時刻（直近 5 回）:

```
    2026-08-08T00:00
    2026-08-08T12:00
    2026-08-09T00:00
    2026-08-09T12:00
    2026-08-10T00:00
```

### `unfollow-daily`

- 残っているのは: **環境変数（EnvironmentVariables）**
- `.bak` の有無: 
- 同名スクリプト: 無し
- ログの実行時刻（直近 5 回）:

```
```

### `unfollow-evening`

- 残っているのは: **環境変数（EnvironmentVariables）**
- `.bak` の有無: 
- 同名スクリプト: 無し
- ログの実行時刻（直近 5 回）:

```
```

### `unfollow-cleanup-morning`

- 残っているのは: **起動引数（ProgramArguments）**
- `.bak` の有無: 
- 同名スクリプト: 無し
- ログの実行時刻（直近 5 回）:

```
```

### `unfollow-cleanup-evening`

- 残っているのは: **起動引数（ProgramArguments）**
- `.bak` の有無: 
- 同名スクリプト: 無し
- ログの実行時刻（直近 5 回）:

```
```

### `revenge-unfollow`

- 残っているのは: **環境変数（EnvironmentVariables）**
- `.bak` の有無: 
- 同名スクリプト: /Users/ny/.openclaw/workspace/scripts/revenge-unfollow.js 無し
- ログの実行時刻（直近 5 回）:

```
```


## 3. 作り直す（**起動引数が残っている 2 本だけ**）

`unfollow-cleanup-morning` / `unfollow-cleanup-evening` は**起動引数が完全に残っている。**
実行時刻はログから取る。取れなければ**作らない。**

### `unfollow-cleanup-morning`

- 実行時刻: **8:30**（ログの時刻に合わせた）
- **作り直した**（1167 B）／壊れた版は `broken.20260906-212327/` に退避
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-morning.plist: OK

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.unfollow-cleanup-morning</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN=<MASKED>")"; cd /Users/ny/.openclaw/workspace; /Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh; MAX_PER_FIRE=3 /usr/local/bin/node scripts/unfollow-cleanup.js</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>8</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/unfollow-cleanup-morning.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/unfollow-cleanup-morning-err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

### `unfollow-cleanup-evening`

- 実行時刻: **20:30**（ログの時刻に合わせた）
- **作り直した**（1168 B）／壊れた版は `broken.20260906-212327/` に退避
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-evening.plist: OK

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.unfollow-cleanup-evening</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>eval "$(/usr/local/bin/node -e "const c=require('/Users/ny/.openclaw/openclaw.json');console.log('export SLACK_BOT_TOKEN=<MASKED>")"; cd /Users/ny/.openclaw/workspace; /Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh; MAX_PER_FIRE=2 /usr/local/bin/node scripts/unfollow-cleanup.js</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>20</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/unfollow-cleanup-evening.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/unfollow-cleanup-evening-err.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```


## 4. 残り 4 本

**起動引数が残っていないので、当て推量で作らない。**
上の 2 章に材料（`.bak` の有無・同名スクリプト・ログの時刻）を出した。
**そもそも `reply-followers-cleanup.js` を呼ぶジョブが要るのかを、1 章の結果で決める。**

## 5. いま load されているか（**触っていないことの確認**）

```
  follow-watchdog              未ロード
  unfollow-daily               未ロード
  unfollow-evening             未ロード
  unfollow-cleanup-morning     未ロード
  unfollow-cleanup-evening     未ロード
  revenge-unfollow             未ロード
```

---

**アンフォローしていない。作り直した plist も load していない（$0）。**
**起動は次のタスクで、少数から。いきなり 196 件を外さない。**
