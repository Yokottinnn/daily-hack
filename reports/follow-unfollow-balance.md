# フォローとアンフォローの収支（2026-09-27 14:53 JST・$0）

**このレポートが作られた時刻: 2026-09-27 14:53:32 JST**

> **読むだけ。** フォローもアンフォローもしていない。設定も変えていない。

## 1. プロフィールの実数（**これが答えそのもの**）

```json
  {"ok":true,"followingTxt":"251","followersTxt":"288","following":251,"followers":288}
```

> **取れなければ、そう書く。** 推測の数字は置かない。

## 2. ジョブが載っているか（**載っていなければ、そもそも走らない**）

```
  --- フォローする側 ---
  ai.openclaw.competitor-follower-follow     **載っている** 	runs = 2
  ai.openclaw.hashtag-follow                 **載っている** 	runs = 2
  ai.openclaw.reply-follow                   載っていない

  --- アンフォローする側 ---
  ai.openclaw.unfollow-daily                 載っていない
  ai.openclaw.unfollow-evening               載っていない
  ai.openclaw.unfollow-cleanup-morning       載っていない
  ai.openclaw.unfollow-cleanup-evening       載っていない
  ai.openclaw.auto-detect-and-unfollow-inactive 載っていない
  ai.openclaw.revenge-unfollow               載っていない
  ai.openclaw.mutual-prune                   **載っている** 	runs = 1
  ai.openclaw.reply-followers-cleanup        **載っている** 	runs = 2
  ai.openclaw.unfollow-stats-monitor         載っていない

  --- LaunchAgents に在る unfollow / prune 系の plist ---
    ai.openclaw.auto-detect-and-unfollow-inactive.plist
    ai.openclaw.mutual-prune.plist
    ai.openclaw.mutual-prune.plist.bak-20260913-104853
    ai.openclaw.mutual-prune.plist.bak-20260915-012122
    ai.openclaw.reply-followers-cleanup.plist
    ai.openclaw.reply-followers-cleanup.plist.bak-20260913-030908
    ai.openclaw.revenge-unfollow.plist
    ai.openclaw.unfollow-cleanup-evening.plist
    ai.openclaw.unfollow-cleanup-morning.plist
    ai.openclaw.unfollow-daily.plist
    ai.openclaw.unfollow-evening.plist
    ai.openclaw.unfollow-stats-monitor.plist
```

## 3. 各ログの最終更新と末尾（**何をして終わっているか**）

```
  competitor-follower-follow           更新 09-27 11:46     416065 bytes
  hashtag-follow                       更新 09-27 10:20     146146 bytes
  unfollow-daily                       更新 08-10 09:00      42362 bytes
  unfollow-evening                     更新 08-09 22:00      42876 bytes
  unfollow-cleanup-morning             更新 08-06 09:30       4248 bytes
  unfollow-cleanup-evening             更新 08-06 20:30       4602 bytes
  auto-detect-and-unfollow-inactive    更新 09-09 22:30      17446 bytes
  revenge-unfollow                     更新 09-09 13:00      21332 bytes
  mutual-prune                         更新 09-27 05:11     227376 bytes
  reply-followers-cleanup              更新 09-27 05:01   17548388 bytes
```

アンフォロー系の末尾（**書式が分かる。数え方を決められる**）:

### `unfollow-daily.log`

```
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":1,"unfollowed":["okane_kyukyu"],"ghosts":[],"failed":[]}
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":3,"unfollowed":["kabu_world_map","tanoc_happy"],"ghosts":[],"failed":[]}
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":3,"unfollowed":[],"cancelled":["aichikyu369","abi_41_official","hitsujimaru_ai"],"ghosts":[],"failed":[]}
```

### `unfollow-evening.log`

```
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":19,"unfollowed":[],"cancelled":[],"ghosts":["cony30175146","gSkTl8nNVU89471","xwGiEzSE9","DwacHXEg55","NyEkrFlE8","sinonon882211","lis1713226","55_VYYpkSWr","usari__xxx",
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
  [unfollow] WHITELIST skip @<伏せ>
  [unfollow] WHITELIST skip @<伏せ>
  {"ok":true,"total_candidates":0,"unfollowed":[],"failed":[]}
```

### `unfollow-cleanup-morning.log`

```
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
  {"ok":false,"error":"browserType.connectOverCDP: Timeout 30000ms exceeded.\nCall log:\n  - <ws preparing> retrieving websocket url from http://127.0.0.1:18800\n  - <ws connecting> ws://127.0.0.1:18800
```

### `mutual-prune.log`

```
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:44.828Z]   ・ @<伏せ> — フォロワー数が読めない（読めない＝悪いではない）
  [2026-09-26T20:11:48.476Z]   @<伏せ>: フォロー中のボタンが無い（既に外れている可能性）
  [2026-09-26T20:11:52.133Z]   @<伏せ>: フォロー中のボタンが無い（既に外れている可能性）
  [2026-09-26T20:11:52.144Z] reply-followers.json に反映: 0 件
  [2026-09-26T20:11:52.144Z] === mutual-prune done: 0 件 外した ===
```

### `reply-followers-cleanup.log`

```
  [2026-09-23T14:40:42.438Z] @<伏せ>: unfollow failed (no unfollow button)
  [2026-09-23T20:02:21.419Z] due 264 → 上限 20 件に絞る（残りは次回）
  [2026-09-23T20:02:21.422Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
  [2026-09-24T20:02:23.001Z] due 278 → 上限 20 件に絞る（残りは次回）
  [2026-09-24T20:02:23.005Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
  [2026-09-25T20:01:34.644Z] due 288 → 上限 20 件に絞る（残りは次回）
  [2026-09-25T20:01:34.662Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
  [2026-09-26T10:17:08.753Z] @<伏せ>: unfollow failed (no unfollow button)
  [2026-09-26T11:00:05.081Z] due 291 → 上限 20 件に絞る（残りは次回）
  [2026-09-26T11:00:05.083Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
  [2026-09-26T20:01:36.371Z] due 299 → 上限 20 件に絞る（残りは次回）
  [2026-09-26T20:01:36.373Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mon
```

### `auto-detect-and-unfollow-inactive.log`

```
   5. ArenaBreakoutJP      → https://x.com/renaBreakoutJP
   6. just_unique0         → https://x.com/ust_unique0
   7. americangirl402      → https://x.com/mericangirl402
   8. money_yossy          → https://x.com/oney_yossy
   9. 422200               → https://x.com/22200
  10. R80455959            → https://x.com/80455959
  
  ⏭️  After noting dates, update followed.json using:
     node update_activity_manual.js
  
  ✅ No inactive accounts detected.
  
```


## 4. 相互フォローの材料が在るか（**管理の土台**）

「相互だけど外してよさそうな相手」を選ぶには、**誰をフォローしているか**と
**誰が返してくれているか**の両方が要る。

```
  followed.json                          56555 bytes  更新 09-27 00:51
  reply-followers.json                  232297 bytes  更新 09-27 13:15
  badge-followback-state.json            11161 bytes  更新 09-27 00:51
  refollow-blacklist.json                 4531 bytes  更新 08-02 20:45
  unfollow-whitelist.json                  742 bytes  更新 07-19 23:06
  follower-history.json                   1577 bytes  更新 05-24 00:30
  unfollow-cleanup-state.json            15630 bytes  更新 09-09 20:31
```

`followed.json` の 1 件の形（**いつフォローしたか・返ってきたかが要る**）:

```json
  件数: 2
  0                    {"handle":"rata_tsumitate","followed_at":"2026-06-
  1                    {"handle":"mmnnoowr","followed_at":"2026-06-27T05:
  2                    {"handle":"HmdWaxGp612Tw2A","followed_at":"2026-06
  3                    {"handle":"MINIONS_bobbob","followed_at":"2026-06-
  4                    {"handle":"ArenaBreakoutJP","followed_at":"2026-06
  5                    {"handle":"just_unique0","followed_at":"2026-07-01
  6                    {"handle":"americangirl402","followed_at":"2026-07
  7                    {"handle":"money_yossy","followed_at":"2026-07-01T
  8                    {"handle":"422200","followed_at":"2026-07-01T05:16
  9                    {"handle":"R80455959","followed_at":"2026-07-01T05
  10                   {"handle":"ryoppy_826","followed_at":"2026-07-01T0
  11                   {"handle":"100p","followed_at":"2026-07-01T05:09:4
  12                   {"handle":"100","followed_at":"2026-07-01T05:09:53
  13                   {"handle":"100k","followed_at":"2026-07-01T05:09:5
  14                   {"handle":"1009","followed_at":"2026-07-01T05:10:0
  15                   {"handle":"1007","followed_at":"2026-07-01T05:10:0
  16                   {"handle":"100x","followed_at":"2026-07-01T05:10:0
  17                   {"handle":"100i","followed_at":"2026-07-01T05:10:1
  18                   {"handle":"100V","followed_at":"2026-07-01T05:10:1
  19                   {"handle":"100s","followed_at":"2026-07-01T05:10:1
```

## 5. `mutual-prune.js` は何を基準に外すか

```javascript
  314 行  更新 09-15 02:01

  11://   DRY_RUN=1          1 件も外さず、判定だけ出す
  12://   MAX_UNFOLLOW=8     1 回に外す上限
  13://   INACTIVE_DAYS=30   最終投稿がこれより前なら「休眠」
  16://   GRACE_DAYS=14      フォローしてからこの日数 未満は触らない
  23:const DRY = process.env.DRY_RUN === "1";
  24:const MAXN = Number(process.env.MAX_UNFOLLOW || 8);
  25:const INACTIVE_DAYS = Number(process.env.INACTIVE_DAYS || 30);
  28:const GRACE_DAYS = Number(process.env.GRACE_DAYS || 14);
  30:const LOG = path.join(WS, "logs", "mutual-prune.log");
  31:const STATE = path.join(WS, "data", "mutual-prune-state.json");
  45:  for (const p of ["data/mutual-prune-whitelist.json", "data/unfollow-whitelist.json", "data/whitelist.json"]) {
  48:      const arr = Array.isArray(d) ? d : (d.handles || d.whitelist || Object.keys(d));
  52:  return out;
  58:  if (!s) return null;
  61:  if (!m) return null;
  63:  if (!isFinite(n)) return null;
  69:  return Math.round(n);
  85:      return out;
  93:  return seen;
  101:  return await page.evaluate(() => {
  115:    return res;
  120:  log("=== mutual-prune start (dry=" + DRY + " max=" + MAXN + " inactive=" + INACTIVE_DAYS +
  121:      "d ratio=" + RATIO + " absMin=" + ABS_MIN + " grace=" + GRACE_DAYS + "d) ===");
  125:  catch (e) { log("CDP に繋がらない: " + String(e.message).slice(0, 120)); return; }
  127:  if (!ctx) { log("context が無い。何もしない。"); return; }
  134:    if (/login|i\/flow/.test(page.url())) { log("**ログインが切れている。何もしない。**"); await page.close(); return; }
  138:      return m ? m[1] : null;
  140:  } catch (e) { log("/home を開けない: " + String(e.message).slice(0, 100)); await page.close(); return; }
  141:  if (!me) { log("**自分のハンドルが読めない。何もしない。**"); await page.close(); return; }
  152:  if (following.size === 0) { log("**0 件しか読めない。ページが壊れている。何もしない。**"); await page.close(); return; }
  175:  const mutual = [...following].filter((h) => lowerFollowers.has(h.toLowerCase()));
  176:  log("相互フォロー: " + mutual.length + " 件");
  183:  for (const h of mutual) {
  184:    if (decided.filter((d) => d.cut).length >= MAXN) break;
  189:      const days = (now - new Date(fa).getTime()) / 86400000;
  190:      if (isFinite(days) && days < GRACE_DAYS) {
  191:        decided.push({ h, cut: false, why: "フォローしてまだ " + Math.floor(days) + " 日（猶予 " + GRACE_DAYS + " 日）" });
  208:    if (idle >= INACTIVE_DAYS) reasons.push("休眠 " + idle + " 日");
  223:  if (DRY) {
  224:    log("**DRY_RUN。1 件も外していない。**");
```

---

## 読み方

| 出方 | 何が言えるか |
| --- | --- |
| §2 でアンフォロー側が**全部 載っていない** | **アンフォローは走っていない。** フォローだけ増えて当然 |
| 載っているのにログが 8 月 止まり | **走って何もしていない。** §3 の末尾で理由が分かる |
| §4 に返信フォロワーの記録が在る | **相互の判定に使える。** 管理の土台になる |
| §1 が取れない | Chrome か CDP の問題。**数字は書かない** |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
