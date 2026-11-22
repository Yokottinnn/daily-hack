# フォローした瞬間にフォロワー数を記録する

**このレポートが作られた時刻: 2026-09-13 19:58:29 JST**

> x63 の実測: `follow-handle.js` は成功時に `profile` を返している。
> `profile = { bio, follower_count, following_count, last_post_age_days }`
>
> **数字は手元に在るのに、呼び出し側が捨てていた。**

**しきい値は触らない。足すだけ。**

## 0. 当てる前

```
  competitor-follower-follow.js     168 行 / 2026-08-09 17:52
    既に入っている箇所: 0
  hashtag-follow.js                 174 行 / 2026-08-02 19:39
    既に入っている箇所: 0
```

## 1. 足す 3 つ

| キー | 中身 |
| --- | --- |
| `followers_at_follow` | フォローした時点の相手のフォロワー数 |
| `following_at_follow` | 同・フォロー数（比率を後から出せる） |
| `phase_at_follow` | `follow-handle` が判定した Phase（1/2/3） |

```
  competitor-follower-follow.js    : 当てた（検査待ち）
  hashtag-follow.js                : 当てた（検査待ち）

  --- 検査して置き換える（**構文が通ったものだけ**） ---
    competitor-follower-follow.js: **置き換えた**（退避 competitor-follower-follow.js.bak-20260913-195829）
    hashtag-follow.js: **置き換えた**（退避 hashtag-follow.js.bak-20260913-195829）
```

## 2. 当てた後（**実物**）

```javascript
// ══ competitor-follower-follow.js
 149|           const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 150|           rf[h] = {
 151|             followed_at: new Date().toISOString(),
 152|             followback_status: "pending",
 153|             followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,
 154|             following_at_follow: (r.profile && typeof r.profile.following_count === "number") ? r.profile.following_count : null,
 155|             phase_at_follow: (typeof r.phase === "number") ? r.phase : null,
 156|             source: `competitor-follower:${competitor}`,
 157|           };
 158|           fs.writeFileSync(REPLY_FOLLOWERS_PATH, JSON.stringify(rf, null, 2));

// ══ hashtag-follow.js
 153|           const rf = fs.existsSync(REPLY_FOLLOWERS_PATH) ? JSON.parse(fs.readFileSync(REPLY_FOLLOWERS_PATH, "utf8")) : {};
 154|           rf[p.author] = {
 155|             followed_at: new Date().toISOString(),
 156|             followback_status: "pending",
 157|             followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,
 158|             following_at_follow: (r.profile && typeof r.profile.following_count === "number") ? r.profile.following_count : null,
 159|             phase_at_follow: (typeof r.phase === "number") ? r.phase : null,
 160|             source: "hashtag-follow",
 161|             seed_post_url: p.tweet_url || null,
 162|             seed_engagement: { likes: p.like_count, replies: p.reply_count, retweets: p.retweet_count },

```

**`phase_at_follow` は `null` になる見込み。** 成功時の戻り値は
`{ ok: true, status: "followed", profile }` で **phase を含まない**（x63 実測・208 行目）。
**Phase は `followers_at_follow` から後で引ける**（100 未満 = 1 / 300 未満 = 2 / それ以上 = 3）ので、
**ここでは follow-handle 側を触らない。** 触る必要が出たら別タスクにする。

## 3. いつ使えるようになるか

**過去のフォローには遡って入らない。** 次にフォローした分から溜まる。

```
  --- 直近 7 日 のフォロー実績（reply-followers.json の followed_at） ---
    2026-09-05    8 件
    2026-09-06   16 件
    2026-09-07    3 件
    2026-09-08    9 件
    2026-09-09   10 件
    2026-09-12    6 件
    2026-09-13    9 件

    直近 7 日 の合計: 61 件（1 日 平均 8.7 件）
    → 帯ごとに比べられる量（各帯 20 件 以上）になるのは、この速度なら数週間 先。
```

**上限 50000 の妥当性は、すぐには判定できない。**
数字が溜まるまでは**しきい値を触らない。** 触ると、何が効いたか分からなくなる。

## 4. 費用

**JSON に 3 つ キーを足すだけ。LLM を呼ばない。フォロー数も増やさない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

参考（**推定**・前提: Haiku 4.5・生成 64 回/日）: 定時の返信ループは
1 回 $0.003 ／ 1 日 約 $0.19 ／ 1 か月 約 $5.8。
**今日の実測の通過率は 56%**（picked 16 / enqueue 9）。
