# マージから実行までの実測（2026-08-31 01:19:58 JST）

> **「入れた」と「効いている」は別。** 数字で確かめる。

## 1. 待ち時間

- main へ入った時刻: `2026-08-31 01:19:12`
- 実行された時刻:   `2026-08-31 01:19:58`

### **待ち時間: 46 秒（0 分 46 秒）**

✅ **90 秒以内。ポーラーが効いている。**（前は最大 1,800 秒）

## 2. どちらのジョブが走らせたか

- 実行者: **`ops-poller`**（`OPS_PUSH=1` が付いている）

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
