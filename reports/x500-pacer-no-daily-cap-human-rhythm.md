# 1 日の上限を外し、人の動き方で散らす（2026-11-15 21:31:43 JST・$0）

## ① 間隔の決まりを置き直す
```
置いた: /Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs（16667 bytes・元は .bak.20261115-213143）
きょうの動き方: 08:43〜22:47・休憩 12:37〜13:15 / 18:20〜20:17・ふつうの日（間隔 0.95 倍）
いま: 動ける時間
tweet: 直近 30 分 0/12・直近 24 時間 0（1 日の上限なし）
like: 直近 30 分 0/10・直近 24 時間 0（1 日の上限なし）
follow: 直近 30 分 0/4・直近 24 時間 10（1 日の上限なし）
unfollow: 直近 30 分 0/6・直近 24 時間 6（1 日の上限なし）
並んでいるジョブ: なし
```

## ② ジョブごとの頭打ちを暴走よけの値に

### badge-followback
```
変える前 FOLLOWBACK_MAX_PER_RUN: 2
bootstrap rc=0 
載っている ← launchd が持っている値:
  FOLLOWBACK_MAX_PER_RUN => 25
```

### competitor-follower-follow
```
変える前 COMPETITOR_FOLLOW_DAILY_CAP: 2
bootstrap rc=0 
載っている ← launchd が持っている値:
  COMPETITOR_FOLLOW_DAILY_CAP => 20
```

### hashtag-follow
```
変える前 HASHTAG_FOLLOW_DAILY_CAP: 2
bootstrap rc=0 
載っている ← launchd が持っている値:
  HASHTAG_FOLLOW_DAILY_CAP => 20
```

### comment-warmup
```
変える前 REPLY_FOLLOW_DAILY_CAP: 6
bootstrap rc=0 
載っている ← launchd が持っている値:
  REPLY_FOLLOW_DAILY_CAP => 30
```

### follow-balance
```
変える前 MAX_UNFOLLOW: 2
bootstrap rc=0 
載っている ← launchd が持っている値:
  MIN_UNFOLLOW => 2
  MAX_UNFOLLOW => 20
```

### mutual-prune
```
変える前 MAX_UNFOLLOW: 2
bootstrap rc=0 
載っている ← launchd が持っている値:
  MAX_UNFOLLOW => 8
```

## ③ 押す係の試し運転を止める
```
bootout rc=0
plist を .disabled にした
載っていない（止まった）
試し運転の記録の行数: 17
```

**LLM 不使用（$0）。**
