# unfollow-cleanup は follower-history を何に使っているか（2026-09-21 14:10 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 14:10:49 JST**

> x119 で、名指ししているのは **`unfollow-cleanup.js` だけ**と分かった（他は `.bak`）。
> **だが出せたのは定数の宣言行だけで、読み手か書き手か分からない。**
>
> **これは フォローを外す側。** `0 人` を「全員 減った」と読む作りなら、
> **フォロワーを増やそうとしている最中に外す側が誤爆している。**

## 1. 使っている全行（**変数名で引く**）

```javascript
  29-const { execSync, spawnSync } = require("child_process");
  30-
  31-const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
  32-const WS = "/Users/ny/.openclaw/workspace";
  33-const STATE_PATH = `${WS}/data/unfollow-cleanup-state.json`;
  34-const WHITELIST_PATH = `${WS}/data/unfollow-whitelist.json`;
  35:const FOLLOWER_HISTORY = `${WS}/data/follower-history.json`;
  36-const LOGIN_LOCK = "/tmp/x-login-in-progress";
  37-const MANUAL_HALT_FLAG = `${WS}/data/unfollow-cleanup.HALT`;
  38-const SLACK_CHANNEL = "C0A5FKU7T5M";
  39-const OWNER_ID = "U0A5V22PVTQ";
  40-const MAX_PER_FIRE = parseInt(process.env.MAX_PER_FIRE || "3", 10);
  41-const DRY_RUN = process.env.DRY_RUN === "1";
  --
  136-  const reasons = [];
  137-  // 1. login lock
  138-  if (fs.existsSync(LOGIN_LOCK)) reasons.push("login-lock");
  139-  // 2. manual halt file
  140-  if (fs.existsSync(MANUAL_HALT_FLAG)) reasons.push("manual-halt");
  141-  // 3. follower drop 3 consecutive days
  142:  const hist = loadJson(FOLLOWER_HISTORY, []);
  143-  if (Array.isArray(hist) && hist.length >= 3) {
  144-    const last3 = hist.slice(-3);
  145-    let drops = 0;
  146-    for (let i = 1; i < last3.length; i++) {
  147-      if ((last3[i].followers || 0) < (last3[i - 1].followers || 0)) drops++;
  148-    }
```

## 2. 読んでいるのか、書いているのか

```
  --- 読み（readFileSync / existsSync）---
    （無し）
  --- 書き（writeFileSync / appendFileSync）---
    （無し）

  総出現回数: 2
```

**宣言だけで一度も使っていないなら、消してよい。** 上の 2 つが両方 空ならそれ。

## 3. この JS を起動している plist はどれか

```
  ===== ai.openclaw.unfollow-cleanup-evening =====
    plist: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-evening.plist
    **載っていない**
  ===== ai.openclaw.unfollow-cleanup-evening =====
    plist: /Users/ny/Library/LaunchAgents/broken.20260906-212327/ai.openclaw.unfollow-cleanup-evening.plist
    **載っていない**
  ===== ai.openclaw.unfollow-cleanup-morning =====
    plist: /Users/ny/Library/LaunchAgents/broken.20260906-212327/ai.openclaw.unfollow-cleanup-morning.plist
    **載っていない**
  ===== ai.openclaw.unfollow-cleanup-morning =====
    plist: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-morning.plist
    **載っていない**
```

**`launchctl list | grep` では見ない**（載っていても出ないことがある・最上位ルール 13）。

## 4. 直近のログ（**外した件数が出ていれば、それが一次情報**）

```
  ===== auto-detect-and-unfollow-inactive-err.log / 2026-08-23 22:30 =====

  ===== auto-detect-and-unfollow-inactive.log / 2026-09-09 22:30 =====
     5. ArenaBreakoutJP      → https://x.com/renaBreakoutJP
     6. just_unique0         → https://x.com/ust_unique0
     7. americangirl402      → https://x.com/mericangirl402
     8. money_yossy          → https://x.com/oney_yossy
     9. 422200               → https://x.com/22200
    10. R80455959            → https://x.com/80455959
    
    ⏭️  After noting dates, update followed.json using:
       node update_activity_manual.js
    
    ✅ No inactive accounts detected.
    

  ===== revenge-unfollow-err.log / 2026-07-12 13:00 =====
    ensure-chrome: login-mode-guard active, skip launch

  ===== revenge-unfollow.log / 2026-09-09 13:00 =====
    [whitelist] skip @tokufree3
    {"ok":true,"checked":2,"revenge_unfollowed":0,"still_mutual":1,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":["okazusan1"],"ghostSkipped":[],"che
    [whitelist] skip @tokufree3
    {"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
    [whitelist] skip @tokufree3
    {"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}
    [whitelist] skip @tokufree3
    {"ok":true,"checked":10,"revenge_unfollowed":0,"still_mutual":9,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":["watashi4649desu","ameame_san00","
    [whitelist] skip @tokufree3
    {"ok":true,"checked":7,"revenge_unfollowed":0,"still_mutual":6,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":["famicammpbazzz","sidejobacount","t
    [whitelist] skip @tokufree3
    {"ok":true,"checked":1,"revenge_unfollowed":0,"still_mutual":0,"ghost_skipped":0,"check_fail":0,"detail":{"revenged":[],"stillMutual":[],"ghostSkipped":[],"checkFail":[]}

  ===== unfollow-cleanup-evening-err.log / 2026-09-09 20:31 =====
    [unfollow-cleanup] 2026-09-08T11:31:07.580Z unfollowing @aya99919 (bio: "フォローされています フォロー中 お得な情報や気になった内容を不定�
    [unfollow-cleanup] 2026-09-08T11:31:14.292Z   OK
    [unfollow-cleanup] 2026-09-09T11:30:09.453Z whitelist size: 12
    [unfollow-cleanup] 2026-09-09T11:30:11.866Z Chrome tabs: 14
    [unfollow-cleanup] 2026-09-09T11:30:12.280Z scraping /following...
    [unfollow-cleanup] 2026-09-09T11:30:53.452Z scraped 199 handles
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z tier: T1=0 T2=46 T3=106 T4=47
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z candidates (2): kyou1824, ematty_unko
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z unfollowing @kyou1824 (bio: "フォロー中 22歳男 ご主人様 @yui_k_anime  母 @Mr_kamicyama  姉 @cafe_latte")
    [unfollow-cleanup] 2026-09-09T11:31:00.509Z   OK
    [unfollow-cleanup] 2026-09-09T11:31:11.530Z unfollowing @ematty_unko (bio: "フォロー中 本アカ @ematty2  。当垢は趣味寄り。書評 / アニメ / 映画・�
    [unfollow-cleanup] 2026-09-09T11:31:18.288Z   OK

  ===== unfollow-cleanup-evening.log / 2026-08-06 20:30 =====
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co

  ===== unfollow-cleanup-morning-err.log / 2026-09-09 08:31 =====
    [unfollow-cleanup] 2026-09-08T23:30:06.892Z whitelist size: 12
    [unfollow-cleanup] 2026-09-08T23:30:07.639Z Chrome tabs: 12
    [unfollow-cleanup] 2026-09-08T23:30:07.880Z scraping /following...
    [unfollow-cleanup] 2026-09-08T23:30:48.944Z scraped 198 handles
    [unfollow-cleanup] 2026-09-08T23:30:48.975Z tier: T1=1 T2=50 T3=99 T4=48
    [unfollow-cleanup] 2026-09-08T23:30:48.976Z candidates (3): reina33133, morino_kuma1030, poitravelmonkey
    [unfollow-cleanup] 2026-09-08T23:30:48.976Z unfollowing @reina33133 (bio: "フォローされています フォロー中 気になった内容やお得だなと思う内
    [unfollow-cleanup] 2026-09-08T23:30:55.838Z   OK
    [unfollow-cleanup] 2026-09-08T23:31:08.185Z unfollowing @morino_kuma1030 (bio: "フォローされています フォロー中 統合失調症&発達障害者です|食�
    [unfollow-cleanup] 2026-09-08T23:31:14.972Z   OK
    [unfollow-cleanup] 2026-09-08T23:31:28.793Z unfollowing @poitravelmonkey (bio: "フォロー中 ポイント大好きしんぽいおじちゃん👴✌️サブ垢では�
    [unfollow-cleanup] 2026-09-08T23:31:35.568Z   OK

  ===== unfollow-cleanup-morning.log / 2026-08-06 09:30 =====
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co

  ===== unfollow-daily-err.log / 2026-07-12 14:00 =====
    ensure-chrome: login-mode-guard active, skip launch
    ensure-chrome: login-mode-guard active, skip launch

  ===== unfollow-daily.log / 2026-08-10 09:00 =====
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":1,"unfollowed":["okane_kyukyu"],"ghosts":[],"failed":[]}
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":3,"unfollowed":["kabu_world_map","tanoc_happy"],"ghosts":[],"failed":[]}
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":3,"unfollowed":[],"cancelled":["aichikyu369","abi_41_official","hitsujimaru_ai"],"ghosts":[],"failed":[]}

  ===== unfollow-evening-err.log / 2026-07-12 22:00 =====
    ensure-chrome: login-mode-guard active, skip launch
    ensure-chrome: login-mode-guard active, skip launch
    ensure-chrome: login-mode-guard active, skip launch

  ===== unfollow-evening.log / 2026-08-09 22:00 =====
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":19,"unfollowed":[],"cancelled":[],"ghosts":["cony30175146","gSkTl8nNVU89471","xwGiEzSE9","DwacHXEg55","NyEkrFlE8","sinonon882211","lis171322
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
    [unfollow] WHITELIST skip @kii_pointpay
    [unfollow] WHITELIST skip @u_chanmama_
    {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}

  ===== unfollow-stats-monitor.log / 2026-08-10 09:30 =====
    }
    {
      "ok": true,
      "alerts": [],
      "stats": {
        "runs_inspected": 7,
        "sumUnfollowed": 3,
        "sumCancelled": 5,
        "sumFailed": 0,
        "failRatio": "0.00"
      }
    }

  ===== unfollow-stats-monitor.stderr.log / 2026-05-24 09:30 =====

  ===== unfollow-stats-monitor.stdout.log / 2026-05-24 09:30 =====

  ===== x-follower-unfollow-err.log / 2026-05-09 22:00 =====

  ===== x-follower-unfollow.log / 2026-05-09 22:00 =====

  ===== reply-followers-cleanup.log / 2026-09-21 05:02 =====
    [2026-09-15T20:02:25.831Z] due 220 → 上限 20 件に絞る（残りは次回）
    [2026-09-15T20:02:25.840Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos
    [2026-09-16T20:02:29.624Z] due 227 → 上限 20 件に絞る（残りは次回）
    [2026-09-16T20:02:29.675Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos
    [2026-09-17T20:02:36.129Z] due 230 → 上限 20 件に絞る（残りは次回）
    [2026-09-17T20:02:36.133Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos
    [2026-09-18T20:02:39.472Z] due 235 → 上限 20 件に絞る（残りは次回）
    [2026-09-18T20:02:39.476Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos
    [2026-09-19T16:17:22.736Z] due 240 → 上限 20 件に絞る（残りは次回）
    [2026-09-19T16:17:22.739Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos
    [2026-09-20T20:02:22.043Z] due 243 → 上限 20 件に絞る（残りは次回）
    [2026-09-20T20:02:22.046Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyos

  ===== unfollow-cleanup-evening-err.log / 2026-09-09 20:31 =====
    [unfollow-cleanup] 2026-09-08T11:31:07.580Z unfollowing @aya99919 (bio: "フォローされています フォロー中 お得な情報や気になった内容を不定�
    [unfollow-cleanup] 2026-09-08T11:31:14.292Z   OK
    [unfollow-cleanup] 2026-09-09T11:30:09.453Z whitelist size: 12
    [unfollow-cleanup] 2026-09-09T11:30:11.866Z Chrome tabs: 14
    [unfollow-cleanup] 2026-09-09T11:30:12.280Z scraping /following...
    [unfollow-cleanup] 2026-09-09T11:30:53.452Z scraped 199 handles
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z tier: T1=0 T2=46 T3=106 T4=47
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z candidates (2): kyou1824, ematty_unko
    [unfollow-cleanup] 2026-09-09T11:30:53.511Z unfollowing @kyou1824 (bio: "フォロー中 22歳男 ご主人様 @yui_k_anime  母 @Mr_kamicyama  姉 @cafe_latte")
    [unfollow-cleanup] 2026-09-09T11:31:00.509Z   OK
    [unfollow-cleanup] 2026-09-09T11:31:11.530Z unfollowing @ematty_unko (bio: "フォロー中 本アカ @ematty2  。当垢は趣味寄り。書評 / アニメ / 映画・�
    [unfollow-cleanup] 2026-09-09T11:31:18.288Z   OK

  ===== unfollow-cleanup-evening.log / 2026-08-06 20:30 =====
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co

  ===== unfollow-cleanup-morning-err.log / 2026-09-09 08:31 =====
    [unfollow-cleanup] 2026-09-08T23:30:06.892Z whitelist size: 12
    [unfollow-cleanup] 2026-09-08T23:30:07.639Z Chrome tabs: 12
    [unfollow-cleanup] 2026-09-08T23:30:07.880Z scraping /following...
    [unfollow-cleanup] 2026-09-08T23:30:48.944Z scraped 198 handles
    [unfollow-cleanup] 2026-09-08T23:30:48.975Z tier: T1=1 T2=50 T3=99 T4=48
    [unfollow-cleanup] 2026-09-08T23:30:48.976Z candidates (3): reina33133, morino_kuma1030, poitravelmonkey
    [unfollow-cleanup] 2026-09-08T23:30:48.976Z unfollowing @reina33133 (bio: "フォローされています フォロー中 気になった内容やお得だなと思う内
    [unfollow-cleanup] 2026-09-08T23:30:55.838Z   OK
    [unfollow-cleanup] 2026-09-08T23:31:08.185Z unfollowing @morino_kuma1030 (bio: "フォローされています フォロー中 統合失調症&発達障害者です|食�
    [unfollow-cleanup] 2026-09-08T23:31:14.972Z   OK
    [unfollow-cleanup] 2026-09-08T23:31:28.793Z unfollowing @poitravelmonkey (bio: "フォロー中 ポイント大好きしんぽいおじちゃん👴✌️サブ垢では�
    [unfollow-cleanup] 2026-09-08T23:31:35.568Z   OK

  ===== unfollow-cleanup-morning.log / 2026-08-06 09:30 =====
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co
    {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws co

```

## 5. 読み方（**このタスクでは直さない**）

| 出方 | 次の一手 |
| --- | --- |
| 宣言だけで未使用 | **ファイルごと消してよい。** 定数の行も消す |
| 書き手だけ | **4 か月 書けていない。** 止めるか、`follower-snapshots/` に寄せる |
| **読み手が在り、plist が載っている** | **いま誤爆しうる。最優先で直す** |
| 読み手が在るが plist が載っていない | 動いていないので急がない。直すときに一緒に直す |

**正しい記録は `follower-snapshots/YYYY-MM-DD.json` の `count`**
（`followers` はハンドルの配列で人数ではない。docs/follower-tracking.md）。

## 6. 費用

**`grep` と `launchctl print` だけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
