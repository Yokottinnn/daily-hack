# ブラックフライデーまとめが出たか（2026-11-19 12:27:00 JST・読むだけ・$0）

## キュー
```
status=posted x_tweet_id=2123252148729450700 posted_at=2026-11-19T03:09:26.091Z scheduled_at=2026-11-19T03:08:00.000Z
last_result={"ok":true,"step":null,"error":""}
  [1] x_tweet_id=2123252148729450700
  [2] x_tweet_id=2123252267986116700
```

## ジョブ
```
載っていない（走り終えて自分を外したか、最初から載っていない）
-rw-r--r--  1 ny  staff  851 Nov 15 23:42 /Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-matome-oneshot.plist
```

## ログ（末尾 40 行）
```
--- publish-bf-matome-oneshot.log
[2026-11-19 12:08:05] start
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[post-via-playwright] alt set for image 1 (172 chars)
[post-via-playwright] alt set for image 2 (289 chars)
[post-via-playwright] alt set for image 3 (217 chars)
[post-via-playwright] alt set for image 4 (103 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=6894ms
[step] find-reply-textarea t=13201ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=14947ms
[step] type-text t=14947ms
[x154] like 付いた
[step] arm-response-listener t=19269ms
[step] submit t=19271ms
[step] wait-response-or-confirm t=19368ms
[step] wait-textarea-clear t=19729ms
{"ok":true,"tweet_id":"2123252148729450700","url":"https://x.com/heng_ji31590/status/2123252148729450700","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2123252148729450700","url":"https://x.com/heng_ji31590/status/2123252148729450700","image_attached":true,"captur
[wb] t1=2123252148729450700 t2=2123252267986116700 ok=true
[2026-11-19 12:09:26] done rc=0
--- publish-bf-matome-oneshot-out.log
--- publish-bf-matome-oneshot-err.log
```

## ほかの予約ジョブ
```
ai.openclaw.publish-hanabi-oneshot.plist
ai.openclaw.publish-hanabi-oneshot.plist.bak-x352
ai.openclaw.publish-payid-oneshot.plist
ai.openclaw.publish-payid-oneshot.plist.bak-x352
ai.openclaw.publish-points-oneshot.plist
com.dailyhack.publish-bf-matome-oneshot.plist
com.dailyhack.publish-furusato-portal-comparison-2026-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist.bak-x352
com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist.bak-x352
com.dailyhack.publish-rainbow-ride-oneshot.plist
com.dailyhack.publish-wangan-map-oneshot.plist
```

**読むだけ。LLM 不使用（$0）。**
