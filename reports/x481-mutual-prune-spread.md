# mutual-prune を散らす（2026-11-14 20:00:24 JST・$0）

## ① いまの状態
```
state=running pid=3033
走っている時間: 07:30:24
 3033 07:30:24 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/mutual-prune.js
[2026-11-13T10:17:00.266Z] === mutual-prune done: 0 件 外した ===
[2026-11-13T20:02:19.012Z] === mutual-prune start (dry=false max=15 inactive=30d ratio=0.2 absMin=300 grace=1d) ===
[2026-11-13T20:02:22.283Z] **自分のハンドルが読めない。何もしない。**
[2026-11-14T03:30:00.275Z] === mutual-prune start (dry=false max=15 inactive=30d ratio=0.2 absMin=300 grace=1d) ===
[2026-11-14T03:30:03.484Z] **自分のハンドルが読めない。何もしない。**
→ 450 分。固まっているとみなして、このジョブだけ止める
止まった
```

## ② 設定を入れる
```
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  GRACE_DAYS => 3
  MAX_UNFOLLOW => 2
```
