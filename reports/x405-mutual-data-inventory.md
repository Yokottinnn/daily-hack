# 相互を数えるための記録の棚卸し（2026-11-03 17:48 JST・読むだけ・$0）

## data/ の候補ファイル（名前・大きさ・更新）
```
21 Oct 3 21:03 .x214-follower-300.lock
21 Oct 12 19:31 .x272-blue-badge.lock
21 Oct 12 20:33 .x276-blue-badge.lock
21 Oct 18 20:57 .x325-follower-500.lock
42528 Nov 3 16:22 badge-followback-state.json
10428 Nov 3 15:16 follow-balance-followers-prev.json
23446 Nov 3 15:16 follow-balance-lists.json
4301 Nov 3 15:28 follow-balance-notfollowing.json
74951 Nov 3 15:28 follow-balance-state.json
619 Sep 9 11:03 follow-watchdog-state.json
92293 Nov 3 16:22 followed.json
109 Sep 9 08:00 follower-daily-report-state.json
1577 May 24 00:30 follower-history.json
3136 Nov 3 00:35 follower-snapshots
124 Aug 22 19:37 follower-target-config.json
125 Aug 22 19:37 follower-target-config.json.bak
160 Jun 6 00:55 following-snapshots
20051 Nov 3 13:23 mutual-prune-state.json
4531 Aug 2 20:45 refollow-blacklist.json
24 May 20 21:03 refollow-may18-done.flag
501843 Nov 3 17:00 reply-followers.json
106178 Sep 13 19:41 reply-followers.json.bak-20260913-194151
165093 Sep 13 19:44 reply-followers.json.bak-20260913-194413
174282 Sep 15 02:01 reply-followers.json.bak-20260915-020121
15630 Sep 9 20:31 unfollow-cleanup-state.json
742 Jul 19 23:06 unfollow-whitelist.json
1817 May 9 01:15 unfollow_batch.json
128 Oct 12 20:33 x-blue-badge
96 Oct 3 21:03 x-follower-300
96 Oct 18 20:57 x-follower-500
```

## 中身の形（キーと 1 件目の項目名・件数。ハンドルは出さない）
```
follow-balance-lists.json : 物 キー 5 個
   at → string
   me → string
   following → 配列 483 件・1件目: string
   followers → 配列 726 件・1件目: string
   secs → 物 2 個
reply-followers.json : 物 キー 965 個
  1件目の項目: followed_at,followback_status,scheduled_unfollow_at,source,comment_id,followback_judgment_at,still_following,follows_back,checked_at,unfollowed_at,unfollow_source,unfollow_note
badge-followback-state.json : 物 キー 3 個
   processed → 配列 764 件・1件目: string
   followed_back → 配列 335 件・1件目: handle,at
   initialized → boolean
mutual-prune-state.json : 物 キー 125 個
  1件目の項目: unfollowed_at,why,followers,idle_days
follow-balance-state.json : 物 キー 551 個
  1件目の項目: unfollowed_at,why,rank
```

## 他のファイルで「verified」を持つもの
```
followed.json
reply-followers.json
```
