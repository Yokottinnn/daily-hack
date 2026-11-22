# ジョブはどのドメインに居るのか（t141）

生成: **2026-09-21T02:04:01+0900**

## 1) ドメインを名指しして見る

| ラベル | `gui/501` | `user/501` | `launchctl list` |
| --- | --- | --- | --- |
| `com.dailyhack.refresh-daily` | not | — | **出ない** |
| `com.dailyhack.ops-heartbeat` | not | — | 出る |

（`—` は そのドメインに**居ない**。値が出ていれば **`print` が通った＝載っている**）

## 2) 足りないほうに入れ直す

- 正とするドメイン: `gui/501`（`com.dailyhack.ops-heartbeat` が居るほう）
- **すでにそこに居る。** 入れ直さない

### ✅ `launchctl print gui/501/com.dailyhack.refresh-daily` が通る（state = **not**）← **これが証拠**

```text
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.refresh-daily.plist
	state = not running
	program = /bin/bash
	stdout path = /Users/ny/.openclaw/logs/refresh-daily.out.log
	stderr path = /Users/ny/.openclaw/logs/refresh-daily.err.log
	runs = 0
	last exit code = (never exited)
```

## 3) 次の実行予定

- **毎日 05:30。** `RunAtLoad` は false なので、いま走ることはない
- 鍵が無いままなら**何もせずに終わる**（t140 の通り）
