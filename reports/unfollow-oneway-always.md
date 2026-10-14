# 片思いは比率に関係なく外す・相互の整理を 1 回 15 件に（2026-10-14 21:53:45 JST・$0）

## ① follow-balance.js
```json
{"ok":true,"note":"書いた・node --check 通過"}
```
356:      // 2026-10-14 x289: 片思い（猶予を過ぎて返っていない）は比率に関係なく毎回 上限まで外す（利用者の指摘）。
357-      // 比率が目標以内でも片思いを残さない。目標を超えていれば、その分も同じ上限の中で外す
358-      quota = MAXN;

## ② mutual-prune の 1 回の上限
```
	state = not running
		MUTUAL_RATIO_CUT => 0.8
		MAX_UNFOLLOW => 15
```

## ③ follow-balance をいま走らせる
```
kickstart rc=0
	state = running
	runs = 4
	pid = 85940
```

## フォロー側は止めていない
```
competitor-follower-follow: state = not running
hashtag-follow: state = not running
badge-followback: state = not running
```

**LLM を呼んでいない（$0／回・$0／日・$0／月）。** 戻すときは follow-balance.js.bak-x289 と plist の .bak-x289。結果は次のタスクで読む。
