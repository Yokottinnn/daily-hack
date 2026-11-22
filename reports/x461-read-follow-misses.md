# フォローの空振りの原因（2026-11-10 23:55:30 JST・読むだけ・$0）

## ① follow-balance: 0 件で止まった回（11/1 以降・時刻 UTC）
```
2026-11-06T09:45:48.101Z
2026-11-08T09:45:48.195Z
2026-11-10T09:45:51.418Z
--- 時刻ごとの回数（UTC の時）
   8 09
   1 15
--- 起動の時刻ごとの回数（UTC の時・11/1 以降）
  20 02
  20 06
  22 09
   2 12
   2 13
--- 直近の 0 件の回の前後（重複を落として 20 行）
[2026-11-10T07:25:34.354Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-10T07:25:47.809Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-10T07:26:01.250Z]   @<伏せ>: フォロー中のボタンが無い — {"path":"/<伏せ>","suspended":false,"notfound":true,"locked":false,"empty":false,"follow_btns":"25073877-follow:フォロー | 
[2026-11-10T07:26:14.920Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-10T07:26:28.481Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-10T07:26:41.954Z]   @<伏せ>: **フォローしていない**（一覧の取り込み間違い。押さない・覚えた）
[2026-11-10T07:26:41.983Z] reply-followers.json に反映: 8 件
[2026-11-10T07:26:41.983Z] === 外した: 15 件 / 候補 33 件（今日のフォロー 5 件） / **一覧に混ざっていた未フォロー 16 件** ===
[2026-11-10T09:45:05.289Z] === follow-balance start (dry=false min=20 max=20 grace=1d inactive=30d big=5000) ===
[2026-11-10T09:45:24.416Z] /home が空。開き直す
[2026-11-10T09:45:39.632Z] 自分のハンドルが画面から読めない → heng_ji31590 を使う（x395）
[2026-11-10T09:45:51.417Z] フォロー中: 0 件（12 秒）
[2026-11-10T09:45:51.418Z] **0 件しか読めない。ページが壊れている。何もしない。**
--- 読めた回の「フォロー中: N 件」（直近 10 回）
フォロー中: 553 件（44 秒）
フォロー中: 553 件（44 秒）
フォロー中: 0 件（12 秒）
フォロー中: 0 件（12 秒）
フォロー中: 590 件（46 秒）
フォロー中: 590 件（46 秒）
フォロー中: 568 件（45 秒）
フォロー中: 568 件（45 秒）
フォロー中: 0 件（12 秒）
フォロー中: 0 件（12 秒）
```

## ② competitor-follower-follow
```
  "EnvironmentVariables" => {
    "COMPETITOR_FOLLOW_DAILY_CAP" => "30"
    "FORCE_RUN" => "1"
    "PATH" => "/usr/local/bin:/usr/bin:/bin"
  }
  "Label" => "ai.openclaw.competitor-follower-follow"
  "ProgramArguments" => [
    0 => "/usr/local/bin/node"
    1 => "/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js"
  ]
  "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow-err.log"
  "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow.log"
  "StartCalendarInterval" => [
    0 => {
      "Hour" => 11
      "Minute" => 30
    }
    1 => {
      "Hour" => 18
      "Minute" => 30
    }
  ]
}
--- ログ（直近 40 行・重複を落とす）
[2026-11-09T15:25:14.327Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-11-09T15:25:47.279Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
[2026-11-09T15:26:20.112Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-11-09T15:26:53.024Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
[2026-11-09T15:27:25.944Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:27:58.727Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:28:31.541Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:29:04.349Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:29:37.153Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:30:09.955Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:30:42.748Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:31:15.537Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:31:48.420Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-11-09T15:32:18.429Z] === end: 1/18 OK ===
=== end: 1/18 OK ===
[2026-11-10T02:30:05.267Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/3) cap=30 ===
[2026-11-10T02:30:23.426Z] scraped 26 followers from @<伏せ>
scraped 26 followers from @<伏せ>
[2026-11-10T02:30:23.427Z] new targets (after dedup): 8
[2026-11-10T02:30:30.245Z]   @<伏せ>: ✅
  @<伏せ>: ✅
[2026-11-10T02:31:05.340Z]   @<伏せ>: ❌ follower count out of range (0, need 10-50000)
[2026-11-10T02:31:39.777Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-11-10T02:32:14.251Z]   @<伏せ>: ❌ refollow blacklist (manually unfollowed in past)
[2026-11-10T02:32:48.755Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): masa14231423
[2026-11-10T02:33:22.639Z]   @<伏せ>: ❌ follower count out of range (1, need 10-50000)
  @<伏せ>: ❌ follower count out of range (1, need 10-50000)
[2026-11-10T02:33:57.144Z]   @<伏せ>: ❌ follower count out of range (1, need 10-50000)
  @<伏せ>: ❌ follower count out of range (1, need 10-50000)
[2026-11-10T02:34:33.190Z]   @<伏せ>: ❌ follower count out of range (122000, need 100-50000)
  @<伏せ>: ❌ follower count out of range (122000, need 100-50000)
[2026-11-10T02:35:03.209Z] === end: 1/8 OK ===
[2026-11-10T09:30:05.291Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/3) cap=30 ===
[2026-11-10T09:30:22.792Z] scraped 0 followers from @<伏せ>
[2026-11-10T09:30:22.793Z] new targets (after dedup): 0
--- 見る先のリスト・既に見た記録（ファイル名と件数）
-rw-r--r--    1 ny  staff    97916 Nov 10 16:23 followed.json
```
