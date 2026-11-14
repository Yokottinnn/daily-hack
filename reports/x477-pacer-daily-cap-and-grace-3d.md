# 1 日の上限・深夜の停止と、外す猶予 3 日（2026-11-14 19:25:46 JST・$0）

## ① 間隔の決まり（x-action-pacer.cjs）を置き直す
```
置いた: /Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs（7698 bytes・元は .bak.20261114-192546）
tweet: 直近 30 分 0/12・間隔 60 秒・直近 24 時間 0/上限なし
like: 直近 30 分 0/10・間隔 45 秒・直近 24 時間 0/40
follow: 直近 30 分 0/4・間隔 180 秒・直近 24 時間 0/10
unfollow: 直近 30 分 0/6・間隔 120 秒・直近 24 時間 4/10
```

## ② ai.openclaw.follow-balance の GRACE_DAYS を 3 に
```
変える前: 1
bootstrap rc=0 
載っている ← launchd が持っている値:
  		GRACE_DAYS => 3
```

## ② ai.openclaw.mutual-prune の GRACE_DAYS を 3 に
```
変える前: 1
**いま走っている。触らない**（次の周回でやり直す）
```
