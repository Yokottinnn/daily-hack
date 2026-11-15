# フォロー先に公式アカウントがどれだけ混ざっているか（2026-09-23 23:35 JST・$0）

**このレポートが作られた時刻: 2026-09-23 23:35:45 JST**

> **読むだけ。** フォローも、書き換えも、ジョブの操作もしていない。
> **handle は出さない。** 当たった語と件数だけ。

## 1. `follow-handle.js` は写しと違うか

```
  行数      : 220
  bytes     : 10814
  更新       : 2026-09-05 18:53:25
  sha256    : 00840ddb7d1e2f27b0fc41bb863335829474bc19214f71135a719923cf636c01
```

**9/05 の写しは 220 行 / 更新 2026-08-09 17:52。** 違えば、写しを前提にしたパッチは当たらない。

上限の実値（ログの `need 10-50000` と合うか）:

```javascript
  73:  const minFollowers = phase === 1 ? 10 : 100;
  74:  if (follower_count < minFollowers || follower_count > 50000) {
  75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
```

## 2. 表示名を取っているか（**名前フィルタの前提**）

名前で弾くには、まず名前を持っていないといけない。
`getProfileData` の `page.evaluate` が返しているキーを見る。

```javascript
  5:    const bio = document.querySelector('[data-testid="UserDescription"]')?.textContent || "";
  7:    const flLink = document.querySelector(`a[href$="/${u}/verified_followers"], a[href$="/${u}/followers"]`);
  9:      const txt = (flLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
  15:    const fwLink = document.querySelector(`a[href$="/${u}/following"]`);
  17:      const txt = (fwLink.querySelector("span span")?.textContent || "0").replace(/,/g, "");
  24:    const t = document.querySelector('article time');
  30:    const followBtn = document.querySelector('[data-testid$="-follow"]');
  31:    const unfollowBtn = document.querySelector('[data-testid$="-unfollow"]');
  32:    return {
  33:      bio,
  34:      follower_count: followerCount,
  35:      following_count: followingCount,
  37:      canFollow: !!followBtn,
  38:      alreadyFollowing: !!unfollowBtn,
```

- **表示名を取っていない。** 名前フィルタは `[data-testid="UserName"]` を
  `getProfileData` に足すところから作ることになる。**bio と handle だけなら いま在る材料で足りる**

## 3. `passFilter` の実物（**土台。ここから書き足す**）

```javascript
       1	function passFilter(profile) {
       2	  const { bio, follower_count, following_count, last_post_age_days } = profile;
       3	  const phase = decidePhase(follower_count);
       4	  const followingCount = following_count || 0;
       5	
       6	  // Common: follower count range
       7	  const minFollowers = phase === 1 ? 10 : 100;
       8	  if (follower_count < minFollowers || follower_count > 50000) {
       9	    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };
      10	  }
      11	
      12	  // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
      13	  // follower>=50 を最低 gate にしてノイズ防止 (それ未満は新規 active 期待で filter 適用外)
      14	  if (follower_count >= 50) {
      15	    const ratio = followingCount / follower_count;
      16	    if (ratio < Number(process.env.FOLLOW_MIN_RATIO || "0")) {
      17	      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため skip`, phase };
      18	    }
      19	  }
      20	
      21	  // 🚨 2026-05-31 #96: refollow blacklist チェック (手動 unfollow 履歴あれば skip)
      22	  if (BLACKLIST.has(handle) || BLACKLIST.has("@" + handle)) {
      23	    return { ok: false, reason: "refollow blacklist (manually unfollowed in past)", phase };
      24	  }
      25	
      26	  // 🚨 2026-05-31 #96: 数字 only / ランダム文字列 handle 検出 (フォロバ来ない属性)
      27	  if (isRandomLookingHandle(handle)) {
      28	    return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
      29	  }
      30	
      31	  // 🚨 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
      32	  if (OFF_NICHE_RE.test(bio || "")) {
      33	    return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
      34	  }
      35	
      36	  // 🚨 2026-05-31 #96: bio 情報密度判定 (空 or テンプレキーワードのみ → 質低)
      37	  if (isLowDensityBio(bio)) {
      38	    return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
      39	  }
      40	
      41	  // Common: skip inactive (30+ days no post)
      42	  if (last_post_age_days != null && last_post_age_days > 30) {
      43	    return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
      44	  }
      45	
      46	  // Phase-specific bio checks
      47	  if (phase === 1) {
      48	    // 2026-05-18 broad mutual-intent keyword set
      49	    const bioMatch = /フォロバ|フォローバック|フォロー返し|フォロー返却|フォロー返します|リフォロー|相互(フォロー)?|ふぉろば|フォロー(歓迎|welcome|お気軽|大歓迎)|フォロワー(募集|歓迎|大歓迎|お待ちしてます)|お気軽(に|フォロー)|気軽に(フォロー|どうぞ)|仲間|同志|つながり|繋がり|無言フォロー?(歓迎|失礼|OK|ok)?|FF外(から)?(失礼|OK)?|誰でも(歓迎|フォロー|どうぞ)|繋(が|げ)りた[いそ]|交流(歓迎|したい)|なかよく|仲良(し|く)/i.test(bio || "");
      50	    const ratioMatch = followingCount > 0 && (
      51	      (followingCount >= follower_count * 0.8 && followingCount <= follower_count * 1.5) ||
      52	      (followingCount > follower_count && followingCount < 1000)
      53	    );
      54	    const spamMatch = /いいね回し|相互いいね|拡散希望|相互RT/i.test(bio || "");
      55	    if (spamMatch) return { ok: false, reason: "Phase 1: spam pattern in bio", phase };
      56	    if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase };
      57	  }
      58	  if (phase === 2) {
      59	    if (!/節約|ポイ活|お得|貯金|ふるさと|格安|nisa|投資|キャッシュレス|ポイント|還元|家計|貯蓄/i.test(bio || "")) {
      60	      return { ok: false, reason: "Phase 2: no relevant topic in bio", phase };
      61	    }
      62	  }
      63	  // Phase 3: just rely on common filters (already passed range + influencer + activity)
      64	  return { ok: true, phase };
      65	}
```

## 4. 直近ログの拒否理由の内訳（**足す余力があるか**）

いま何が何件 弾いているか。**`✅` の数が、名前フィルタが削る母数。**

```
  auto-detect-and-unfollow-inactive-err.log ✅    0 件   ❌    0 件   更新 08-23 22:30
  auto-detect-and-unfollow-inactive.log ✅    0 件   ❌    0 件   更新 09-09 22:30
  badge-followback.log               ✅    0 件   ❌    0 件   更新 09-23 00:51
  badge-followback.stderr.log        ✅    0 件   ❌    0 件   更新 06-08 00:50
  badge-followback.stdout.log        ✅    0 件   ❌    0 件   更新 06-08 00:50
  competitor-follower-follow-err.log ✅    0 件   ❌    0 件   更新 09-18 05:06
  competitor-follower-follow.log     ✅  431 件   ❌ 3189 件   更新 09-23 18:48
  daily-follow-summary-err.log       ✅    0 件   ❌    0 件   更新 09-09 23:00
  daily-follow-summary.log           ✅    0 件   ❌    0 件   更新 09-09 23:00
  follow-daily-err.log               ✅    0 件   ❌    0 件   更新 05-10 14:00
  follow-daily.log                   ✅    0 件   ❌    0 件   更新 06-07 15:13
  follow-morning-err.log             ✅    0 件   ❌    0 件   更新 05-11 08:00
  follow-morning.log                 ✅    0 件   ❌    0 件   更新 06-02 08:00
  follow-up-reply.log                ✅    0 件   ❌    0 件   更新 05-17 02:23
  follow-watchdog-err.log            ✅    0 件   ❌    0 件   更新 09-07 23:59
  follow-watchdog.log                ✅    0 件   ❌    0 件   更新 09-09 11:00
  follower-daily-report-err.log      ✅    0 件   ❌    0 件   更新 09-09 08:00
  follower-daily-report.log          ✅    0 件   ❌    0 件   更新 09-09 08:00
  follower-monitor-err.log           ✅    0 件   ❌    0 件   更新 06-04 12:30
  follower-monitor.log               ✅    0 件   ❌    0 件   更新 09-09 12:30
  follower-snapshot.log              ✅    0 件   ❌    0 件   更新 09-23 00:35
  follower-snapshot.stderr.log       ✅    0 件   ❌    0 件   更新 06-07 00:35
  follower-snapshot.stdout.log       ✅    0 件   ❌    0 件   更新 06-07 00:35
  follower-target-monitor-err.log    ✅    0 件   ❌    0 件   更新 06-07 21:00
  follower-target-monitor.log        ✅    0 件   ❌    0 件   更新 07-04 21:00
  hashtag-follow-err.log             ✅    0 件   ❌    0 件   更新 09-08 00:02
  hashtag-follow.log                 ✅   65 件   ❌  363 件   更新 09-23 17:04
  reply-followback-check.log         ✅    0 件   ❌    0 件   更新 09-23 13:15
  reply-followers-cleanup.log        ✅    0 件   ❌    0 件   更新 09-23 22:00
  revenge-unfollow-err.log           ✅    0 件   ❌    0 件   更新 07-12 13:00
  revenge-unfollow.log               ✅    0 件   ❌    0 件   更新 09-09 13:00
  unfollow-cleanup-evening-err.log   ✅    0 件   ❌    0 件   更新 09-09 20:31
  unfollow-cleanup-evening.log       ✅    0 件   ❌    0 件   更新 08-06 20:30
  unfollow-cleanup-morning-err.log   ✅    0 件   ❌    0 件   更新 09-09 08:31
  unfollow-cleanup-morning.log       ✅    0 件   ❌    0 件   更新 08-06 09:30
  unfollow-daily-err.log             ✅    0 件   ❌    0 件   更新 07-12 14:00
  unfollow-daily.log                 ✅    0 件   ❌    0 件   更新 08-10 09:00
  unfollow-evening-err.log           ✅    0 件   ❌    0 件   更新 07-12 22:00
  unfollow-evening.log               ✅    0 件   ❌    0 件   更新 08-09 22:00
  unfollow-stats-monitor.log         ✅    0 件   ❌    0 件   更新 08-10 09:30
  unfollow-stats-monitor.stderr.log  ✅    0 件   ❌    0 件   更新 05-24 09:30
  unfollow-stats-monitor.stdout.log  ✅    0 件   ❌    0 件   更新 05-24 09:30
  x-follower-cron.log                ✅    0 件   ❌    0 件   更新 07-04 23:54
  x-follower-follow-err.log          ✅    0 件   ❌    0 件   更新 05-09 01:48
  x-follower-follow.log              ✅    0 件   ❌    0 件   更新 05-09 01:48
  x-follower-unfollow-err.log        ✅    0 件   ❌    0 件   更新 05-09 22:00
  x-follower-unfollow.log            ✅    0 件   ❌    0 件   更新 05-09 22:00
```

拒否理由の内訳（多い順・**数字は伏せて理由だけで束ねる**）:

```
  1239 follower count out of range
   587 inactive
   448 no follow button
   330 random-looking handle
   284 low-density bio
   156 refollow blacklist
   152 off-niche bio
   137 follower>>following exclusion
   128 Phase N
    45 follow button click didn't change to unfollow
    35 exec err
     6 influencer exclusion
     5 page.goto
```

## 5. 通った先に「公式らしさ」がどれだけ在るか

**`✅` になった handle だけ**に語を当てる。**handle は出さない。当たった語と件数だけ。**

**`✅` の実数（重複を除いた handle）: 319 件**

### 強い手がかり（**当たればほぼ公式・法人**）

```
  _jp            2 件
  _pr            2 件
  _co            1 件
  _CO            1 件
```

### 弱い手がかり（**個人でも普通に使う。単独では弾けない**）

```
  info           1 件
  shop           1 件
  team           1 件
```

## 6. bio 側に語が在るか（**日本語はこちらが本命**）

handle は英字しか入らないので、**「【公式】」「株式会社」「編集部」は bio と表示名にしか出ない。**
フォロー実績に bio が残っているファイルを探して当てる。

```
  badge-followback-state.json                    10251 bytes  更新 09-23 00:51
  follow-watchdog-state.json                       619 bytes  更新 09-09 11:03
  followed.json                                  55341 bytes  更新 09-23 00:51
  follower-daily-report-state.json                 109 bytes  更新 09-09 08:00
  follower-history.json                           1577 bytes  更新 05-24 00:30
  follower-target-config.json                      124 bytes  更新 08-22 19:37
  refollow-blacklist.json                         4531 bytes  更新 08-02 20:45
  reply-followers.json                          215794 bytes  更新 09-23 22:03
  unfollow-cleanup-state.json                    15630 bytes  更新 09-09 20:31
  unfollow-whitelist.json                          742 bytes  更新 07-19 23:06
  unfollow_batch.json                             1817 bytes  更新 05-09 01:15
```

そのファイルの中で、公式らしさの語が何件 当たるか（**中身は出さない**）:

```
  公式                    2 行
```

> **「行」であって「アカウント数」ではない。** 1 行に複数 入っていることも、
> 同じアカウントが複数 行に出ていることもある。**上限の見積もりとして読む**

---

## 読み方（**このタスクでは直さない**）

| 出方 | 次の一手 |
| --- | --- |
| 語の当たりが **多い**（✅ の 1 割 以上） | **名前フィルタを足す価値がある。** §3 の `passFilter` に足す |
| 語の当たりが **ほぼ 0** | **公式は既に別の絞りで落ちている。** 足しても供給が減るだけ。**やめる** |
| 表示名を取っていない（§2） | `getProfileData` に `UserName` を足すぶん、パッチが 2 箇所 になる |
| `follow-handle.js` が写しと違う（§1） | **実物の `passFilter`（§3）から書く。** 写しは使わない |
| ✅ が日に数件 しかない | **絞りを足す前に供給を増やす話。** 順番が逆 |

## 費用

**ファイルとログを読むだけ。LLM を呼んでいない。**
**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、絞りを変えても課金は増えない。

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
