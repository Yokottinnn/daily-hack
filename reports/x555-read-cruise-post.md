# クルーズ船が出たか（2026-11-25 15:17:07 JST・読むだけ・$0）

## キュー
```
status=posted x_tweet_id=2125423526731718903 posted_at=2026-11-25T02:57:34.374Z scheduled_at=2026-11-25T02:56:00.000Z
last_result={"ok":true,"step":null,"error":""}
  [1] x_tweet_id=2125423526731718903
  [2] x_tweet_id=2125423610022228242
```

## ジョブ
```
載っていない（走り終えて自分を外したか、最初から載っていない）
-rw-r--r--  1 ny  staff  872 Nov 23 23:13 /Users/ny/Library/LaunchAgents/com.dailyhack.publish-cruise-ranking-oneshot.plist
```

## ログ（末尾 40 行）
```
--- publish-cruise-ranking-oneshot.log
[2026-11-25 11:56:05] start
[run-publish] thread_chain mode
[post-via-playwright] attached 6/6 image(s)
[post-via-playwright] alt set for image 1 (197 chars)
[post-via-playwright] alt set for image 2 (140 chars)
[post-via-playwright] alt set for image 3 (143 chars)
[post-via-playwright] alt set for image 4 (152 chars)
[post-via-playwright] alt set for image 5 (128 chars)
[post-via-playwright] alt set for image 6 (173 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=944ms
[step] find-reply-textarea t=7141ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=7238ms
[step] type-text t=7239ms
[x154] article が無い。いいねは飛ばす
[step] arm-response-listener t=11062ms
[step] submit t=11064ms
[step] wait-response-or-confirm t=11172ms
[step] wait-textarea-clear t=11632ms
{"ok":true,"tweet_id":"2125423526731718903","url":"https://x.com/heng_ji31590/status/2125423526731718903","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2125423526731718903","url":"https://x.com/heng_ji31590/status/2125423526731718903","image_attached":true,"captur
[wb] t1=2125423526731718903 t2=2125423610022228242 ok=true
[2026-11-25 11:57:34] done rc=0
--- publish-cruise-ranking-oneshot-out.log
--- publish-cruise-ranking-oneshot-err.log
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
com.dailyhack.publish-camp-koyomi-oneshot.plist
com.dailyhack.publish-cruise-ranking-oneshot.plist
com.dailyhack.publish-furusato-portal-comparison-2026-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist.bak-x352
com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist.bak-x352
com.dailyhack.publish-rainbow-ride-oneshot.plist
com.dailyhack.publish-wangan-illumination-oneshot.plist
com.dailyhack.publish-wangan-map-oneshot.plist
com.dailyhack.publish-xmas-market-hikaku-oneshot.plist
```

**読むだけ。LLM 不使用（$0）。**
