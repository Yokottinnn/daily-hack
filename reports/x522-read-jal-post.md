# レインボーライドの告知が出たか（2026-11-18 18:47:19 JST・読むだけ・$0）

## キュー
```
status=posted x_tweet_id=2122887719512854585 posted_at=2026-11-18T03:01:15.228Z scheduled_at=2026-11-18T03:00:00.000Z
last_result={"ok":true,"step":null,"error":""}
  [1] x_tweet_id=2122887719512854585
  [2] x_tweet_id=2122887820939530559
```

## ジョブ
```
載っていない（走り終えて自分を外したか、最初から載っていない）
-rw-r--r--  1 ny  staff  863 Nov 15 01:06 /Users/ny/Library/LaunchAgents/com.dailyhack.publish-rainbow-ride-oneshot.plist
```

## ログ（末尾 40 行）
```
--- publish-rainbow-ride-oneshot.log
[2026-11-18 12:00:05] start
[run-publish] thread_chain mode
[post-via-playwright] attached 2/2 image(s)
[post-via-playwright] alt set for image 1 (88 chars)
[post-via-playwright] alt set for image 2 (127 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=5066ms
[step] find-reply-textarea t=11420ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=11514ms
[step] type-text t=11514ms
[x154] like 付いた
[step] arm-response-listener t=15154ms
[step] submit t=15155ms
[step] wait-response-or-confirm t=15232ms
[step] wait-textarea-clear t=15600ms
{"ok":true,"tweet_id":"2122887719512854585","url":"https://x.com/heng_ji31590/status/2122887719512854585","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2122887719512854585","url":"https://x.com/heng_ji31590/status/2122887719512854585","image_attached":true,"captur
[wb] t1=2122887719512854585 t2=2122887820939530559 ok=true
[2026-11-18 12:01:15] done rc=0
--- publish-rainbow-ride-oneshot-out.log
--- publish-rainbow-ride-oneshot-err.log
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
