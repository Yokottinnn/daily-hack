# 決済キャンペーン5つが出たか（2026-11-21 22:04:48 JST・読むだけ・$0）

## キュー
```
status=posted x_tweet_id=2124001703401844981 posted_at=2026-11-21T04:47:44.248Z scheduled_at=2026-11-21T04:47:00.000Z
last_result={"ok":true,"step":null,"error":""}
  [1] x_tweet_id=2124001703401844981
  [2] x_tweet_id=2124001782527602938
```

## ジョブ
```
載っていない（走り終えて自分を外したか、最初から載っていない）
-rw-r--r--  1 ny  staff  840 Nov 21 12:37 /Users/ny/Library/LaunchAgents/com.dailyhack.publish-bf-pay-oneshot.plist
```

## ログ（末尾 40 行）
```
--- publish-bf-pay-oneshot.log
[2026-11-21 13:47:05] start
[run-publish] thread_chain mode
[post-via-playwright] attached 1/1 image(s)
[post-via-playwright] alt set for image 1 (333 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=380ms
[step] find-reply-textarea t=6593ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6640ms
[step] type-text t=6640ms
[x154] like 付いた
[step] arm-response-listener t=9881ms
[step] submit t=9883ms
[step] wait-response-or-confirm t=9997ms
[step] wait-textarea-clear t=10372ms
{"ok":true,"tweet_id":"2124001703401844981","url":"https://x.com/heng_ji31590/status/2124001703401844981","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2124001703401844981","url":"https://x.com/heng_ji31590/status/2124001703401844981","image_attached":true,"captur
[wb] t1=2124001703401844981 t2=2124001782527602938 ok=true
[2026-11-21 13:47:44] done rc=0
--- publish-bf-pay-oneshot-out.log
--- publish-bf-pay-oneshot-err.log
```

## ほかの予約ジョブ
```
ai.openclaw.publish-hanabi-oneshot.plist
ai.openclaw.publish-hanabi-oneshot.plist.bak-x352
ai.openclaw.publish-payid-oneshot.plist
ai.openclaw.publish-payid-oneshot.plist.bak-x352
ai.openclaw.publish-points-oneshot.plist
com.dailyhack.publish-bf-matome-oneshot.plist
com.dailyhack.publish-bf-pay-oneshot.plist
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
