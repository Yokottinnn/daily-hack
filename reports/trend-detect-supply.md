# `trend-detect` の出力が安定しない理由

**このレポートが作られた時刻: 2026-09-13 21:54:43 JST**

> `hashtag-follow` は独自のタグを持たず、**`trend-detect` の出力を使っている。**
> **返信もフォローも供給元はここ 1 つ。** 0 件 の回は両方 空振りする。

**測るだけ。広げない。**

## 1. 1 回あたり何件 返しているか（**時刻ごとの推移**）

```
  --- hashtag-follow 側（trend candidates: N） ---
    2026-08-29 08:03:05  4 件
    2026-09-01 01:18:06  11 件
    2026-09-01 08:03:01  4 件
    2026-09-02 01:18:05  12 件
    2026-09-02 08:03:05  8 件
    2026-09-03 01:18:05  13 件
    2026-09-03 08:03:05  14 件
    2026-09-04 01:18:05  9 件
    2026-09-04 08:03:05  13 件
    2026-09-05 01:18:06  11 件
    2026-09-05 08:03:05  5 件
    2026-09-05 09:01:09  1 件
    2026-09-05 09:56:26  2 件
    2026-09-06 01:18:06  9 件
    2026-09-06 08:03:05  14 件
    2026-09-07 15:02:29  1 件
    2026-09-08 01:18:05  6 件
    2026-09-08 08:03:05  0 件
    2026-09-09 01:18:05  2 件
    2026-09-09 08:03:04  4 件
    2026-09-12 18:07:27  1 件
    2026-09-13 01:18:05  9 件
    2026-09-13 01:49:21  0 件
    2026-09-13 08:03:05  2 件

  --- 返信側（from N candidates） ---
    2026-09-06 21:26:17  候補 14 件 → picked 2/2
    2026-09-06 22:03:03  候補 5 件 → picked 2/2
    2026-09-08 00:03:14  候補 23 件 → picked 4/4
    2026-09-08 12:03:06  候補 9 件 → picked 4/4
    2026-09-08 16:03:06  候補 11 件 → picked 4/4
    2026-09-08 19:03:05  候補 4 件 → picked 4/4
    2026-09-08 22:03:06  候補 21 件 → picked 4/4
    2026-09-09 12:03:07  候補 13 件 → picked 4/4
    2026-09-09 16:03:10  候補 14 件 → picked 4/4
    2026-09-09 19:03:07  候補 10 件 → picked 4/4
    2026-09-09 22:03:08  候補 15 件 → picked 4/4
    2026-09-13 03:05:57  候補 8 件 → picked 4/4
    2026-09-13 12:03:06  候補 11 件 → picked 4/4
    2026-09-13 16:03:06  候補 5 件 → picked 4/4
    2026-09-13 19:03:06  候補 8 件 → picked 4/4
    2026-09-13 21:09:30  候補 11 件 → picked 4/4

  --- 0 件 だった回の時刻（UTC の時） ---
      11 T12:
       6 T19:
       6 T16:
       5 T08:
       5 T01:
       4 T22:
       3 T04:
       1 T11:

  --- 0 件 以外の回の時刻（比較用） ---
      34 T01:
      32 T08:
      10 T11:
      10 T04:
       2 T09:
       1 T20:
       1 T18:
       1 T15:
       1 T13:
       1 T10:
```

**時刻に偏っていれば「その時間帯に投稿が少ない」で説明がつく。**
偏っていなければ、取りに行く側の問題を疑う。

## 2. 途中で失敗していないか（**`failed:` の行**）

```
  comment-warmup.log               0
0 件
  comment-orchestrator.log          13 件
  hashtag-follow.log               190 件

  --- 直近 12 件（実物） ---
    [2026-08-06T04:03:20.927Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js m3h2c11wK5esIcV
    [2026-08-06T04:04:06.348Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js Momomoai10over
    [2026-08-06T08:03:20.781Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js m3h2c11wK5esIcV
    [2026-08-06T08:04:06.160Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js Momomoai10over
    [2026-08-06T11:03:20.122Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js m3h2c11wK5esIcV
    [2026-08-06T11:04:06.517Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js Momomoai10over
    [2026-08-07T08:03:05.583Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js momoyama_univ
    [2026-08-07T08:03:35.857Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js cuterunchan
    [2026-08-07T11:03:04.761Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js momoyama_univ
    [2026-08-07T11:03:35.047Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js cuterunchan
    [2026-09-07T15:03:00.866Z]   @<伏せ>: ❌ page.goto: Timeout 20000ms exceeded.
      @<伏せ>: ❌ page.goto: Timeout 20000ms exceeded.

  --- 失敗した検索語（多い順） ---
       1 hashtag 節約 failed
       1 hashtag ポイ活 failed
       1 hashtag お得情報 failed
```

## 3. どこから集めているか（**設定の実物**）

```
  251 行 / 最終更新 2026-08-30 21:42

  --- 集めに行く先 ---
    5: *   B. Hashtag search: see HASHTAGS list
    10: *   - PER_ITEM_TIMEOUT_MS (default 12s) — hashtag/account 個別 scrape の hard cap
    13: *   - HASHTAGS を優先度高 core 12個に絞る (元 24)
    27:const HASHTAGS = [
    155:async function scrapeHashtag(page, hashtag) {
    156:  const url = `https://x.com/search?q=${encodeURIComponent("#" + hashtag)}&f=live`;
    158:  return scrapeTimelinePage(page, `hashtag:${hashtag}`);
    178:  for (const tag of HASHTAGS) {
    179:    if (all.length >= EARLY_EXIT_COUNT) { console.error(`early exit: hashtag loop, all=${all.length}`); break; }
    181:      const items = await withTimeout(scrapeHashtag(page, tag), PER_ITEM_TIMEOUT_MS, `hashtag:${tag}`);
    189:      console.error(`hashtag ${tag} failed:`, e.message);

  --- 絞り込みの条件 ---
    20:const MIN_LIKES = parseInt(process.env.MIN_LIKES || "5", 10);
    21:const MAX_AGE_HOURS = parseInt(process.env.MAX_AGE_HOURS || "12", 10);
    65:function ageHours(postedAt) {
    70:function ageDecay(postedAt) {
    71:  const a = ageHours(postedAt);
    79:function velocityBonus(engagement, postedAt) {
    80:  const a = Math.max(0.1, ageHours(postedAt));
    82:  const eph = engagement / a;
    89:  const eng = (item.like_count || 0) + (item.reply_count || 0) * 3 + (item.retweet_count || 0) * 5;
    90:  return Math.round(eng * ageDecay(item.posted_at) * velocityBonus(eng, item.posted_at) * 10) / 10;
    93:async function scrapeTimelinePage(page, label) {
    94:  await page.waitForSelector('article[data-testid="tweet"]', { timeout: 4500 }).catch(() => null);
    95:  await page.waitForTimeout(500);
    97:    await page.evaluate(() => window.scrollBy(0, 1500));
    98:    await page.waitForTimeout(400);
    100:  const items = await page.$$eval('article[data-testid="tweet"]', (articles) => {
    123:      if (/(リポスト|reposted|retweeted)/i.test(social)) return null;
    134:      const retweetAria = a.querySelector('[data-testid="retweet"], [data-testid="unretweet"]')?.getAttribute("aria-label") || "";
    138:      const retweets = parseNum(retweetAria);
    143:        text: text.slice(0, 500),

  --- 読み込んでいる設定ファイル ---
    trend-cache.json
```

## 4. 絞り込みの実値（**plist が渡している値**）

```
    EnvironmentVariables	MAX_AGE_HOURS
    18	MAX_PICKS_PER_FIRE
    4	MIN_LIKES
    2	REPLY_FOLLOW_DAILY_CAP
    30	

  --- 候補の設定ファイル（更新日も見る） ---
```

**`MIN_LIKES=2` と `MAX_AGE_HOURS=18` がどこで効くかを 3 章と突き合わせる。**
深夜は「18 時間 以内かつ いいね 2 以上」を満たす投稿がそもそも少ない可能性がある。

## 5. 費用

**ログとソースを読むだけ。LLM を呼ばない。ブラウザも触らない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**注意: 候補を増やすと返信の生成回数が増えるため、そちらは費用が動く。**

| | 1 回あたり | 1 日あたり | 1 か月あたり |
| --- | --- | --- | --- |
| いま（x68 適用後・上限） | $0.003 | $0.048 | **$1.44** |
| 候補が増えて上限に毎回 張り付いた場合 | $0.003 | $0.048 | **$1.44** |

**上限（MAX_PICKS 4 × 4 発火 = 16 件/日）は変えないので、
候補が増えても月額の上限は $1.44 のまま。** 上限に近づくだけ。
**発火数や MAX_PICKS を上げる提案をするときは、増加後の月額を必ず併記する。**
