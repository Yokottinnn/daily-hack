# どの経路が何人 連れてきているか

**このレポートが作られた時刻: 2026-09-20 16:10:04 JST**

> `follower-snapshot` を戻して、**実数が 264** だと分かった（227 ではなかった）。
> **目標 300 まで 36 人 / 10 日 ＝ 3.6 人/日。** いまのペース 3.08 人/日 の約 1.17 倍。
>
> **量を増やす前に、経路ごとの返り率を見る。** 返りの悪い経路を増やしても
> フォロー数が増えるだけで、フォロワーは増えない。

**測るだけ。CAP を触らない。フォローしない。**

## 1. `reply-followers.json` に**実際に入っているキー**（推測しない）

```
  レコード数: 437

  --- キーと、値が入っている件数 ---
    followed_at                437 件
    followback_status          437 件
    source                     437 件
    scheduled_unfollow_at      428 件
    followback_judgment_at     428 件
    still_following            346 件
    follows_back               346 件
    checked_at                 346 件
    unfollowed_at              290 件
    unfollow_source            274 件
    comment_id                 148 件
    followers_at_follow        90 件
    following_at_follow        90 件
    phase_at_follow            77 件
    revenge_checked_at         63 件
    seed_post_url              43 件
    seed_engagement            43 件
    late_followback_at         24 件
    incoming_reply_id          5 件
    unfollow_reason            2 件
    revenge_check_error        1 件

  --- 経路らしいキーの値 ---
    source:
      comment-orchestrator             148 件
      competitor-follower:himawari56757 54 件
      hashtag-follow                   43 件
      competitor-follower:tokufree3    42 件
      competitor-follower:money_yossy  35 件
      competitor-follower:POIKATSU_OTAKE 34 件
      competitor-follower:ukk_hx       30 件
      competitor-follower:haiji_doctor 24 件
      competitor-follower:okamiler_pn  22 件
      incoming-reply-watcher           5 件
```

## 2. 経路ごとの返り率（**mature ＝ フォローから 72 時間 以上**）

```
    経路                            件数   mature  返った  返り率
    ------------------------------------------------------------------
    comment-orchestrator            148     146      32   21.9%
    competitor-follower:himawari56757   54      50      13   26.0%
    hashtag-follow                   43      43       6   14.0%
    competitor-follower:tokufree3    42      37       6   16.2%
    competitor-follower:money_yossy   35      35       3    8.6%
    competitor-follower:POIKATSU_OTAKE   34      30       3   10.0%
    competitor-follower:ukk_hx       30      24       1    4.2%
    competitor-follower:haiji_doctor   24      24       5   20.8%
    competitor-follower:okamiler_pn   22      22       4   18.2%
    incoming-reply-watcher            5       5       2   40.0%  ← 件数が足りない。判断しない
```

**mature が 20 件 未満の行は率を信じない。** 1 件の増減で数 % 動く。

## 3. 直近 14 日、**日ごとに何件 フォローしたか**

```
    2026-09-06  計   8   competitor-follower:tokufree3=6  hashtag-follow=2
    2026-09-07  計   3   competitor-follower:okamiler_pn=3
    2026-09-08  計   9   competitor-follower:money_yossy=8  comment-orchestrator=1
    2026-09-09  計  10   competitor-follower:haiji_doctor=9  hashtag-follow=1
    2026-09-12  計   6   competitor-follower:POIKATSU_OTAKE=5  comment-orchestrator=1
    2026-09-13  計  15   competitor-follower:tokufree3=10  comment-orchestrator=3  hashtag-follow=2
    2026-09-14  計  23   competitor-follower:okamiler_pn=19  hashtag-follow=3  comment-orchestrator=1
    2026-09-15  計  15   competitor-follower:money_yossy=10  comment-orchestrator=4  hashtag-follow=1
    2026-09-16  計  13   competitor-follower:haiji_doctor=10  comment-orchestrator=2  incoming-reply-watcher=1
    2026-09-17  計  19   competitor-follower:himawari56757=15  comment-orchestrator=4
    2026-09-18  計   6   competitor-follower:ukk_hx=6
    2026-09-19  計   4   competitor-follower:POIKATSU_OTAKE=4
    2026-09-20  計   5   competitor-follower:tokufree3=5
```

**上限（CAP）は安全弁であって実績ではない。** 上の実数と比べて、
**上限に当たっていないなら「増やす」の余地は上限ではなく候補の数にある。**

## 4. フォロワーの実推移（**一次情報**）

```
    2026-08-23   208
    2026-08-24   210  (+2)
    2026-08-25   212  (+2)
    2026-08-26   211  (-1)
    2026-08-27   214  (+3)
    2026-08-28   214  (+0)
    2026-08-29   215  (+1)
    2026-09-07   224  (+9)
    2026-09-08   227  (+3)
    2026-09-20   264  (+37)

  --- 直近の記録に含まれる disappeared / new ---
    2026-09-07  計 224  （去った 4 ／ 来た 13）
    2026-09-08  計 227  （去った 3 ／ 来た 6）
    2026-09-20  計 264  （去った 11 ／ 来た 48）
```

**去った数も見る。** 来た数だけ増やしても、去る数が同じだけ増えれば止まる。

## 5. 費用

**JSON とログを読んで数えるだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**量を増やす判断をするときは、増えたあとの月額を必ず出す**（最上位ルール 2-B）。
いまの実測は 1 回 $0.003 ／ 1 日 $0.021 ／ 1 か月 約 $0.63。
`MAX_PICKS` を 4 → 6 にすると 1 か月 約 $0.95、4 → 8 で約 $1.26 になる見込み
（**推定**。前提は「1 件 $0.003 × 1 日 4 回 × picks」で、通過率は実績どおりとする）。
フォロー・アンフォロー系は **$0**（DOM 操作のみ）なので、
`competitor-follower-follow` と `hashtag-follow` を増やしても **API 費用は増えない。**
