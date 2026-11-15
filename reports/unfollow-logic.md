# アンフォローの本体はどれか（2026-09-05 21:52:23 JST・費用 $0）

> 8 本のうち **2 本は動いている**。`reply-followback-check` が
> 「フォロバ無し → 外す」の本体なら、**失敗している 6 本は直さなくてよい。**
> **推測で「満たしています」と言わない。先に読む。**
> **書き換えない。フォローもアンフォローもしない。**

## 1. `reply-followback-check.js` 全文

- 84 行 / 更新 2026-08-02 20:31

```javascript
     1	#!/usr/bin/env node
     2	// reply-followback-check.js — every 12h cron.
     3	// For each reply-followers entry with followback_status="pending" AND followed_at + 24h <= now:
     4	//   - call check-followback for that handle
     5	//   - if follows_us: set status="yes", scheduled_unfollow_at=null (keep)
     6	//   - else: set status="no", scheduled_unfollow_at = followed_at + random(7-14日)
     7	const fs = require("fs");
     8	const { execSync } = require("child_process");
     9	
    10	const STATE_PATH = "/Users/ny/.openclaw/workspace/data/reply-followers.json";
    11	const CHECK_SCRIPT = "/Users/ny/.openclaw/workspace/scripts/check-followback.js";
    12	const LOG_PATH = "/Users/ny/.openclaw/workspace/logs/reply-followback-check.log";
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
    30	async function main() {
    31	  const state = loadState();
    32	  const now = Date.now();
    33	  const FORTY_EIGHT_H = 24 * 3600 * 1000;  // 2026-08-02 24h 短縮 (user 命令)
    34	  const SEVEN_DAYS_MS = 7 * 86400 * 1000;
    35	  const FOURTEEN_DAYS_MS = 14 * 86400 * 1000;
    36	
    37	  const toCheck = [];
    38	  for (const [handle, e] of Object.entries(state)) {
    39	    if (e.followback_status !== "pending") continue;
    40	    const fa = new Date(e.followed_at).getTime();
    41	    if (now - fa < FORTY_EIGHT_H) continue;
    42	    toCheck.push(handle);
    43	  }
    44	  if (toCheck.length === 0) {
    45	    log("nothing to check (no entries 24h+ pending)");
    46	    return;
    47	  }
    48	  log(`checking ${toCheck.length} handles: ${toCheck.join(",")}`);
    49	
    50	  const BATCH = 5;
    51	  for (let i = 0; i < toCheck.length; i += BATCH) {
    52	    const batch = toCheck.slice(i, i + BATCH);
    53	    let res;
    54	    try {
    55	      const out = execSync(`/usr/local/bin/node ${CHECK_SCRIPT} ${batch.join(" ")}`, { encoding: "utf8", maxBuffer: 8 * 1024 * 1024 });
    56	      res = JSON.parse(out.trim().split("\n").pop());
    57	    } catch (e) {
    58	      log(`batch [${batch.join(",")}] failed: ${e.message}`);
    59	      continue;
    60	    }
    61	    for (const r of res.results || []) {
    62	      const e = state[r.handle];
    63	      if (!e) continue;
    64	      e.followback_judgment_at = new Date().toISOString();
    65	      if (r.follows_us === true) {
    66	        e.followback_status = "yes";
    67	        e.scheduled_unfollow_at = null;
    68	        log(`@${r.handle}: yes (keep)`);
    69	      } else if (r.follows_us === false) {
    70	        e.followback_status = "no";
    71	        const delay = SEVEN_DAYS_MS + Math.random() * (FOURTEEN_DAYS_MS - SEVEN_DAYS_MS);
    72	        const fa = new Date(e.followed_at).getTime();
    73	        e.scheduled_unfollow_at = new Date(fa + delay).toISOString();
    74	        log(`@${r.handle}: no, scheduled_unfollow_at=${e.scheduled_unfollow_at}`);
    75	      } else {
    76	        log(`@${r.handle}: error (${r.error || "unknown"}), retry next cycle`);
    77	      }
    78	    }
    79	  }
    80	  saveState(state);
    81	  log("done");
    82	}
    83	
    84	main().catch(e => { log(`fatal: ${e.message}`); process.exit(1); });
```

### **実際に unfollow しているか**（判定の要）

```
unfollow らしき語: あり
5://   - if follows_us: set status="yes", scheduled_unfollow_at=null (keep)
6://   - else: set status="no", scheduled_unfollow_at = followed_at + random(7-14日)
67:        e.scheduled_unfollow_at = null;
73:        e.scheduled_unfollow_at = new Date(fa + delay).toISOString();
74:        log(`@${r.handle}: no, scheduled_unfollow_at=${e.scheduled_unfollow_at}`);
```

## 2. `auto-detect-and-unfollow-inactive` の判定部分

- スクリプトを特定できない

## 3. 失敗している 6 本は何を叩く設定か（**機能が重複していないか**）

```
follow-watchdog                        （不明）
unfollow-daily                         （不明）
unfollow-evening                       （不明）
unfollow-cleanup-morning               （不明）
unfollow-cleanup-evening               （不明）
revenge-unfollow                       （不明）
```

## 4. 実際にアンフォローした形跡（ログ）

### `auto-detect-and-unfollow-inactive-err.log` — 最終更新 **08-23 22:30** / 0 行

```
```

### `auto-detect-and-unfollow-inactive.log` — 最終更新 **08-30 22:30** / 248 行

```
 7. americangirl402      → https://x.com/mericangirl402
 8. money_yossy          → https://x.com/oney_yossy
 9. 422200               → https://x.com/22200
10. R80455959            → https://x.com/80455959

⏭️  After noting dates, update followed.json using:
   node update_activity_manual.js

✅ No inactive accounts detected.

```

### `revenge-unfollow-err.log` — 最終更新 **07-12 13:00** / 1 行

```
ensure-chrome: login-mode-guard active, skip launch
```

### `revenge-unfollow.log` — 最終更新 **08-09 13:00** / 101 行

```
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
{"ok":false,"error":"CDP browserType.connectOverCDP: Timeout 15000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <w
[whitelist] skip @<伏せ>
{"ok":true,"checked":2,"revenge_unfollowed":0,"still_mutual":1,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":["okazusan1"],"ghostSkipped":[],"che
[whitelist] skip @<伏せ>
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
[whitelist] skip @<伏せ>
{"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
```

### `unfollow-cleanup-evening-err.log` — 最終更新 **08-09 20:31** / 175 行

```
[unfollow-cleanup] 2026-08-09T11:30:05.622Z whitelist size: 12
[unfollow-cleanup] 2026-08-09T11:30:05.789Z Chrome tabs: 4
[unfollow-cleanup] 2026-08-09T11:30:05.857Z scraping /following...
[unfollow-cleanup] 2026-08-09T11:30:47.492Z scraped 172 handles
[unfollow-cleanup] 2026-08-09T11:30:47.542Z tier: T1=15 T2=58 T3=73 T4=26
[unfollow-cleanup] 2026-08-09T11:30:47.542Z candidates (2): mocaketu, gSkTl8nNVU89471
[unfollow-cleanup] 2026-08-09T11:30:47.542Z unfollowing @<伏せ> (bio: "フォロー中 ウクレレばかり弾いてるカリンバ沼民2022年6月からカリンバ�
[unfollow-cleanup] 2026-08-09T11:30:54.219Z   OK
[unfollow-cleanup] 2026-08-09T11:31:04.884Z unfollowing @<伏せ> (bio: "フォローされています フォロー中 フォロバ100")
[unfollow-cleanup] 2026-08-09T11:31:11.656Z   OK
```

### `unfollow-cleanup-evening.log` — 最終更新 **08-06 20:30** / 13 行

```
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
```

### `unfollow-cleanup-morning-err.log` — 最終更新 **08-10 09:31** / 215 行

```
[unfollow-cleanup] 2026-08-10T00:30:08.328Z scraping /following...
[unfollow-cleanup] 2026-08-10T00:30:49.380Z scraped 172 handles
[unfollow-cleanup] 2026-08-10T00:30:49.415Z tier: T1=13 T2=59 T3=74 T4=26
[unfollow-cleanup] 2026-08-10T00:30:49.415Z candidates (3): tatantan_abc, DfcAbc11052, as030376
[unfollow-cleanup] 2026-08-10T00:30:49.415Z unfollowing @<伏せ> (bio: "フォロー中 懸賞応募中 写真好き ディズニー大好き 当選報告は写真�
[unfollow-cleanup] 2026-08-10T00:30:55.992Z   OK
[unfollow-cleanup] 2026-08-10T00:31:10.683Z unfollowing @<伏せ> (bio: "フォロー中 ブロスタ/モンスト/バウンティ やってます。たまにネタツ
[unfollow-cleanup] 2026-08-10T00:31:17.283Z   OK
[unfollow-cleanup] 2026-08-10T00:31:28.792Z unfollowing @<伏せ> (bio: "フォロー中 元業界最大手です！仲介もしてます！フォロバ100%です！フ�
[unfollow-cleanup] 2026-08-10T00:31:35.366Z   OK
```

### `unfollow-cleanup-morning.log` — 最終更新 **08-06 09:30** / 12 行

```
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
{"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
```

### `unfollow-daily-err.log` — 最終更新 **07-12 14:00** / 2 行

```
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
```

### `unfollow-daily.log` — 最終更新 **08-10 09:00** / 234 行

```
{"ok":true,"total_candidates":1,"unfollowed":["okane_kyukyu"],"ghosts":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":3,"unfollowed":["kabu_world_map","tanoc_happy"],"ghosts":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":3,"unfollowed":[],"cancelled":["aichikyu369","abi_41_official","hitsujimaru_ai"],"ghosts":[],"failed":[]}
```

### `unfollow-evening-err.log` — 最終更新 **07-12 22:00** / 3 行

```
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
ensure-chrome: login-mode-guard active, skip launch
```

### `unfollow-evening.log` — 最終更新 **08-09 22:00** / 232 行

```
{"ok":true,"total_candidates":19,"unfollowed":[],"cancelled":[],"ghosts":["cony30175146","gSkTl8nNVU89471","xwGiEzSE9","DwacHXEg55","NyEkrFlE8","sinonon882211","lis171322
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
[unfollow] WHITELIST skip @<伏せ>
[unfollow] WHITELIST skip @<伏せ>
{"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
```

### `unfollow-stats-monitor.log` — 最終更新 **08-10 09:30** / 926 行

```
  "ok": true,
  "alerts": [],
  "stats": {
    "runs_inspected": 7,
    "sumUnfollowed": 3,
    "sumCancelled": 5,
    "sumFailed": 0,
    "failRatio": "0.00"
  }
}
```

### `unfollow-stats-monitor.stderr.log` — 最終更新 **05-24 09:30** / 0 行

```
```

### `unfollow-stats-monitor.stdout.log` — 最終更新 **05-24 09:30** / 0 行

```
```

### `x-follower-unfollow-err.log` — 最終更新 **05-09 22:00** / 0 行

```
```

### `x-follower-unfollow.log` — 最終更新 **05-09 22:00** / 0 行

```
```

### `badge-followback.log` — 最終更新 **08-30 00:50** / 301 行

```
followed back @<伏せ>
[2026-08-28T15:50:42.876Z] followed back @<伏せ>
followed back @<伏せ>
{"ok":true,"scanned":214,"verified":68,"followed_back":2,"handles":["NV_ShogoTakino","xuwhky"]}
[silence-enforce] this script kind=badge-followback-error is silent, slack HTTP calls suppressed
[2026-08-29T15:50:35.898Z] scanned=215 verified=67 new_candidates=1 DRY_RUN=false BASELINE_ONLY=false
scanned=215 verified=67 new_candidates=1 DRY_RUN=false BASELINE_ONLY=false
[2026-08-29T15:50:39.195Z] followed back @<伏せ>
followed back @<伏せ>
{"ok":true,"scanned":215,"verified":67,"followed_back":1,"handles":["oyadani7799"]}
```

### `badge-followback.stderr.log` — 最終更新 **06-08 00:50** / 0 行

```
```

### `badge-followback.stdout.log` — 最終更新 **06-08 00:50** / 0 行

```
```

### `reply-followback-check.log` — 最終更新 **09-05 19:10** / 816 行

```
[2026-09-05T10:10:23.429Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-06T15:55:02.976Z
[2026-09-05T10:10:23.429Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-11T23:51:48.192Z
[2026-09-05T10:10:23.429Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-13T13:59:29.262Z
[2026-09-05T10:10:23.429Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-14T02:31:51.884Z
[2026-09-05T10:10:36.476Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-11T13:34:14.524Z
[2026-09-05T10:10:36.477Z] @<伏せ>: yes (keep)
[2026-09-05T10:10:36.477Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-10T22:09:18.692Z
[2026-09-05T10:10:36.477Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-16T09:10:30.757Z
[2026-09-05T10:10:36.477Z] @<伏せ>: no, scheduled_unfollow_at=2026-09-15T12:21:56.424Z
[2026-09-05T10:10:36.480Z] done
```

### `fire-watchdog-err.log` — 最終更新 **07-06 19:56** / 30 行

```
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
SLACK_BOT_TOKEN missing
```

### `fire-watchdog.log` — 最終更新 **08-10 09:28** / 2850 行

```
alert sent for 1 missed fires
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
OK: all expected fires in last 60min confirmed
alert sent for 1 missed fires
OK: all expected fires in last 60min confirmed
alert sent for 1 missed fires
OK: all expected fires in last 60min confirmed
```

### `follow-watchdog-err.log` — 最終更新 **08-06 21:05** / 35 行

```
  - <ws connected> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf

falling back to cached success (4141min old)
trend-detect main failed: browserType.connectOverCDP: Timeout 8000ms exceeded.
Call log:
  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800
  - <ws connecting> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf
  - <ws connected> ws://127.0.0.1:18800/devtools/browser/01b57623-a205-4dca-9035-f3373632eedf

falling back to cached success (4861min old)
```

### `follow-watchdog.log` — 最終更新 **08-10 09:00** / 326 行

```
  },
  "src24": {
    "badge-followback": 2
  },
  "src72": {
    "cron-poikatsu-follow": 19,
    "badge-followback": 6
  },
  "reasons": []
}
```

### `slack-watchdog-err.log` — 最終更新 **05-11 02:06** / 0 行

```
```

### `slack-watchdog.log` — 最終更新 **08-30 23:12** / 13724 行

```
[2026-08-30T14:11:47.829Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:11:47.829Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:11:52.836Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:11:52.836Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:11:57.847Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:11:57.847Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:12:02.854Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:12:02.854Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:12:07.863Z] ERROR: getaddrinfo ENOTFOUND slack.com
[2026-08-30T14:12:07.863Z] ERROR: getaddrinfo ENOTFOUND slack.com
```

### `v3-violation-watchdog.log` — 最終更新 **08-10 06:28** / 331 行

```
[2026-08-07T12:33:59.616Z] Slack alert sent
[2026-08-07T15:49:49.505Z] no violations detected
[2026-08-07T21:49:49.654Z] no violations detected
[2026-08-08T03:49:50.455Z] no violations detected
[2026-08-08T09:49:50.627Z] no violations detected
[2026-08-08T15:49:50.924Z] no violations detected
[2026-08-08T21:49:51.065Z] no violations detected
[2026-08-09T03:49:51.201Z] no violations detected
[2026-08-09T15:28:14.539Z] no violations detected
[2026-08-09T21:28:14.714Z] no violations detected
```


## 5. 状態ファイルにアンフォローの記録があるか

```
unfollow-cleanup-state.json: unfollow を含む行 43 / 更新 08-10 09:31
unfollow-whitelist.json: unfollow を含む行 1 / 更新 07-19 23:06
unfollow_batch.json: unfollow を含む行 0
0 / 更新 05-09 01:15
reply-followers.json: unfollow を含む行 365 / 更新 09-05 19:10
followed.json: unfollow を含む行 272 / 更新 08-30 00:50
```

---

**何も変えていない（$0）。** 1 で unfollow の実行コードが見つかれば **6 本は不要**。
見つからなければ、3 の一覧からどれが本体かを決めて直す。
