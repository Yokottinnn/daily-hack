# 定時を待たずに確かめる（t143・**API は呼ばない・$0**）

生成: **2026-09-21T02:11:23+0900**

## 1) 鍵は読めるか

- `launchctl getenv`: ⚠️ **読めない**

## 2) どの記事を選ぶか（`--dry-run`）

```text
対象: may-2026-bank-campaigns-roundup（3001 文字 / 最終確認 未）
--dry-run のため API は呼ばない。ここで終わり。
```

- `node`: `/opt/homebrew/bin/node`（v26.0.0）

## 3) ジョブは載っているか（**`print` で見る**）

```text
	state = not running
	program = /bin/bash
	runs = 0
	last exit code = (never exited)
```

## 4) これで残るもの

- ここまで通っていれば、**05:30 に 1 本 走って PR が出る**
- 1 回あたり **約 $0.07**（推定・Sonnet 5）／ 1 日 **約 $0.07** ／ 1 か月 **約 $2.1**
- 実額は `ops/data/refresh-state.json` の `total_usd` に積まれる
