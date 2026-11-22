# 週次ジョブ board-weekly を launchd から走らせる（t282・**$0**）

生成: **2026-10-12T18:40:59+0900**

```text
kickstart rc=0
	state = running
	runs = 1
	pid = 84378
	last exit code = (never exited)
		state = active
		state = active
--- board-weekly.log（末尾 5 行）
=== 2026-10-12T12:35:32+0900 boot
=== 2026-10-12T18:40:59+0900 boot
```

結果は 10 分ほどで `reports/board/mac-weekly-status.json` に出る（heartbeat が push する）。
