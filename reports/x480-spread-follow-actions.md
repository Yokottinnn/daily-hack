# 自動のフォロー・解除を散らす（2026-11-14 19:36:16 JST・$0）

## ① ② 間隔の決まりと起動のばらつきを置く
```
置いた: x-action-pacer.cjs
置いた: x-jitter.sh
pacer: フォロー＋解除の合算とランダムな間隔 → 入っている
tweet: 直近 30 分 0/12・間隔 60 秒・直近 24 時間 0/上限なし
like: 直近 30 分 0/10・間隔 45 秒・直近 24 時間 0/40
follow: 直近 30 分 0/4・間隔 180 秒・直近 24 時間 0/10
unfollow: 直近 30 分 0/6・間隔 120 秒・直近 24 時間 4/10
```

## ③ follow-handle.js の押す直前で『記録して待つ』
```
入れた: 262:    /* x480: 押す直前に間隔の決まりを通す（記録する）。
```

## ④ badge-followback.js の押す前に間隔待ち
```
入れた: 219:        /* x480: 押す前に間隔の決まりを通す（記録する）。空かなければこの回はここで
```

## ⑤ 1 回あたりの上限・起動のばらつき（plist）

### ai.openclaw.badge-followback
```
0:50 → 21:50 に移した
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  FOLLOWBACK_MAX_PER_RUN => 2
```

### ai.openclaw.competitor-follower-follow
```
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  COMPETITOR_FOLLOW_DAILY_CAP => 2
```

### ai.openclaw.hashtag-follow
```
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  HASHTAG_FOLLOW_DAILY_CAP => 2
```

### ai.openclaw.comment-warmup
```
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  REPLY_FOLLOW_DAILY_CAP => 6
```

### ai.openclaw.follow-balance
```
bootstrap rc=0 
載っている ← launchd が持っている値:
  /Users/ny/.openclaw/workspace/lib/x-jitter.sh
  MIN_UNFOLLOW => 2
  GRACE_DAYS => 3
  MAX_UNFOLLOW => 2
```

### ai.openclaw.mutual-prune
```
**いま走っている。触らない**（あとでやり直す）
```
