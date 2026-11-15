# 関所を外して確かめる（2026-10-30 00:44:34 JST・$0）

## 1. plist から関所を外す
```
外した plist: 74 本 / 読み込み直して関所が消えたのを確かめた: 20 本
動いている最中で後回し: ai.openclaw.caffeinate ai.openclaw.reply-followers-cleanup ai.openclaw.tab-guard com.dailyhack.openclaw.listener com.dailyhack.ops-poller
```

## 2. いま動いている node（X に触っていそうなもの・経過時間）
```
10275       02:39:13 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/unfollow-handle.js hirouma888
10331       19:39:58 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/tab-guard.js --watch
19189       18:44:32 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js
42160          00:00 /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/x-impressions.js
```

## 3. 返信の入力欄が開くか（自分の固定の投稿を開くだけ・押さない）
```
{"textarea":true,"errorText":true}
```
**入力欄は開いた。**
