# フォロー候補の供給を太くする（2026-08-30 21:10 JST）

> **cap 90 に対し候補が 1〜3 件。** 上限ではなく供給が詰まっている。
> 「取れていない」のか「弾いている」のかを段階ごとの数で分ける。

## 1. 探しに行っているハッシュタグ

```javascript
5: *   B. Hashtag search: see HASHTAGS list
13: *   - HASHTAGS を優先度高 core 12個に絞る (元 24)
27:const HASHTAGS = [
176:  for (const tag of HASHTAGS) {
```

定義の中身（配列の実体）:
```javascript
const HASHTAGS = [
  "節約", "ポイ活", "お得情報", "ふるさと納税", "還元",
  "新NISA", "PayPay", "楽天経済圏"
];
```

## 2. 足切りの条件

### trend-detect.js（249 行）
```javascript
10: *   - PER_ITEM_TIMEOUT_MS (default 12s) — hashtag/account 個別 scrape の hard cap
20:const MIN_LIKES = parseInt(process.env.MIN_LIKES || "5", 10);
21:const MAX_AGE_HOURS = parseInt(process.env.MAX_AGE_HOURS || "12", 10);
25:const PER_ITEM_TIMEOUT_MS = parseInt(process.env.PER_ITEM_TIMEOUT_MS || "12000", 10);
40:const EARLY_EXIT_COUNT = parseInt(process.env.EARLY_EXIT_COUNT || "20", 10);
141:        text: text.slice(0, 500),
177:    if (all.length >= EARLY_EXIT_COUNT) { console.error(`early exit: hashtag loop, all=${all.length}`); break; }
179:      const items = await withTimeout(scrapeHashtag(page, tag), PER_ITEM_TIMEOUT_MS, `hashtag:${tag}`);
181:        .filter(x => x.like_count >= MIN_LIKES && ageHours(x.posted_at) <= MAX_AGE_HOURS)
184:        .slice(0, MAX_PER_SOURCE);
191:    if (all.length >= EARLY_EXIT_COUNT * 1.5) { console.error(`early exit: account loop, all=${all.length}`); break; }
193:      const items = await withTimeout(scrapeAccount(page, handle), PER_ITEM_TIMEOUT_MS, `account:${handle}`);
195:        .filter(x => ageHours(x.posted_at) <= MAX_AGE_HOURS)
198:        .slice(0, MAX_PER_SOURCE);
219:  const ranked = unique.sort((a, b) => b.score - a.score).slice(0, MAX_OUTPUT);
```
### hashtag-follow.js（174 行）
```javascript
32:const TODAY = new Date().toISOString().slice(0, 10);
99:    log(`trend-detect failed: ${e.message} | stderr: ${(e.stderr||"").toString().slice(0,500)}`);
138:  const picks = targets.slice(0, remaining);
165:      results.push({ author: p.author, ok: false, error: e.message.slice(0, 200) });
166:      log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
```
### follow-handle.js（220 行）
```javascript
24:// 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
62:  if (followerCount < 100) return 1;
72:  // Common: follower count range
74:  if (follower_count < minFollowers || follower_count > 10000) {
75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-10000)`, phase };
78:  // 🚨 2026-05-25 改定 user 指示: 規模問わず ratio<0.3 で skip (フォロワー>>フォロー = 人気アカ、 フォロバ率低)
81:    const ratio = followingCount / follower_count;
82:    if (ratio < 0.3) {
83:      return { ok: false, reason: `follower>>following exclusion: ratio=${ratio.toFixed(2)} (fw=${followingCount}/fr=${follower_count}) — フォロバ率低のため
94:    return { ok: false, reason: `random-looking handle (likely throwaway/spam): ${handle}`, phase };
97:  // 🚨 2026-05-31 #96: off-niche bio negative-list (節約・ポイ活と無関係なジャンル特化アカ)
99:    return { ok: false, reason: `off-niche bio (ダイエット/オタ活/ペット等)`, phase };
104:    return { ok: false, reason: `low-density bio (空 or テンプレキーワードのみ)`, phase };
107:  // Common: skip inactive (30+ days no post)
109:    return { ok: false, reason: `inactive (last post ${last_post_age_days}d ago)`, phase };
116:    const ratioMatch = followingCount > 0 && (
118:      (followingCount > follower_count && followingCount < 1000)
122:    if (!bioMatch && !ratioMatch) return { ok: false, reason: `Phase 1: no mutual-intent keyword & ratio mismatch (fw=${followingCount}/fr=${follower_count})`, phase 
```

## 3. どの段階で減っているか（直近 10 回ぶん）

**取得 → 重複除外 → 足切り → pick。** どこで落ちているかを並べる。

### hashtag-follow
```
[2026-08-28T01:18:02.725Z] trend candidates: 13
trend candidates: 13
[2026-08-28T01:18:02.739Z] unique new authors: 4
unique new authors: 4
[2026-08-28T01:18:02.742Z] today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
[2026-08-28T01:18:02.742Z] picks: 4 authors
picks: 4 authors
[2026-08-28T01:20:29.518Z] === end: 1/4 OK ===
=== end: 1/4 OK ===
[2026-08-28T08:03:05.353Z] trend candidates: 2
trend candidates: 2
[2026-08-28T08:03:05.365Z] unique new authors: 1
unique new authors: 1
[2026-08-28T08:03:05.368Z] today already follows: 2 (A:0+B:2) / DAILY_CAP=90 / remaining=88
today already follows: 2 (A:0+B:2) / DAILY_CAP=90 / remaining=88
[2026-08-28T08:03:05.368Z] picks: 1 authors
picks: 1 authors
[2026-08-28T08:03:43.538Z] === end: 0/1 OK ===
=== end: 0/1 OK ===
[2026-08-29T01:18:05.333Z] trend candidates: 6
trend candidates: 6
[2026-08-29T01:18:05.344Z] unique new authors: 1
unique new authors: 1
[2026-08-29T01:18:05.347Z] today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
[2026-08-29T01:18:05.347Z] picks: 1 authors
picks: 1 authors
[2026-08-29T01:18:42.162Z] === end: 0/1 OK ===
=== end: 0/1 OK ===
[2026-08-29T08:03:05.344Z] trend candidates: 4
trend candidates: 4
[2026-08-29T08:03:05.358Z] unique new authors: 3
unique new authors: 3
[2026-08-29T08:03:05.361Z] today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
[2026-08-29T08:03:05.361Z] picks: 3 authors
picks: 3 authors
[2026-08-29T08:05:00.262Z] === end: 1/3 OK ===
=== end: 1/3 OK ===
```

### competitor-follower-follow
```
[2026-08-28T02:30:33.715Z] scraped 53 followers from @<伏せ>
scraped 53 followers from @<伏せ>
[2026-08-28T02:30:33.716Z] new targets (after dedup): 10
new targets (after dedup): 10
[2026-08-28T02:36:38.953Z] === end: 0/10 OK ===
=== end: 0/10 OK ===
[2026-08-28T09:30:05.285Z] === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=10 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=10 ===
[2026-08-28T09:30:33.719Z] scraped 53 followers from @<伏せ>
scraped 53 followers from @<伏せ>
[2026-08-28T09:30:33.720Z] new targets (after dedup): 10
new targets (after dedup): 10
[2026-08-28T09:36:40.230Z] === end: 0/10 OK ===
=== end: 0/10 OK ===
[2026-08-29T02:30:05.524Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=10 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=10 ===
[2026-08-29T02:30:23.687Z] scraped 60 followers from @<伏せ>
scraped 60 followers from @<伏せ>
[2026-08-29T02:30:23.688Z] new targets (after dedup): 10
new targets (after dedup): 10
[2026-08-29T02:36:36.823Z] === end: 1/10 OK ===
=== end: 1/10 OK ===
[2026-08-29T09:30:05.281Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=10 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=10 ===
[2026-08-29T09:30:23.921Z] scraped 61 followers from @<伏せ>
scraped 61 followers from @<伏せ>
[2026-08-29T09:30:23.922Z] new targets (after dedup): 10
new targets (after dedup): 10
[2026-08-29T09:36:40.174Z] === end: 0/10 OK ===
=== end: 0/10 OK ===
```

## 4. 巡回先の母数

競合の day-rotation は何件あるか（**ハンドルは出さない。件数だけ**）:
- 競合の巡回先: **7 件**
- followed.json: 161 件 / unfollowed=129 / following=13 / (なし)=19
  → **この数だけ候補から除外されている**

## 5. 太くする手の候補（**実行はしない。材料を出すだけ**）

上の数字を見て、効く順に選ぶこと。

    A. ハッシュタグを増やす        → 1 タグ 1〜3 件なら、タグ数がそのまま効く
    B. MIN_LIKES を下げる          → 足切りで落ちているなら効く。落ちていないなら無意味
    C. MAX_AGE_HOURS を伸ばす      → 18h → 48h で母数が増える
    D. 競合の巡回先を増やす        → 6 件しか無いなら、ここが一番太い
    E. 1 タグあたりの取得上限を上げる

**上限（cap）はもう効かないと分かっている。** A〜E は供給側の手。
