# 比率の調整：外す間隔を決まりに合わせ、候補を広げて、いま走らせる（2026-11-02 22:16 JST・$0）
```
pacer: /Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs
① 差し込んだ
① 入れた・構文 OK
568:      // x403: フォロー解除は全ジョブ共有の台帳で 120 秒あけ・30 分 6 回まで（最上位ルール 23）。空くまで待って記�
569:      { const _r = await require("/Users/ny/.openclaw/workspace/lib/x-action-pacer.cjs").waitTake("unfollow", 35 * 60 * 1000); if (!_r.ok) { log("  間隔�
--- ② plist
{"MAX_PROFILE_READS":"60","DECIDE_BUDGET_S":"300","FOLLOW_RATIO_GLIDE":"370:0.57,500:0.50,700:0.42,1000:0.33","LIST_BUDGET_S":"110","MIN_UNFOLLOW":"20","HOME":"\/Users\/ny","MAX_UNFOLLOW":"20","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin:\/usr\/sbin:\/sbin","GRACE_DAYS":"1"}
--- ③ 載せ直して走らせる
bootstrap rc=0
kickstart rc=0
	state = running 	runs = 1 	last exit code = (never exited) 		state = active 		state = active 
**載っている**
--- 台帳のいまの数
tweet: 直近 30 分 0/12・間隔 60 秒
like: 直近 30 分 0/10・間隔 45 秒
follow: 直近 30 分 0/4・間隔 180 秒
unfollow: 直近 30 分 0/6・間隔 120 秒
--- ほかに外すジョブが台帳を使っているか（読むだけ）
mutual-prune.js: 0
unfollow-handle.js: 1
```
**LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。結果は次のタスクで読む**
