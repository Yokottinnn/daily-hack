# 本日の実数 ＋ アンフォローが外せない理由 ＋ 追いかけ先

**このレポートが作られた時刻: 2026-09-13 11:04:07 JST**

**ボタンを押さない。アンフォローもフォローもしない。LLM を呼ばない（$0）。**

## 1. 本日の実数（**一次情報だけ**）

```
  返信 累計      : 859 件
  返信 本日(2026-09-13): **2 件**
  最後の 1 件    : 2026-09-12T18:06:31.876Z

  --- 本日 出た返信 ---
    2026-09-12T18:06:12.100Z  https://x.com/heng_ji31590/status/2098835572601286873
    2026-09-12T18:06:31.876Z  https://x.com/heng_ji31590/status/2098835656172843441
```

```
  --- 状態ファイル（フォロー関連） ---
  reply-followers.json          338 件 / 最終更新 2026-09-13 11:03
  followed.json                 173 件 / 最終更新 2026-09-13 00:51
  mutual-prune-state.json    無し

  --- 本日 動いたジョブ（ログに今日の行が在るか） ---
  comment-warmup               **本日 動いた** / 最終更新 09-13 03:06
  competitor-follower-follow   **本日 動いた** / 最終更新 09-13 11:01
  hashtag-follow               **本日 動いた** / 最終更新 09-13 10:49
  badge-followback             本日は無し      / 最終更新 09-13 00:51
  reply-followback-check       **本日 動いた** / 最終更新 09-13 01:15
  reply-followers-cleanup      **本日 動いた** / 最終更新 09-13 11:03
  incoming-reply-watcher       **本日 動いた** / 最終更新 09-13 11:00
  pipeline-heartbeat           本日は無し      / 最終更新 09-13 08:00
  daily-supervisor             本日は無し      / 最終更新 09-13 05:00
  mutual-prune                 **本日 動いた** / 最終更新 09-13 10:55
```

## 2. アンフォローが外せない理由を確定する（**押さない**）

x09 は `playwright`（`-core` ではない）で落ちて答えが出ていない。**今回は `playwright-core`。**

| 候補 | 見分け方 |
| --- | --- |
| **A. 状態ファイルが古い** | 期限到来の相手が **`/following` に居ない** |
| **B. セレクタが古い** | `/following` に**居るのに**「フォロー中」を掴めていない |

```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x53-count-and-fix-unfollow.sh: line 69: 71241 Terminated: 15          "$@" > "$outf" 2>&1
  期限到来の古い順 4 件を見る
  ログイン: 生きている（@<伏せ>）
  実際にフォロー中: 170 件
  
    @<伏せ>
      期限: 2026-05-16T04:03:05.644Z
      /following に居る: **いいえ**
      画面のボタン: [{"testid":"1563537713638559744-follow","text":"フォロー"},{"testid":"1801910088778825729-follow","text":"フォロー"},{"testid":"2096296929814835200-follow","text":"フォロー"}]
  
    @<伏せ>
      期限: 2026-05-16T10:03:07.780Z
      /following に居る: **はい**
      画面のボタン: [{"testid":"2040770556531011584-unfollow","text":"フォロー中"},{"testid":"1058380986843447296-follow","text":"フォロー"},{"testid":"1381178320700669954-follow","text":"フォロー"}]
  
    @<伏せ>
      期限: 2026-05-19T01:17:38.602Z
      /following に居る: **はい**
      画面のボタン: [{"testid":"1829403620011540480-unfollow","text":"フォロー中"},{"testid":"1244294814071263233-follow","text":"フォロー"},{"testid":"1381178320700669954-follow","text":"フォロー"}]
  
    @<伏せ>
      期限: 2026-05-19T01:18:47.181Z
      /following に居る: **はい**
      画面のボタン: [{"testid":"1518145659270213632-unfollow","text":"フォロー中"},{"testid":"1601979989078904832-follow","text":"フォロー"},{"testid":"1605018024708173824-follow","text":"フォロー"}]
  
  === 判定 ===
    /following に居る: 3 件 / 居ない: 1 件
    → **B. フォロー中なのに外せていない。** 上のボタンの実物を見て
       セレクタを合わせる（`Following` / `フォロー中` が在るか）。
```

```
  --- 期限到来の古さ（状態ファイルから） ---
    期限到来: 322 件
      0〜6日   63 件
      7〜13日  5 件
      14〜29日 31 件
      30日以上 223 件
    いちばん古い: 2026-05-16
```

## 3. フォロー 2 本の追いかけ先（**下限は下げない**）

復帰はしたが、**候補のフォロワー数が 3〜7 人 で全部 弾かれる**問題は残っている。
フォロワー 3 人 を追っても返りはほぼ無い。**追いかけ先が古くないか**を見る。

```
  --- 追いかけ先の一覧ファイル ---

  --- data/ で follow / target を含むファイル ---
    badge-followback-state.json
    follow-watchdog-state.json
    followed.json
    follower-daily-report-state.json
    follower-history.json
    follower-snapshots
    follower-target-config.json
    follower-target-config.json.bak
    following-snapshots
    post_queue.json.bak.20260515-hashtag-reduce
    quick-reply-targets.json
    refollow-blacklist.json
    refollow-may18-done.flag
    reply-followers.json
    unfollow-cleanup-state.json
```

```
  --- 弾かれた候補のフォロワー数の分布（直近のログ全体） ---
  [competitor-follower-follow]
    10 未満: 347 件 / 10〜99: 0 件 / 100〜999: 0 件 / 1000 以上: 298 件
    直近 12 件の実数: 0 0 0 0 67000 67000 0 0 0 0 3 3 
    本日 フォローできた数: 277 件（ログ由来・**一次情報ではない**）
  [hashtag-follow]
    10 未満: 4 件 / 10〜99: 0 件 / 100〜999: 0 件 / 1000 以上: 90 件
    直近 12 件の実数: 9 9 103000 103000 102000 102000 102000 102000 3 3 102000 102000 
    本日 フォローできた数: 51 件（ログ由来・**一次情報ではない**）
```

## 4. 費用

**LLM を一切 呼ばない。DOM を読むだけ。ボタンを押さない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

定時の返信ループは **推定** 1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8
（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
