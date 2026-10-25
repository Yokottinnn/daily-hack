# 返信の記録と分析画面（2026-10-25 21:22:20 JST・読むだけ・$0）

## 1. 返信の記録になりそうなファイル（data/ と logs/）
```
21 Oct 4 20:02 .x245-jal-2x-reply.lock
21 Oct 4 20:09 .x248-jal-2x-reply.lock
50 Oct 25 19:04 auto-reply-fail-streak.json
6949 Jul 6 08:00 comment-state.json
7585 Aug 28 00:40 comment-templates.json
3373 May 13 10:03 comment-templates.json.bak.20260513-100323
7056 May 15 15:01 comment-templates.json.bak.20260515-watashi-migration
8023 Aug 28 00:40 comment-templates.json.pre034.20260827-154041
112212 Oct 25 21:11 incoming-reply-state.json
2522 Aug 15 19:25 quick-reply-targets.json
417772 Oct 25 19:04 reply-followers.json
106178 Sep 13 19:41 reply-followers.json.bak-20260913-194151
165093 Sep 13 19:44 reply-followers.json.bak-20260913-194413
174282 Sep 15 02:01 reply-followers.json.bak-20260915-020121
4160 Aug 28 00:40 reply-ng-rules.json
4160 Aug 28 00:40 reply-ng-rules.json.bak.20260906-201513
3246 Aug 28 00:40 reply-ng-rules.json.pre034.20260827-154041
8814 Sep 13 15:27 reply-relevance-rules.json
7882 Sep 13 02:34 reply-relevance-rules.json.bak-20260913-023420
8322 Sep 13 15:27 reply-relevance-rules.json.bak-20260913-152748
10030 Sep 6 20:15 reply-style-prompt.json
3572 Aug 29 00:51 reply-tone-rules.json
863675 Oct 25 19:04 comment-orchestrator.log
457541 Oct 25 19:04 comment-warmup-err.log
1084568 Oct 25 19:04 comment-warmup.log
4280 Jun 7 08:30 dm-orchestrator.log
0 May 15 16:04 follow-up-reply.err
28642 May 17 02:23 follow-up-reply.log
28582 May 17 02:23 follow-up-reply.out
20036 Aug 10 08:42 incoming-reply-responder-err.log
1496353 Aug 10 09:47 incoming-reply-responder.log
4059 Oct 16 17:07 incoming-reply-watcher.err
1889510 Oct 25 21:11 incoming-reply-watcher.log
1069781 Oct 25 21:11 incoming-reply-watcher.out
29118 Aug 9 16:00 qt-orchestrator.log
713 Aug 15 19:28 quick-reply-watcher.log
15021 Sep 7 23:59 reply-followback-check.err
131819 Oct 25 13:15 reply-followback-check.log
124879 Oct 25 13:15 reply-followback-check.out
7198429 Oct 21 05:03 reply-followers-cleanup.err
17592179 Oct 25 05:02 reply-followers-cleanup.log
17580139 Oct 25 05:02 reply-followers-cleanup.out
730 Jun 9 06:35 reply-test-20260609.json
29897 Sep 9 09:34 trend-orchestrator.log
```

## 2. それぞれの中身の形（項目名と件数・値は出さない）
```
--- auto-reply-fail-streak.json（3 件・直近 7 日 ? 件）項目:  ／ ID らしい項目: なし
--- comment-state.json（7 件・直近 7 日 ? 件）項目: 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24 ／ ID らしい項目: なし
--- comment-templates.json（35 件・直近 7 日 ? 件）項目: id,category,scenario,template ／ ID らしい項目: なし
--- incoming-reply-state.json（3 件・直近 7 日 ? 件）項目: 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24 ／ ID らしい項目: なし
--- quick-reply-targets.json（3 件・直近 7 日 ? 件）項目: 0,1,2,3,4,5,6,7 ／ ID らしい項目: なし
--- reply-followers.json（902 件・直近 7 日 ? 件）項目: followed_at,followback_status,followers_at_follow,following_at_follow,phase_at_follow,source,followback_judgment_at,scheduled_unfollow_at,unfollowed_at,unfollow_source,unfollow_reason,comment_id,seed_post_url,seed_engagement,incoming_reply_id,still_following,verified ／ ID らしい項目: seed_post_url,incoming_reply_id
--- reply-ng-rules.json（10 件・直近 7 日 ? 件）項目: _note,words,threshold,domains,emoji,min_account_age_days,_min_account_age_note,max_following_to_follower_ratio,_ratio_note,require_ja_content,_ja_note ／ ID らしい項目: なし
--- reply-relevance-rules.json（44 件・直近 7 日 ? 件）項目: 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,_doc,T11,T09,T16 ／ ID らしい項目: なし
--- reply-style-prompt.json（12 件・直近 7 日 ? 件）項目: 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24 ／ ID らしい項目: なし
--- reply-tone-rules.json（4 件・直近 7 日 ? 件）項目: _doc,referral,url,insult,illegal_topic,minor_safety,command,assertion,repeat,max_emoji,max_chars,min_chars ／ ID らしい項目: url
```

## 3. 自分の返信 1 件の分析画面（押さない）
```
返信タブで見つけた自分の投稿: 5 件 ／ 選んだのは返信か: false
  ポスト アナリティクス
  引用
  あんたバカぁ？まだ損してるの？速報💸
  @heng_ji31590
  ·
  1時間
  返信先: @<伏せ>さん
  1
  0
  1
  インプレッション数
  14
  エンゲージメント
  3
  詳細のクリック数
  1
  プロフィールへのアクセス数
  0
  ポストをブースト
```
**読んだだけ。返信・クリックはしていない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
