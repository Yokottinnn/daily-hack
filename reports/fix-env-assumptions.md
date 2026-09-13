# 環境差で転んだ 2 つを直す

**このレポートが作られた時刻: 2026-09-13 10:38:17 JST**

| 転んだところ | 実際のエラー |
| --- | --- |
| `timeout` が macOS に無い | `line 368: timeout: command not found` |
| `node --check` が `.js.new` を弾く | `ERR_UNKNOWN_FILE_EXTENSION: Unknown file extension ".new"` |

**どちらもクラウド（Linux / Node v22）では通っていた。**
動いている実物で確かめずに「確かめたつもり」になっていた。

**このタスクは `timeout` を 1 回も使わない。** 素の bash で打ち切る。

## 0. 前提

```
  3 ループ    : **8 / 8 本**
  CDP         : 健全
  login ロック: 無い
  timeout     : **無い**（だから使わない）
  node        : v24.14.0
  累計の返信  : 859 件
  ai.openclaw.daily-supervisor     ロード済み
  ai.openclaw.mutual-prune         **未ロード**
  ai.openclaw.caffeinate           ロード済み
  com.dailyhack.ops-poller         ロード済み
  com.dailyhack.ops-heartbeat      ロード済み
```

## 1. `mutual-prune.js` を置き直す（一時ファイルも `.js`）

```
  **本体がまだ無い。** x46 を作り直す必要がある。
  x46 の done の印:
    （このタスクからは見えないので、次のタスクで作り直す）
```

## 2. 番人を走らせて `status.json` を作る（**timeout 不使用**）

x47 は `timeout` が無くて落ちた。**今回は素の bash で 10 分 で打ち切る。**

```
  **/Users/ny/.openclaw/workspace/scripts/daily-supervisor.sh が無い／実行できない。**
    -rw-r--r--  1 ny  staff  7243 Sep 13 03:09 /Users/ny/.openclaw/workspace/scripts/daily-supervisor.sh
```

### `status.json`

```json
  {
    "generated_at": "2026-09-12T20:00:06Z",
    "date_jst": "2026-09-13",
    "cdp_healthy": true,
    "login_lock": false,
    "fixed": "",
    "not_run": "mutual-prune",
    "jobs": [{"job":"comment-warmup","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"competitor-follower-follow","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"hashtag-follow","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"badge-followback","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"reply-followback-check","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"reply-followers-cleanup","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":true},{"job":"mutual-prune","loaded":false,"ran_today":false,"attempts":0,"needs_cdp":true},{"job":"incoming-reply-watcher","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":false},{"job":"pipeline-heartbeat","loaded":true,"ran_today":true,"attempts":0,"needs_cdp":false}]
  }
```

## 3. 候補プールを埋め直す（`trend-detect`・**LLM 不使用・$0**）

x43 で orchestrator が**何も言わずに終わった。** 入口が空だったため。
**修理も禁止リストも、候補が無ければ出番が来ない。**

```
    {"ok":true,"count":0,"candidates":[]}

    --- 件数らしき行 ---
      {"ok":true,"count":0,"candidates":[]}
```

## 4. 候補が在れば叩く（最大 4 件・約 $0.012）

```
  走らせる前の累計: **859 件**
    [2026-09-13T10:41:19] === comment orchestrator start (max_picks=4, reply_follow_cap=10) ===
    [2026-09-13T10:44:20] no candidates

  走らせる前: 859 件 → 後: 859 件
  **今回 出た数: 0 件**
```

## 5. 止まっているフォロー 2 本とアンフォローを走らせる（**$0**）

**下限は下げない。** なぜフォロワー 3〜7 人 ばかり集まるのかを見るために実数を取る。

### `competitor-follower-follow`

```
  実行前: 2682 行 / 最終更新 2026-09-13 10:44
  実行後: 2692 行（**+10 行**）

  --- 末尾 14 行 ---
    [2026-09-13T01:44:13.827Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
      @<伏せ>: ❌ no follow button (private/blocked/deleted)
    [2026-09-13T01:44:46.536Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
      @<伏せ>: ❌ no follow button (private/blocked/deleted)
    [2026-09-13T01:45:06.608Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=3/6) cap=30 ===
    [2026-09-13T01:45:25.058Z] scraped 60 followers from @<伏せ>
    scraped 60 followers from @<伏せ>
    [2026-09-13T01:45:25.059Z] new targets (after dedup): 30
    new targets (after dedup): 30
    [2026-09-13T01:45:27.940Z]   @<伏せ>: ❌ inactive (last post 100d ago)
      @<伏せ>: ❌ inactive (last post 100d ago)
    [2026-09-13T01:46:00.778Z]   @<伏せ>: ❌ refollow blacklist (manually unfollowed in past)
      @<伏せ>: ❌ refollow blacklist (manually unfollowed in past)

  --- 内訳 ---
    out of range             645 件
    followed                  52 件
    unfollowed                52 件

  --- range 外だった実際のフォロワー数（直近 12 件） ---
    0 0 0 0 67000 67000 0 0 0 0 3 3 
```
### `hashtag-follow`

```
  実行前: 1609 行 / 最終更新 2026-09-13 10:43
  実行後: 1611 行（**+2 行**）

  --- 末尾 14 行 ---
    [2026-09-13T01:19:15.613Z]   @<伏せ>: ❌ inactive (last post 35d ago)
      @<伏せ>: ❌ inactive (last post 35d ago)
    [2026-09-13T01:19:48.411Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    [2026-09-13T01:20:21.306Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
      @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
    [2026-09-13T01:20:54.102Z]   @<伏せ>: ❌ inactive (last post 255d ago)
      @<伏せ>: ❌ inactive (last post 255d ago)
    [2026-09-13T01:21:24.112Z] === end: 1/6 OK ===
    === end: 1/6 OK ===
    [2026-09-13T01:43:29.642Z] === hashtag-follow start (cap=90) ===
    === hashtag-follow start (cap=90) ===
    [2026-09-13T01:46:21.487Z] === hashtag-follow start (cap=90) ===
    === hashtag-follow start (cap=90) ===

  --- 内訳 ---
    out of range              94 件
    already                  135 件
    failed                   188 件

  --- range 外だった実際のフォロワー数（直近 12 件） ---
    9 9 103000 103000 102000 102000 102000 102000 3 3 102000 102000 
```
### `reply-followers-cleanup`

```
  実行前: 275929 行 / 最終更新 2026-09-13 10:47
  実行後: 275934 行（**+5 行**）

  --- 末尾 14 行 ---
    [2026-09-13T01:46:37.640Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:46:44.891Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:46:52.080Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:46:59.254Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:06.442Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:13.616Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:20.875Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:28.187Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:35.410Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:47:36.634Z] due 204 → 上限 20 件に絞る（残りは次回）
    [2026-09-13T01:47:36.636Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujyou,new_mono_koto,moyana75,pref_yamagata,
    [2026-09-13T01:48:33.669Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:48:40.859Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T01:48:48.023Z] @<伏せ>: unfollow failed (no unfollow button)

  --- 内訳 ---
    followed                  16 件
    unfollowed                16 件
    no unfollow button     66015 件
    failed                 79669 件
```

## 6. まとめ（**一次情報だけ**）

```
  返信 累計: 859 件
  reply-followers.json       338 件 / 最終更新 09-13 10:18
  followed.json              173 件 / 最終更新 09-13 00:51
```

## 7. 費用

| | 金額 |
| --- | --- |
| trend-detect / フォロー / アンフォロー / 番人 | **$0**（LLM 不使用） |
| 返信の生成（最大 4 件） | 最大 **$0.012** |

**このタスクは 1 回きり。** 定時の返信ループは **推定** 1 日 約 $0.19 ／
1 か月 約 $5.8（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
�） | 最大 **$0.012** |

**このタスクは 1 回きり。** 定時の返信ループは **推定** 1 日 約 $0.19 ／
1 か月 約 $5.8（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
