# フォローのフィルタ実物（2026-09-05 16:41:10 JST・費用 $0）

> **ジョブは動いている。フィルタが全部 弾いている。** 今日フォローできたのは 1 人。
> `kankan1014` を「ランダムなハンドル」と誤判定していた。**ここが最大の詰まりどころ。**
> **書き換えない。フォローしない。ジョブも触らない。**

## `ai.openclaw.competitor-follower-follow`

### 叩いているもの（plist の ProgramArguments）

```
/usr/local/bin/node
/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js
```

### 環境変数（**plist だけで調整できるか**）

```
EnvironmentVariables	COMPETITOR_FOLLOW_DAILY_CAP
10	PATH
/usr/local/bin:/usr/bin:/bin	
```

### `competitor-follower-follow.js` — 168 行

#### 数字の定数（範囲・ratio・件数・上限）

```javascript
21:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
33:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
112:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
```

#### ランダム判定（`kankan1014` が弾かれる理由）

```javascript
7: * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
17:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
57:        const h = (a.handle || "").replace(/^@/, "").toLowerCase();
77:  const handles = new Set();
83:    while (handles.size < SCRAPE_TARGET_COUNT && stableCount < 5) {
89:          if (m && !/^(home|explore|notifications|messages|i|search)$/.test(m[1])) seen.add(m[1]);
93:      for (const h of newOnes) handles.add(h);
94:      if (handles.size === lastSize) stableCount++;
96:      lastSize = handles.size;
105:  return [...handles];
145:      results.push({ handle: h, ok: r.ok, info: r });
159:      results.push({ handle: h, ok: false, error: e.message.slice(0, 200) });
```

#### 弾く判定の本体（ログの文言から逆引き）

```javascript
146:      log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
160:      log(`  @${h}: ❌ exec err`);
```

## `ai.openclaw.hashtag-follow`

### 叩いているもの（plist の ProgramArguments）

```
/usr/local/bin/node
/Users/ny/.openclaw/workspace/scripts/hashtag-follow.js
```

### 環境変数（**plist だけで調整できるか**）

```
EnvironmentVariables	HASHTAG_FOLLOW_DAILY_CAP
90	PATH
/usr/local/bin:/usr/bin:/bin	
```

### `hashtag-follow.js` — 174 行

#### 数字の定数（範囲・ratio・件数・上限）

```javascript
30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
87:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
130:  log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
```

#### ランダム判定（`kankan1014` が弾かれる理由）

```javascript
10: *   4. follow-handle.js 経由で follow (bio/follower-count filter 内蔵)
22:const FOLLOW_HANDLE = `${WS}/scripts/follow-handle.js`;
69:        const h = (a.handle || "").replace(/^@/, "").toLowerCase();
```

#### 弾く判定の本体（ログの文言から逆引き）

```javascript
148:      log(`  @${p.author}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
166:      log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
```

---

**何も変えていない（$0）。** 次はここの数字だけを、根拠を持って動かす。
