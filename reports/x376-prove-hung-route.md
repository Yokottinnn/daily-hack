# 止まった処理が X の通信を止めているか（2026-10-30 00:55:07 JST・押さない・$0）

## ① 動いている X 系の node と、関所が付いているか
```
pid=10275 経過 02:49:43 関所=x-action-guard unfollow-handle.js
pid=19189 経過 18:55:02 関所=x-action-guard reply-followers-cleanup.js
```

## ② 終わらせる前：X の通信（15 秒）
```
{"sent":36,"done":36,"failed":0,"pending":[],"pendingCount":0}
```

## ③ 30 分以上動いている X 系の node を終わらせる
```
終わらせた: pid=10275 経過 02:50:07
終わらせた: pid=19189 経過 18:55:26
--- 残り
```

## ④ 終わらせた後：X の通信（15 秒）
```
{"sent":34,"done":34,"failed":0,"pending":[],"pendingCount":0}
```
**押していない（$0）。**
