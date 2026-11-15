# 滞留を片付けるための実態

**このレポートが作られた時刻: 2026-09-15 02:01:24 JST**

> x61 の実測（2026-09-13）: 期限到来 **58 件**（30 日 以上 放置が 19 件）。
> アンフォロー自体は x60 で **3/3 外れる**ことを確認済み。
>
> **外す仕組みは直っている。あとは流し切るだけ。**

**測るだけ。上限を上げない。**

## 1. いま滞留は何件か（**数え直す**。9/13 の数字は古い）

```
  状態ファイル全体            : 374 件
  いまフォロー中の扱い        : 56 件
  **期限到来（滞留）**        : **4 件**
  そのうち 30 日 以上 放置    : 1 件

  滞留のうち相互（返してくれている）: 4 件
  → **相互は外すか残すかで方針が分かれる。** ここで分けて出す

  --- いちばん古い 5 件 ---
    期限 2026-08-10（35 日 超過）  相互=はい  source=competitor-follower
    期限 2026-08-16（29 日 超過）  相互=はい  source=comment-orchestrator
    期限 2026-09-12（1 日 超過）  相互=はい  source=hashtag-follow
    期限 2026-09-14（0 日 超過）  相互=はい  source=competitor-follower
```

## 2. 外すジョブ（**設定の実物**）

```
  ai.openclaw.reply-followers-cleanup: **載っている**
    PID=61743  最後の終了コード=-15
  ai.openclaw.reply-followback-check: **載っている**
    PID=-  最後の終了コード=0
  ai.openclaw.badge-followback: **載っている**
    PID=-  最後の終了コード=0

  --- ai.openclaw.reply-followers-cleanup.plist ---
    更新: 2026-09-13 03:09
    StartInterval        : (無し)
    StartCalendarInterval: 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,0,1 時
    --- 環境変数 ---
```

## 3. 1 回に何件 外す設定か（**スクリプトの実物**）

```
  ══ reply-followers-cleanup.js（100 行 / 09-06 21:32）
    48:  const CLEANUP_MAX_PER_RUN = Number(process.env.CLEANUP_MAX_PER_RUN || 20);
    49:  if (due.length > CLEANUP_MAX_PER_RUN) {
    50:    log(`due ${due.length} → 上限 ${CLEANUP_MAX_PER_RUN} 件に絞る（残りは次回）`);
    51:    due.length = CLEANUP_MAX_PER_RUN;

    scripts: audit-wrong-unfollows.js
    scripts: audit-wrong-unfollows.js.bak18800
    scripts: auto_detect_and_unfollow_inactive.js
    scripts: check-unfollowed-status.js
    scripts: check-unfollowed-status.js.bak18800
    scripts: reply-followers-cleanup.js
    scripts: reply-followers-cleanup.js.bak.20260906-213249
    scripts: revenge-unfollow.js
    scripts: revenge-unfollow.js.bak.20260725-notify-batch2
    scripts: revenge-unfollow.js.bak18800
    scripts: run-unfollow.sh
    scripts: unfollow-cleanup.js
    scripts: unfollow-cleanup.js.bak.20260720-inline-refactor
    scripts: unfollow-cleanup.js.bak.20260720-tab-overload
    scripts: unfollow-cleanup.js.bak.20260725-notify-batch2
    scripts: unfollow-cleanup.js.bak.20260802-24h
    scripts: unfollow-cleanup.js.bak18800
    scripts: unfollow-handle.js
    scripts: unfollow-handle.js.bak-20260913-152559
    scripts: unfollow-handle.js.bak.20260720-goto-commit
    scripts: unfollow-handle.js.bak.20260809
    scripts: unfollow-handle.js.bak18800
    scripts: unfollow-stats-monitor.js
    scripts: unfollow-stats-monitor.js.bak.20260725-slack-notify-migrate
    scripts: unfollow-via-playwright.js
    scripts: unfollow-via-playwright.js.bak.1778505437346
    scripts: unfollow-via-playwright.js.bak.20260524-livecheck-timing
    scripts: unfollow-via-playwright.js.bak.20260524-mega
    scripts: unfollow-via-playwright.js.bak.20260603-engagement-2x
    scripts: unfollow-via-playwright.js.bak.20260604-ghost-precheck
    scripts: unfollow-via-playwright.js.bak.20260607-cdp
    scripts: unfollow-via-playwright.js.bak.20260725-notify-batch2
    scripts: unfollow-via-playwright.js.bak18800
    scripts: unfollow_inactive_batch.js
    scripts: update_followed_after_cleanup.js
```

## 4. 直近の実績（**1 回あたり実際に何件 外せているか**）

```
  17542667 bytes / 最終更新 2026-09-14 05:02

  --- 直近 25 行 ---
    [2026-09-13T06:01:01.788Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:08.965Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:16.190Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:23.408Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:30.581Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:37.817Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:45.045Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:52.238Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:01:59.461Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:06.648Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:13.836Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:21.066Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:28.246Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:35.474Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:42.660Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:49.848Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:02:57.082Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:03:04.324Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:03:11.567Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:03:18.795Z] @<伏せ>: unfollow failed (no unfollow button)
    [2026-09-13T06:03:21.302Z] done
    [2026-09-13T07:00:05.086Z] due 204 → 上限 20 件に絞る（残りは次回）
    [2026-09-13T07:00:05.089Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujy
    [2026-09-13T20:02:20.972Z] due 205 → 上限 20 件に絞る（残りは次回）
    [2026-09-13T20:02:20.975Z] due unfollows: 20 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504,STARPayment07,Kimama_FIRE,hirouma888,gurisusan,furunavi_PR,kageyoshi_maki,harunorikujy

  --- 日ごとの外した数 ---
    日付       起動 外した
    2026-08-07        0        0
    2026-08-08        0        0
    2026-08-09        0        0
    2026-08-10        0        0
    2026-09-06        0        0
    2026-09-07        0        0
    2026-09-08        0        0
    2026-09-09        0        0
    2026-09-12        0        0
    2026-09-13        0        0
```

## 5. 何日で終わるか

**上限 × 頻度 で割るだけ。** 実績が上限に届いていないなら、そちらで割る。

| | 計算 |
| --- | --- |
| 上限どおりに流れた場合 | 滞留 ÷（1 回の上限 × 1 日 の回数） |
| 実績どおりなら | 滞留 ÷ 直近の 1 日 あたり実績 |

**この 2 つは別物。** 上限を実績のように出さない（最上位ルール 2-B）。
数字は上の 1〜4 章から入れる。

## 6. 費用

**JSON・plist・ログを読むだけ。LLM を呼ばない。外さない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**アンフォロー自体も $0**（DOM 操作のみ・LLM を呼ばない）。
上限を上げても API 課金は増えない。増えるのは Mac の CPU 時間と通信だけ。
返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44。
