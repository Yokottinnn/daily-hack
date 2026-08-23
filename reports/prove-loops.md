# 4 ループが実際に動いたかの証明（2026-08-23 18:15 JST）

> **ロードされていること＝動いていること、ではない。**
> 7/07〜8/09 の competitor-follower-follow は載ったまま 1 件も実行していなかった。
> ここでは**実行の痕跡**だけで判定する。

## 0. 動く前提: Chrome CDP

{
   "Browser": "Chrome/140.0.7339.207",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (Macintosh; Intel M
→ **18810 応答あり。** ブラウザ経由の操作は成立しうる。

## 1. ジョブごとの実行痕跡

### ai.openclaw.auto-thread-chainifier
- 予定発火（JST）: 02:00
- launchctl: **載っていない**
- ログ最終更新: 2026-08-23 02:00（16 時間前） 89 行
- 本日の記録: 0 行
- **判定: 予定時刻を過ぎているのに本日の記録が無い → 動いていない**
- 直近 5 行:
      [2026-08-09T17:00:04.822Z] no entries to chainify
      [2026-08-22T15:11:03.574Z] no entries to chainify
      no entries to chainify
      [2026-08-22T17:00:05.091Z] no entries to chainify
      no entries to chainify

### ai.openclaw.badge-followback
- 予定発火（JST）: 00:50
- launchctl: 載っている / pid=- last_exit=0
- ログ最終更新: 2026-08-23 00:50（17 時間前） 261 行
- 本日の記録: 0 行
- **判定: 予定時刻を過ぎているのに本日の記録が無い → 動いていない**
- 直近 5 行:
      [2026-08-22T15:50:27.552Z] followed back @komemama_otoku
      followed back @komemama_otoku
      [2026-08-22T15:50:36.135Z] followed back @poodill3
      followed back @poodill3
      {"ok":true,"scanned":203,"verified":65,"followed_back":2,"handles":["komemama_otoku","poodill3"]}

### ai.openclaw.auto-detect-and-unfollow-inactive
- 予定発火（JST）: 22:30
- launchctl: 載っている / pid=- last_exit=0
- ログ: **存在しない → 一度も動いていない**

### ai.openclaw.competitor-follower-follow
- 予定発火（JST）: 11:30,18:30
- launchctl: 載っている / pid=- last_exit=0
- ログ最終更新: 2026-08-23 11:30（6 時間前） 1410 行
- 本日の記録: 1 行
- **判定: 本日 実行された**
- 直近 5 行:
      [2026-08-09T02:30:00.251Z] === competitor-follower SKIP (day=0, Sun/Mon skip policy) ===
      [2026-08-09T08:46:48.005Z] === competitor-follower SKIP (day=0, Sun/Mon skip policy) ===
      [2026-08-09T09:30:05.363Z] === competitor-follower SKIP (day=0, Sun/Mon skip policy) ===
      [2026-08-23T02:30:05.373Z] === competitor-follower SKIP (day=0, Sun/Mon skip policy) ===
      === competitor-follower SKIP (day=0, Sun/Mon skip policy) ===

### ai.openclaw.hashtag-follow
- 予定発火（JST）: 10:15,17:00
- launchctl: 載っている / pid=- last_exit=0
- ログ最終更新: 2026-08-23 17:00（1 時間前） 1057 行
- 本日の記録: 2 行
- **判定: 本日 実行された**
- 直近 5 行:
      [2026-08-09T11:00:05.073Z] === hashtag-follow SKIP (day=0, Sun/Mon skip policy) ===
      [2026-08-23T01:15:05.194Z] === hashtag-follow SKIP (day=0, Sun/Mon skip policy) ===
      === hashtag-follow SKIP (day=0, Sun/Mon skip policy) ===
      [2026-08-23T08:00:05.100Z] === hashtag-follow SKIP (day=0, Sun/Mon skip policy) ===
      === hashtag-follow SKIP (day=0, Sun/Mon skip policy) ===

## 2. 結果の数字（動いていれば動く）

- フォロー済み（data/followed.json）: 155 件 / 更新 08-23 00:50
- 受信リプ処理済み（data/incoming-replies-handled.json）: 2 件 / 更新 08-10 00:06
- フォロワー推移（直近7日分の記録）:
      2026-08-02  192
      2026-08-06  192
      2026-08-07  195
      2026-08-08  198
      2026-08-09  206
      2026-08-21  207
      2026-08-22  206

## 3. 返信ジョブの停止状態（022 が効いたか）

  ai.openclaw.comment-warmup                 停止
  ai.openclaw.incoming-reply-watcher         停止
  ai.openclaw.auto-thread-chainifier         停止
