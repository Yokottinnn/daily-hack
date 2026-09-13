# 測れるようにする（フォロー返し・実態の記録）

**このレポートが作られた時刻: 2026-09-13 19:44:13 JST**

> `reply-followers.json` は **`followed_at` しか持っていない。**
> だからフォロー返し率も、いまフォローしているかも分からない。
>
> 期限到来は **328 件** だが、**実際にフォローしているのは 170 件**。
> **半分以上は既に外れているのに、外そうとして失敗し続けていた。**

**フォローもアンフォローもしない。読んで記録するだけ。**

## 0. 前提

```
  CDP: 健全
  reply-followers.json: 在る（165093 bytes）
  いまのキー:
    followed_at           346 件
    followback_status     346 件
    source                346 件
    still_following       346 件
    follows_back          346 件
    checked_at            346 件
    scheduled_unfollow_at 333 件
    followback_judgment_at331 件
    unfollowed_at         288 件
    unfollow_source       272 件
    comment_id            135 件
    revenge_checked_at    63 件
    seed_post_url         39 件
    seed_engagement       39 件
    late_followback_at    24 件
    incoming_reply_id     4 件
    revenge_check_error   1 件
```

## 1. `/following` と `/followers` を読んで記録する

| 足すキー | 意味 |
| --- | --- |
| `still_following` | **いまもフォローしているか** |
| `follows_back` | **相手がこちらをフォローしているか** |
| `checked_at` | いつ確かめたか |

既に外れているものには `unfollowed_at` を入れて、**期限到�/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x61-record-followback-truth.sh: line 72: 17407 Terminated: 15          "$@" > "$outf" 2>&1
  いまフォロー中 : **173 件**
  いまフォロワー : **254 件**
  
  === 記録した ===
    状態ファイルの件数        : 346 件
    いまもフォローしている    : **59 件**
    既に外れている            : 287 件（うち **272 件** に印を付けた）
    相手がこちらをフォロー    : **56 件**
    **フォロー返し率: 16.2%**（56 / 346）
  
    ※ この返し率は「状態ファイルに載っている相手のうち、いま相互の割合」。
       フォローした直後は返ってこないので、**低めに出る。**

  JSON: OK
```

## 2. 記録した後のキー

```
  followed_at           346 件
  followback_status     346 件
  source                346 件
  still_following       346 件
  follows_back          346 件
  checked_at            346 件
  scheduled_unfollow_at 333 件
  followback_judgment_at331 件
  unfollowed_at         288 件
  unfollow_source       272 件
  comment_id            135 件
  revenge_checked_at    63 件
  seed_post_url         39 件
  seed_engagement       39 件
  late_followback_at    24 件
  incoming_reply_id     4 件
  revenge_check_error   1 件
```

## 3. 本当の滞留数（**水増しを消した後**）

```
  期限到来: **58 件**（30 日以上 放置が 19 件）

  **前: 328 件**（いまフォローしているかを見ていなかった）
```

## 4. 次にやること（**このタスクでは触らない**）

**フォロワー数の記録は、ここでは入れていない。**
1 件ずつプロフィールを開くと 344 件 で 20 分 かかり、ルール 15 に反する。

**フォローする瞬間に記録するのが正しい。**
`competitor-follower-follow` と `hashtag-follow` は、**弾くときに
フォロワー数を読んでいる**（`out of range (67000` と出せている）。
**通したときにも同じ数字を書けば、帯ごとの返し率が出せる。**

## 5. 費用

**LLM を一切 呼ばない。** DOM を読んで JSON に書くだけ。
**フォローもアンフォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

定時の返信ループは **推定** 1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8
（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
