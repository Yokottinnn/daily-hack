# 競合フォロワー追跡の種アカウント設定

**このレポートが作られた時刻: 2026-09-20 16:14:15 JST**

> x93 で、**種アカウントによって返り率が 6 倍 違う**と分かった。
> 下位 3 つ で 99 件 フォローして返りは 7 人。上位並みなら約 26 人で、**差は +19 人。**
>
> **消す前に、一覧の場所と回し方を実物で確かめる。**

**読むだけ。書き換えない。**

## 1. `competitor-follower-follow` は何を実行しているか

```
  plist 更新: 2026-09-05 17:29

  --- ProgramArguments ---
    Array {
        /usr/local/bin/node
        /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js
    }

  --- EnvironmentVariables（CAP など）---
    Dict {
        COMPETITOR_FOLLOW_DAILY_CAP = 30
        PATH = /usr/local/bin:/usr/bin:/bin
        FORCE_RUN = 1
    }

  --- 予定 ---
    Array { Dict { Hour = 11 Minute = 30 } Dict { Hour = 18 Minute = 30 }}
```

## 2. **種アカウントの一覧はどこにあるか**

```
  --- data/ の中で competitor / seed を名前に持つもの ---
    follower-target-config.json                    2026-08-22 19:37
    follower-target-config.json.bak                2026-08-22 19:37
    quick-reply-targets.json                       2026-08-15 19:25

  --- 実際に知っている種の名前でファイルを探す ---
    himawari56757          /Users/ny/.openclaw/workspace/data/following-snapshots/2026-06-05.json /Users/ny/.openclaw/workspace/data/influencers.json /Users/ny/.openclaw/workspace/data/unfollow-whitelist.json 
    tokufree3              /Users/ny/.openclaw/workspace/data/following-snapshots/2026-06-05.json /Users/ny/.openclaw/workspace/data/following-snapshots/2026-06-03.json /Users/ny/.openclaw/workspace/data/following-snapshots/2026-05-31.json 
    money_yossy            /Users/ny/.openclaw/workspace/data/comment-state.json /Users/ny/.openclaw/workspace/data/incoming-replies-handled.json /Users/ny/.openclaw/workspace/data/followed.json 
    POIKATSU_OTAKE         /Users/ny/.openclaw/workspace/data/comment-state.json /Users/ny/.openclaw/workspace/data/influencers.json /Users/ny/.openclaw/workspace/data/incoming-reply-state.json 
    ukk_hx                 /Users/ny/.openclaw/workspace/data/influencers.json /Users/ny/.openclaw/workspace/data/unfollow-whitelist.json /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js 
    haiji_doctor           /Users/ny/.openclaw/workspace/data/influencers.json /Users/ny/.openclaw/workspace/data/incoming-reply-state.json /Users/ny/.openclaw/workspace/data/post_queue.json 
    okamiler_pn            /Users/ny/.openclaw/workspace/data/influencers.json /Users/ny/.openclaw/workspace/data/post_queue.json /Users/ny/.openclaw/workspace/data/unfollow-whitelist.json 
```

**同じファイルが 7 件 すべてに出てくるなら、そこが一覧。**
散らばっているなら、回し方も別の場所にある。

## 3. 一覧の中身と、**回し方**

```
  一覧: /Users/ny/.openclaw/workspace/data/following-snapshots/2026-06-05.json
  62 行 / 2026-06-06 00:55

  --- 構造（キーと件数）---
    taken_at                 "2026-06-05T15:55:41.289Z"
    username                 "heng_ji31590"
    count                    56
    following                配列 56 件

    --- following の中身 ---
      "1UNIApjv3r1051"
      "1oku_made"
      "1xQ12jhpZeUJBRD"
      "2778adg"
      "7cd2y"
      "AO_flower666"
      "After_All_Lucky"
      "Butokumaru_naro"
      "Cute1_RinRin"
      "E5xjMvdLPL26078"
      "F838F0203"
      "GpYalaz2ow97965"
      "Kaosu_099"
      "Key4pso2"

  --- 「次にどれを使うか」を決めている箇所 ---
    /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js:6: * Daily rotation: day-of-week mod len(competitors) で 1 competitor 選定、 follower list 先頭から
    /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js:119:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITO
    /Users/ny/.openclaw/workspace/scripts/follower-daily-report.js:192:    lines.push(":rotating_light: *5日連続 pace 遅れ検知 → v7.1 tactics 発動候補:*");
    /Users/ny/.openclaw/workspace/scripts/canary-silent-gap.js:108:  const msg = `<@${OWNER}> :rotating_light: *canary: pipeline 全滅 検知* — 直近 6h に post/reply/follow
```

## 4. `hashtag-follow` は上限の**何 % しか使っていないか**

```
  --- EnvironmentVariables ---
    Dict {
        HASHTAG_FOLLOW_DAILY_CAP = 90
        PATH = /usr/local/bin:/usr/bin:/bin
        FORCE_RUN = 1
    }

  --- 直近のログ（何件 拾って何件 打ったか）---
    [2026-09-20T01:18:05.333Z] picks: 4 authors
    picks: 4 authors
    [2026-09-20T01:18:08.246Z]   @rakutenplay: ❌ follower count out of range (102000, need 100-50000)
      @rakutenplay: ❌ follower count out of range (102000, need 100-50000)
    [2026-09-20T01:18:41.127Z]   @GinzaKawaii: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      @GinzaKawaii: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    [2026-09-20T01:19:13.985Z]   @inami_furusato: ❌ inactive (last post 162d ago)
      @inami_furusato: ❌ inactive (last post 162d ago)
    [2026-09-20T01:19:46.897Z]   @tsuruhaofficial: ❌ follower count out of range (297000, need 100-50000)
      @tsuruhaofficial: ❌ follower count out of range (297000, need 100-50000)
    [2026-09-20T01:20:16.908Z] === end: 0/4 OK ===
    === end: 0/4 OK ===
```

**x93 の実測では hashtag-follow は 1 日 最大 3 件**（上限 90）。
**上限ではなく候補の数で止まっている。** 上限を上げても増えない。

## 5. 費用

**設定ファイルとログを読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**種を入れ替える場合も $0。** `competitor-follower-follow` は DOM 操作だけで
LLM を呼ばないため、**フォロー数を変えても API 費用は動かない。**
いまの実測は 1 回 $0.003 ／ 1 日 $0.021 ／ 1 か月 約 $0.63（返信ループのぶん）。
