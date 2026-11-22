# フォロー先の上限を相手のフォロワー 4,999 人に（2026-11-21 23:26:21 JST・$0）

## ① follow-handle.js
```
書き換えた（元は .bak-x531）
102:  const maxFollowers = Number(process.env.FOLLOW_MAX_FOLLOWERS || 50000); // 2026-11-21 x531: フォロー返しの率が低い大きいアカウントを外す
103:  if (follower_count < minFollowers || follower_count > maxFollowers) {
104:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-${maxFollowers})`, phase };
```

## ② plist に FOLLOW_MAX_FOLLOWERS=4999

### competitor-follower-follow
```
載っている ← launchd が持っている値:
  FOLLOW_MIN_RATIO => 0.7
  FOLLOW_MAX_FOLLOWERS => 4999
  COMPETITOR_FOLLOW_DAILY_CAP => 20
```

### hashtag-follow
```
載っている ← launchd が持っている値:
  FOLLOW_MIN_RATIO => 0.7
  HASHTAG_FOLLOW_DAILY_CAP => 20
  FOLLOW_MAX_FOLLOWERS => 4999
```

**誰もフォローしていない（次の周回から効く）。LLM 不使用（$0）。**
