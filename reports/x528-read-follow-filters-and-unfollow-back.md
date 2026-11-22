# フォロワー対策の下調べ（2026-11-21 23:16:48 JST・読むだけ・$0）

## ① フォローのジョブが読む環境変数

### competitor-follower-follow.js
```
process.env.CHROME_CDP_URL || "http://127.0.0.1:18810"
process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10)
process.env.COMPETITOR_VERIFIED_ONLY === "0" ? "followers" : "verified_followers"
process.env.FORCE_RUN) {
-- followers を比べている行
```

### hashtag-follow.js
```
process.env.FORCE_RUN) {
process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10)
process.env.HASHTAG_REQUIRE_VERIFIED === "0" ? "" : "1" }) })
-- followers を比べている行
```

### follow-handle.js
```
process.env.CHROME_CDP_URL || "http://127.0.0.1:18810"
process.env.FOLLOW_MIN_RATIO || "0")) {
process.env.FOLLOW_NAME_FILTER || "log"
process.env.FOLLOW_REQUIRE_VERIFIED === "1" && profile.verified === false) {
-- followers を比べている行
86:  if (followerCount < 100) return 1;
87:  if (followerCount < 300) return 2;
102:  if (follower_count < minFollowers || follower_count > 50000) {
107:  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
108:  if (follower_count >= 50) {
111:      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, p
```

### badge-followback.js
```
process.env.BASELINE_ONLY === "1"
process.env.CHROME_CDP_URL || "http://127.0.0.1:18810"
process.env.DRY_RUN === "1"
process.env.FOLLOWBACK_MAX_PER_RUN || 25)
process.env.HOME + "/.openclaw/workspace/config/silent_slack.json"
-- followers を比べている行
```

### comment-warmup.js
```
無い
```

### mutual-prune.js
```
process.env.ABS_MIN || 300)
process.env.CDP_URL || "http://127.0.0.1:18810"
process.env.DRY_RUN === "1"
process.env.GRACE_DAYS || 14)
process.env.INACTIVE_DAYS || 30)
process.env.MAX_UNFOLLOW || 8)
process.env.MUTUAL_RATIO_CUT ? Number(process.env.MUTUAL_RATIO_CUT) : null
process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace")
process.env.RATIO || 0.20)
-- followers を比べている行
```

### follow-balance.js
```
process.env.BIG_FOLLOWERS || 5000)
process.env.CACHE_MAX_H || 6)
process.env.CDP_URL || "http://127.0.0.1:18810"
process.env.DECIDE_BUDGET_S || 200)
process.env.DRY_RUN === "1"
process.env.FOLLOW_RATIO_CEIL || 0.65)
process.env.FOLLOW_RATIO_FLOOR || 0.45)
process.env.FOLLOW_RATIO_GLIDE) {
process.env.FOLLOW_RATIO_GLIDE.split(",").map((s) => s.split(":").map(Number)).filter((a) => a.length === 2 && a.every(i
process.env.FOLLOW_RATIO_TARGET || 0.58)
process.env.GRACE_DAYS || 7)
process.env.HOME, ".openclaw/workspace/data/badge-followback-state.json"), "utf8"))
process.env.HOME, ".openclaw/workspace/data/follow-balance-empty.json"), "utf8"))
process.env.HOME, ".openclaw/workspace/data/follow-balance-empty.json"), JSON.stringify(j, null, 1))
process.env.INACTIVE_DAYS || 30)
process.env.LIST_BUDGET_S || 150)
process.env.MAX_PROFILE_READS || 40)
process.env.MAX_UNFOLLOW || 60)
process.env.MIN_UNFOLLOW || 30)
process.env.MODE || "all").toLowerCase()
process.env.ONEWAY_IGNORE_ENGAGED !== "0"
process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace")
process.env.SELF_HANDLE || "heng_ji31590"
-- followers を比べている行
334:  if (hdr && Number.isFinite(hdr.following) && Number.isFinite(hdr.followers) && hdr.followers > 0) {
```

## ② plist に入っている FOLLOW_*・MUTUAL_*・GRACE

### competitor-follower-follow
```
COMPETITOR_FOLLOW_DAILY_CAP = 20
FOLLOW_MIN_RATIO = 0.7
```

### hashtag-follow
```
HASHTAG_FOLLOW_DAILY_CAP = 20
FOLLOW_MIN_RATIO = 0.7
```

### comment-warmup
```
MIN_LIKES = 2
MAX_AGE_HOURS = 18
MAX_PICKS_PER_FIRE = 5
REPLY_FOLLOW_DAILY_CAP = 30
```

### badge-followback
```
FOLLOWBACK_MAX_PER_RUN = 25
```

### mutual-prune
```
MAX_UNFOLLOW = 8
MUTUAL_RATIO_CUT = 0
GRACE_DAYS = 3
```

### follow-balance
```
MAX_PROFILE_READS = 60
FOLLOW_RATIO_GLIDE = 500:0.62,700:0.60,1000:0.55,1500:0.50
MIN_UNFOLLOW = 2
MAX_UNFOLLOW = 20
GRACE_DAYS = 3
```

## ③ 外した記録・フォロワーの記録（ファイル名・大きさ・更新日・件数・キー）
```
21 Oct 3 21:03 .x214-follower-300.lock
21 Oct 18 20:57 .x325-follower-500.lock
57982 Nov 21 22:32 badge-followback-state.json
4321 Nov 17 12:55 follow-balance-empty.json
11500 Nov 21 20:24 follow-balance-followers-prev.json
27236 Nov 21 20:24 follow-balance-lists.json
6902 Nov 21 20:26 follow-balance-notfollowing.json
107816 Nov 21 20:39 follow-balance-state.json
660 Nov 13 11:03 follow-watchdog-state.json
108 Nov 13 08:00 follower-daily-report-state.json
1577 May 24 00:30 follower-history.json
3712 Nov 21 00:36 follower-snapshots
124 Aug 22 19:37 follower-target-config.json
125 Aug 22 19:37 follower-target-config.json.bak
160 Jun 6 00:55 following-snapshots
23334 Nov 21 18:44 mutual-prune-state.json
4531 Aug 2 20:45 refollow-blacklist.json
24 May 20 2026 refollow-may18-done.flag
567905 Nov 21 21:00 reply-followers.json
106178 Sep 13 19:41 reply-followers.json.bak-20260913-194151
165093 Sep 13 19:44 reply-followers.json.bak-20260913-194413
174282 Sep 15 02:01 reply-followers.json.bak-20260915-020121
19477 Nov 13 20:31 unfollow-cleanup-state.json
742 Jul 19 23:06 unfollow-whitelist.json
1817 May 9 2026 unfollow_batch.json
96 Oct 3 21:03 x-follower-300
96 Oct 18 20:57 x-follower-500
```
```
badge-followback-state.json: オブジェクト 3 キー 例のキーの形: 0,1,2,3,4,5,6,7,8,9,10,11
   .processed: 配列 1025 件
   .followed_back: 配列 462 件 キー: handle,at
   .initialized: boolean
follow-balance-empty.json: オブジェクト 66 キー 例のキーの形: 0,1
follow-balance-followers-prev.json: オブジェクト 2 キー 例のキーの形: string
   .at: string
   .followers: 配列 799 件
follow-balance-lists.json: オブジェクト 5 キー 例のキーの形: string
   .at: string
   .me: string
   .following: 配列 609 件
   .followers: 配列 799 件
   .secs: オブジェクト 2 キー 例のキーの形: number
follow-balance-notfollowing.json: 配列 409 件
follow-balance-state.json: オブジェクト 792 キー 例のキーの形: unfollowed_at,why,rank
follower-daily-report-state.json: オブジェクト 3 キー 例のキーの形: string
   .last_run: string
   .consec_behind: number
   .last_pace_actual: number
follower-history.json: オブジェクト 1 キー 例のキーの形: 0,1,2,3,4,5,6,7,8,9
   .snapshots: 配列 10 件 キー: date,captured_at,followers,following,ratio
follower-target-config.json: オブジェクト 5 キー 例のキーの形: string
   .version: string
   .target: number
   .deadline: string
   .baseline_count: number
   .baseline_date: string
mutual-prune-state.json: オブジェクト 145 キー 例のキーの形: unfollowed_at,why,followers,idle_days
reply-followers.json: オブジェクト 1079 キー 例のキーの形: followed_at,followback_status,scheduled_unfollow_at,source,comment_id,followback_judgment_at,still_following,follows_back,checked_at,unfollowed_at,unfollow_source,unfollow_note
unfollow-cleanup-state.json: オブジェクト 9 キー 例のキーの形: number
   .version: number
   .phase: string
   .started_at: string
   .target_ratio_phase_a: number
   .current_ratio: number
   .unfollow_log: 配列 83 件 キー: handle,at,tier,result
   .tier_snapshot: オブジェクト 6 キー 例のキーの形: number
   .halt_flags: オブジェクト 0 キー
unfollow-whitelist.json: オブジェクト 5 キー 例のキーの形: string
   .version: string
   .description: string
   .last_updated: string
   .whitelist: 配列 12 件
   .notes: string
unfollow_batch.json: オブジェクト 3 キー 例のキーの形: string
   .timestamp: string
   .total_inactive: number
```

## ④ ログ: mutual-prune が外した件数（日ごと・直近 14 日）
```
--- mutual-prune.log
 403 2026-11-08
 386 2026-11-09
1199 2026-11-10
1615 2026-11-11
1521 2026-11-12
 833 2026-11-13
 285 2026-11-14
 651 2026-11-15
 865 2026-11-16
 705 2026-11-17
 925 2026-11-18
 616 2026-11-19
 613 2026-11-20
 417 2026-11-21
[2026-11-20T21:23:44.304Z] === mutual-prune done: 0 件 外した ===
[2026-11-21T03:54:55.422Z] === mutual-prune done: 0 件 外した ===
[2026-11-21T09:44:03.685Z] === mutual-prune done: 0 件 外した ===
```

**読むだけ。LLM 不使用（$0）。**
