# 予約ジョブのラベルを載せ替える（2026-10-18 00:17:32 JST・$0）

## 0. いまの状態

```
  ai.openclaw.publish-prime-oneshot: 載っている
  runner: 在る
  キューの id 出現: 1
```

## 1. 実行スクリプトのラベルを書き換える

```
  10:/bin/launchctl bootout "gui/501/com.dailyhack.publish-prime-oneshot" 2>/dev/null
  11:/bin/rm -f "/Users/ny/Library/LaunchAgents/com.dailyhack.publish-prime-oneshot.plist"
```

## 2. 古いジョブを外し、新しいラベルで同じ時刻に載せる

```
  bootstrap rc=0  
```

## 3. 証拠（rc ではなく print）

```
  	path = /Users/ny/Library/LaunchAgents/com.dailyhack.publish-prime-oneshot.plist
  	state = not running
  	program = /bin/bash
  	runs = 0
  → **新しいラベルで載っている**
  古いラベル: 外れた
```

**投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
