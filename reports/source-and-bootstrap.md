# 候補の供給源と bootstrap 失敗の切り分け（2026-09-05 21:52:23 JST・費用 $0）

> **フィルタは悪くない。候補の 4 割がゴミ。**
> 弾かれた 37 件のうち **28 件がフォロワー 0〜9 人**の空アカウントだった。
> 上限を上げても増えるのは 1 日 9 件ほど。**直すべきは供給源。**
> **書き換えない。フォローもアンフォローもしない。**

## 1. 競合フォロワーの取得元（**誰のフォロワーを見ているか**）

### `follower-target-config.json` — 更新 08-22 19:37

```json
{
  "version": "v7",
  "target": 300,
  "deadline": "2026-09-30",
  "baseline_count": 207,
  "baseline_date": "2026-08-22"
}
```


## 2. 取得元とスクレイプ数（スクリプトの実体）

### `competitor-follower-follow.js`

```javascript
8: * cap: COMPETITOR_FOLLOW_DAILY_CAP (default 10)
27:const COMPETITORS = [
33:const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
35:const SCRAPE_TARGET_COUNT = 60;
55:      const list = d.followed || d.accounts || (Array.isArray(d) ? d : []);
79:    await page.goto(`https://x.com/${competitor}/followers`, { waitUntil: "domcontentloaded", timeout: 30000 });
83:    while (handles.size < SCRAPE_TARGET_COUNT && stableCount < 5) {
85:        const links = Array.from(document.querySelectorAll('[data-testid="UserCell"] a[href^="/"]'));
88:          const m = a.getAttribute("href").match(/^\/([^/?#]+)$/);
117:  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
118:  const competitor = COMPETITORS[dayIndex];
119:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
140:  const results = [];
```

### `hashtag-follow.js`

```javascript
13: * Daily cap: env HASHTAG_FOLLOW_DAILY_CAP (default 10)
30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
67:      const list = d.followed || d.accounts || (Array.isArray(d) ? d : []);
114:  const targets = [];
142:  const results = [];
```


## 3. ハッシュタグの検索語

```
（見つからない）
```

## 4. bootstrap が失敗する 6 本の実体

### `follow-watchdog`

- サイズ 87 B / 更新 08-22 20:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.follow-watchdog.plist: (Unexpected character { at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.follow-watchdog`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

### `unfollow-daily`

- サイズ 126 B / 更新 08-22 20:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-daily.plist: (Unexpected character { at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.unfollow-daily`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

### `unfollow-evening`

- サイズ 126 B / 更新 08-22 20:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-evening.plist: (Unexpected character { at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.unfollow-evening`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

### `unfollow-cleanup-morning`

- サイズ 409 B / 更新 08-22 22:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-morning.plist: (Unexpected character [ at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.unfollow-cleanup-morning`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

### `unfollow-cleanup-evening`

- サイズ 409 B / 更新 08-22 22:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-evening.plist: (Unexpected character [ at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.unfollow-cleanup-evening`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

### `revenge-unfollow`

- サイズ 54 B / 更新 08-22 20:07 / 権限 -rw-r--r-- ny
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.revenge-unfollow.plist: (Unexpected character { at line 1)
- plist 内の Label: `（読めない）`
- ⚠️ **ファイル名と Label が食い違っている**（ファイル: `ai.openclaw.revenge-unfollow`）

`launchctl print` の出力:
```
Bad request.
Could not find service "（読めない）" in domain for user gui: 501
```

## 5. 同じ Label が別ファイルにも無いか

```
follow-watchdog                          0 ファイル
unfollow-daily                           0 ファイル
unfollow-evening                         0 ファイル
unfollow-cleanup-morning                 0 ファイル
unfollow-cleanup-evening                 0 ファイル
revenge-unfollow                         0 ファイル
```

---

**何も変えていない（$0）。** 次はここの実体を見てから、供給源と bootstrap を直す。
