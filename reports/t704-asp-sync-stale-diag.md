# ASP の同期が止まっている理由（t704・読むだけ・$0）

生成: **2026-11-18T08:55:04+0900**

## 1) launchd の状態（launchctl print）

```
	path = /Users/ny/Library/LaunchAgents/com.dailyhack.asp-sync.plist
	state = not running
	program = /bin/bash
	stdout path = /Users/ny/.openclaw/logs/asp-sync.out.log
	stderr path = /Users/ny/.openclaw/logs/asp-sync.err.log
		SSH_AUTH_SOCK => /private/tmp/com.apple.launchd.m7lVSZ8gbC/Listeners
		PATH => /usr/bin:/bin:/usr/sbin:/sbin
		OSLogRateLimit => 64
		XPC_SERVICE_NAME => com.dailyhack.asp-sync
	runs = 9
	last exit code = 0
		com.dailyhack.asp-sync.268435508 => {
				"Minute" => 12
				"Hour" => 6
		state = active
		state = active
```

## 2) plist の時刻

```
{"Hour":6,"Minute":12}```

## 3) ログ（起動の行とエラーらしい行だけ・最後の 60 行の範囲）

ログの大きさ: 6242 bytes／最終更新: Nov 18 06:13:40 2026

```
1:=== 2026-10-12T06:12:03+0900 boot
6:=== 2026-10-18T06:12:05+0900 boot
11:=== 2026-10-19T06:12:05+0900 boot
16:=== 2026-10-20T06:12:05+0900 boot
21:=== 2026-10-21T06:12:04+0900 boot
26:=== 2026-10-22T06:12:05+0900 boot
31:=== 2026-10-23T06:12:05+0900 boot
36:=== 2026-10-24T06:12:05+0900 boot
41:=== 2026-10-25T06:12:05+0900 boot
46:=== 2026-10-26T06:12:05+0900 boot
51:=== 2026-10-27T06:12:05+0900 boot
56:=== 2026-10-28T06:12:00+0900 boot
61:=== 2026-10-29T06:12:05+0900 boot
66:=== 2026-10-30T06:12:05+0900 boot
71:=== 2026-10-31T06:12:05+0900 boot
76:=== 2026-11-01T06:12:05+0900 boot
81:=== 2026-11-02T06:12:05+0900 boot
86:=== 2026-11-03T06:12:05+0900 boot
91:=== 2026-11-04T06:12:05+0900 boot
96:=== 2026-11-05T06:12:05+0900 boot
101:=== 2026-11-06T06:12:05+0900 boot
106:=== 2026-11-07T06:12:05+0900 boot
111:=== 2026-11-08T06:12:05+0900 boot
116:=== 2026-11-09T06:12:00+0900 boot
118:fetch に失敗（続行する）
119:CDP 18810 につながらない: Error: browserType.connectOverCDP: connect EADDRNOTAVAIL 127.0.0.1:18810 - Local (0.0.0.0:0)
124:=== 2026-11-10T06:12:05+0900 boot
129:=== 2026-11-11T06:12:03+0900 boot
134:=== 2026-11-12T06:12:00+0900 boot
139:=== 2026-11-13T06:12:03+0900 boot
144:=== 2026-11-14T06:12:00+0900 boot
149:=== 2026-11-15T06:12:04+0900 boot
154:=== 2026-11-16T06:12:05+0900 boot
159:=== 2026-11-17T06:12:05+0900 boot
164:=== 2026-11-18T06:12:05+0900 boot
```

## 4) 書き出し先のファイルの時刻（push 前の作業場所）

```
total 64
drwxr-xr-x     7 ny  staff    224 Nov 18 06:32 .
drwxr-xr-x  1773 ny  staff  56736 Nov 18 08:55 ..
-rw-r--r--     1 ny  staff  10242 Nov 18 06:32 a8.md
-rw-r--r--     1 ny  staff   4011 Nov 18 06:32 moshimo.md
-rw-r--r--     1 ny  staff   3780 Nov 18 06:32 rakuten.md
-rw-r--r--     1 ny  staff   2877 Nov 18 06:32 status.json
-rw-r--r--     1 ny  staff   5581 Nov 18 06:32 vc.md
```

## 5) シム

在る（実行可）: `/Users/ny/.openclaw/bin/asp-sync-boot.sh`
