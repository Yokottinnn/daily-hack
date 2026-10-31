# ポイント経済圏の告知を予約する（2026-10-31 21:19:00 JST・$0）

## 0. 予約時刻

```
  JST          2026-11-01 12:00
  scheduled_at 2026-11-01T03:00:00.000Z  (UTC)
  いまから      881 分後
```

## 1. 画像 2 枚を origin/main から取り直す

```
  2-rules.jpg        162823 bytes
  4-how.jpg          139687 bytes
  対象 2 枚 / 取れた 2 枚
```

## 2. 文面を origin/main から取り、利用者のレビューが入った版かを確かめて積む

```
  [1/2] レビュー済みの版 一致 ／ 文字 1105 ／ 重み 1980 / 25000 ／ sha 68d3c1bb9952
  [2/2] レビュー済みの版 一致 ／ 文字 119 ／ 重み 111 / 25000 ／ sha d9584a49ed3b
OK 積んだ: blog-promo-20261101-points
  rc=0
```

## 3. 12:00 に 1 回だけ走るジョブ

```
  bootstrap rc=0  
```

## 4. 載ったことの証拠（rc ではなく print で見る）

```
  	path = /Users/ny/Library/LaunchAgents/ai.openclaw.publish-points-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **載っている**
```

## 5. Chrome は健全か（予約時点の参考。12:00 に run-publish.sh が ensure-chrome を呼ぶ）

```
{"ok":true,"healthy":true,"round_trip_ms":200,"product":"Chrome/140.0.7339.207","tabs":0}
  (rc=0)
```

## 取り消すとき

```bash
  launchctl bootout gui/501/ai.openclaw.publish-points-oneshot
  rm -f "/Users/ny/Library/LaunchAgents/ai.openclaw.publish-points-oneshot.plist" "/Users/ny/.openclaw/workspace/scripts/publish-points-oneshot.sh"
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。常駐させないので、毎日の費用は増えない。**
