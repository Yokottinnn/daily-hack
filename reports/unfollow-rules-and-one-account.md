# アンフォローのルールと、指定の 1 アカウント（2026-10-04 12:17 JST・$0）

**このレポートが作られた時刻: 2026-10-04 12:17:28 JST**

## ① follow-balance.js の実際の条件

```
26:const WS = process.env.OPS_WS || path.join(process.env.HOME || "", ".openclaw", "workspace");
27:const CDP = process.env.CDP_URL || "http://127.0.0.1:18810";
29:const MINN = Number(process.env.MIN_UNFOLLOW || 30);
30:const MAXN = Number(process.env.MAX_UNFOLLOW || 60);
31:const GRACE_DAYS = Number(process.env.GRACE_DAYS || 7);
32:const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
33:const BIG = Number(process.env.BIG_FOLLOWERS || 5000);
34:const MAX_READS = Number(process.env.MAX_PROFILE_READS || 40);
40:const MODE = String(process.env.MODE || "all").toLowerCase();
41:const CACHE_MAX_H = Number(process.env.CACHE_MAX_H || 6);
43:const LIST_BUDGET_S = Number(process.env.LIST_BUDGET_S || 150);
47:const DECIDE_BUDGET_S = Number(process.env.DECIDE_BUDGET_S || 200);
49:const ONEWAY_IGNORE_ENGAGED = process.env.ONEWAY_IGNORE_ENGAGED !== "0";
295:  const CEIL_RATIO = Number(process.env.FOLLOW_RATIO_CEIL || 0.65);
296:  const FLOOR_RATIO = Number(process.env.FOLLOW_RATIO_FLOOR || 0.45);
301:  const TARGET_RATIO = Number(process.env.FOLLOW_RATIO_TARGET || 0.58);

  --- 守る条件（どれかに当たると外さない）
375-    if (wl.has(k)) return "ホワイトリスト";
376:    if (engaged.has(k) && !(oneWayStage && ONEWAY_IGNORE_ENGAGED)) return "反応をくれた人";
377-    const d = ageDays(h);
378-    if (d !== null && d < GRACE_DAYS) return "フォローしてまだ " + Math.floor(d) + " 日（猶予 " + GRACE_DAYS + " 日）";
379-    return null;
380-  };
381-
382-  // ① 片思い（フォロバが無い）。**いま誰も担当していない**
383-  // **覚えている未フォローは、そもそも一覧から除く。** 片思いにも相互にも入れない
384-  const knownNot = (h) => notFollowSet.has(String(h).toLowerCase());
385-  const followingReal = [...following].filter((h) => !knownNot(h));
386-  if (following.size !== followingReal.length) {

  --- 片思いから候補を取るところ
379-    return null;
380-  };
381-
382:  // ① 片思い（フォロバが無い）。**いま誰も担当していない**
383-  // **覚えている未フォローは、そもそも一覧から除く。** 片思いにも相互にも入れない
384-  const knownNot = (h) => notFollowSet.has(String(h).toLowerCase());
385-  const followingReal = [...following].filter((h) => !knownNot(h));
386-  if (following.size !== followingReal.length) {
387-    log("走査 " + following.size + " 件 から 未フォロー " +
388-        (following.size - followingReal.length) + " 件 を除いた → " + followingReal.length + " 件");
389-  }
390-  const oneWay = followingReal.filter((h) => !lowerFollowers.has(h.toLowerCase()));
391-  // 相互（②③ の対象）
392-  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));

  --- 下調べの打ち切り
36:// まとめて走らせると 900 秒 の上限に当たって打ち切られ、出力が 1 行も残らなかった。
43:const LIST_BUDGET_S = Number(process.env.LIST_BUDGET_S || 150);
46:// 40 件 × 30 秒 で 900 秒 を超える。2026-09-27 に実際に打ち切られた
134:  const deadline = Date.now() + LIST_BUDGET_S * 1000;
136:    if (Date.now() > deadline) { log("  ⏱ " + LIST_BUDGET_S + " 秒 を超えたので打ち切る（" + seen.size + " 件）"); break; }
181:  await page.waitForTimeout(4700 + Math.floor(Math.random() * 1500));   // x219: 続けて開きすぎると X が空のページを返す（2.2 秒 → 4.7〜6.2 秒）
```

## ② 定時と環境変数

```
  == ai.openclaw.follow-balance（載っている）
      "DECIDE_BUDGET_S" => "150"
      "LIST_BUDGET_S" => "110"
      "MAX_PROFILE_READS" => "40"
      "MAX_UNFOLLOW" => "20"
      "MIN_UNFOLLOW" => "20"
      "Hour" => 11
      "Minute" => 45
      "Hour" => 18
      "Minute" => 45
  == ai.openclaw.mutual-prune（載っている）
      "ABS_MIN" => "300"
      "CDP_URL" => "http://127.0.0.1:18810"
      "GRACE_DAYS" => "14"
      "INACTIVE_DAYS" => "30"
      "MAX_UNFOLLOW" => "8"
      "OPS_WS" => "/Users/ny/.openclaw/workspace"
      "RATIO" => "0.20"
      "Hour" => 6
      "Minute" => 0
      "Hour" => 18
      "Minute" => 0
  == ai.openclaw.reply-followback-check（載っている）
      "Hour" => 1
      "Minute" => 15
      "Hour" => 13
      "Minute" => 15
  == ai.openclaw.unfollow-cleanup-morning（**載っていない**）
      "Hour" => 8
      "Minute" => 30
  == ai.openclaw.unfollow-daily（**載っていない**）
      "UNFOLLOW_DRY_RUN" => "false"
      "UNFOLLOW_MAX_PER_RUN" => "20"
      "UNFOLLOW_STALE_DAYS" => "1"
```

## ③ フォロバ判定の古い仕組み（followed.json）

```
  followed.json: 204 件 ／ followback_status {"?":204} ／ 外す予定日あり 0（うち期日を過ぎた 0）／ 最後のフォロバ判定 null
  reply-followers.json: 623 件 ／ followback_status {"no":471,"revenge_ghost_already_unfollowed":48,"unfollowed":16,"yes_late":1,"yes":55,"pending":32} ／ 外す予定日あり 471（うち期日を過ぎた 370）／ 最後のフォロバ判定 2026-10-03T16:15:21.769Z

  --- reply-followback-check の中身（先頭のコメント）
    #!/usr/bin/env node
    // reply-followback-check.js — every 12h cron.
    // For each reply-followers entry with followback_status="pending" AND followed_at + 24h <= now:
    //   - call check-followback for that handle
    //   - if follows_us: set status="yes", scheduled_unfollow_at=null (keep)
    //   - else: set status="no", scheduled_unfollow_at = followed_at + random(7-14日)
  --- そのログの末尾
    [2026-10-03T04:15:29.700Z] done
    [2026-10-03T16:15:05.131Z] checking 5 handles: tessue1,___arupi___,KAINA0524,misa1234misa567,t_urushidani
    [2026-10-03T16:15:21.721Z] @<伏せ>: no, scheduled_unfollow_at=2026-10-10T13:24:21.812Z
    [2026-10-03T16:15:21.756Z] @<伏せ>: no, scheduled_unfollow_at=2026-10-10T10:39:44.699Z
    [2026-10-03T16:15:21.757Z] @<伏せ>: no, scheduled_unfollow_at=2026-10-13T03:02:10.336Z
    [2026-10-03T16:15:21.768Z] @<伏せ>: no, scheduled_unfollow_at=2026-10-14T13:22:25.058Z
    [2026-10-03T16:15:21.769Z] @<伏せ>: yes (keep)
    [2026-10-03T16:15:21.790Z] done
```

## ④ 指定の 1 アカウント

```
  --- こちらのデータのどこに居るか（data/*.json を全部 見る）
  follow-balance-lists.json: .following[]
  follow-balance-notfollowing.json: []
  reply-followers.json: .<指定> = {"followed_at":"2026-09-25T02:43:27.892Z","followback_status":"yes","followers_at_follow":15,"following_at_follow":143,"phase_at_follow":null,"source":"competitor-follower:haiji_doctor","followback_judgment_at":"2026-09-

  --- ログに出てきた行（follow-balance / mutual-prune / follow 系・新しい 10 行）
[2026-09-25T20:11:50.118Z]   ・ @<指定> — フォローしてまだ 0 日（猶予 14 日）
[2026-09-26T20:11:44.795Z]   ・ @<指定> — フォローしてまだ 1 日（猶予 14 日）
[2026-09-27T20:13:13.382Z]   ・ @<指定> — フォローしてまだ 2 日（猶予 14 日）
[2026-09-29T20:15:01.166Z]   ・ @<指定> — フォローしてまだ 4 日（猶予 14 日）
[2026-09-30T21:10:32.866Z]   ・ @<指定> — フォローしてまだ 5 日（猶予 14 日）
[2026-10-01T20:13:09.215Z]   ・ @<指定> — フォローしてまだ 6 日（猶予 14 日）
[2026-09-25T02:43:27.878Z]   @<指定>: ✅
  @<指定>: ✅
[2026-09-26T04:15:05.086Z] checking 11 handles: placeshowking,stephanie45gz9,uorokushoten,yuzuponzu0990,fukurin1oku,Rin072915,j5ama1638,okada_fire,<指定>,Core_splash1,high_tech_stock
[2026-09-26T04:15:34.120Z] @<指定>: yes (keep)

  --- いまのプロフィール（読むだけ）
  相手がこちらをフォローしているか（フォローされています の表示）: している
  こちらのボタン: フォロー中（こちらがフォローしている）
  相手のフォロー中 113 / フォロワー 123 ／ 最新の投稿 2026-09-26T21:34:46.000Z
```

**外していない。フォローしていない。設定を変えていない（$0／回・$0／日・$0／月）。**
