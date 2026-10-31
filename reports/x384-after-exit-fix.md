# 直したあとの外す処理の結果（2026-10-31 11:35:53 JST・読むだけ・$0）

## ① reply-followers-cleanup.log の 2026-10-31T02:33Z 以降
```
行数 3
外した: 0
失敗: 3
打ち切り（timeout・ETIMEDOUT）: 2
--- 起動ごとの行
--- 最後の 8 行
[2026-10-31T02:33:35.717Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T02:35:38.277Z] @<伏せ>: unfollow exec error: spawnSync /bin/sh ETIMEDOUT
[2026-10-31T02:35:45.779Z] @<伏せ>: unfollow failed (no unfollow button)
```

## ② reply-followers.json の unfollowed_at（2026-10-31T02:33Z 以降）
```
外した 0 {} ／ まだ外す予定が残っている 214
```

## ③ 止まったままの node（30 分以上）
```
 5706          35:48 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
13303          05:48 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js
14283          00:05 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js AC_SP500
88055    01-06:32:19 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/tab-guard.js --watch
```

## ④ プロフィールのヘッダー
```
{"links":["443 フォロー中","667 フォロワー"]}
```
**読んだだけ（$0）。**
