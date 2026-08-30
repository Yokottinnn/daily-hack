# マージから実行までの実測（2026-08-31 01:14:52 JST）

> **「入れた」と「効いている」は別。** 数字で確かめる。

## 1. 待ち時間

- main へ入った時刻: `2026-08-31 00:46:39`
- 実行された時刻:   `2026-08-31 01:14:52`

### **待ち時間: 1693 秒（28 分 13 秒）**

❌ **30 分に近い。ポーラーが拾えていない。** 下の 2 章を見ること

## 2. どちらのジョブが走らせたか

- 実行者: **`ops-heartbeat`**（`OPS_PUSH` が無い）
  → ポーラーより先に heartbeat が拾ったか、**ポーラーが動いていない**

## 3. ジョブの状態

- `com.dailyhack.ops-poller`: ロード=**1** 件 / StartInterval=**60** 秒
- `com.dailyhack.ops-heartbeat`: ロード=**1** 件 / StartInterval=**1800** 秒

## 4. ポーラーのログ（末尾）

```
---
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
/bin/bash: /Users/ny/projects/anta-baka-x/blog/scripts/ops-run-tasks.sh: No such file or directory
```

**何も変更していない。読んだだけ。** LLM 呼び出しなし（$0）。
