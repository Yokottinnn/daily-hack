# フォロー量が落ちた理由 ＋ フォロワー数を取るヘルパー

**このレポートが作られた時刻: 2026-09-20 17:03:46 JST**

> **9/17 の 19 件 から 9/18 の 6 件 へ、3 分の 1 に落ちている。**
> x99 では、返ってきた 27 人 のうち 17 人 が 9/13・9/16・9/17 のフォローだった。
> **量が落ちた日は、そのまま成果が落ちる。**

**測るだけ。CAP を変えない。種を触らない。**

## 1. `competitor-follower-follow` は 9/18 以降 何をしていたか

```
  ログ: 4112 行 / 2026-09-20 11:46

  --- 各回の開始行（**どの種をいつ使ったか**）---
    [2026-09-17T20:01:05.711Z] === competitor-follower start: target=@himawari56757 (day-rotation index=0/6) cap=30 ===
    === competitor-follower start: target=@himawari56757 (day-rotation index=0/6) cap=30 ===
    [2026-09-18T02:30:05.280Z] === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    [2026-09-18T09:30:05.271Z] === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    [2026-09-18T20:01:08.416Z] === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@ukk_hx (day-rotation index=1/6) cap=30 ===
    [2026-09-19T02:30:05.856Z] === competitor-follower start: target=@POIKATSU_OTAKE (day-rotation index=2/6) cap=30 ===
    === competitor-follower start: target=@POIKATSU_OTAKE (day-rotation index=2/6) cap=30 ===
    [2026-09-19T16:15:07.353Z] === competitor-follower start: target=@POIKATSU_OTAKE (day-rotation index=2/6) cap=30 ===
    === competitor-follower start: target=@POIKATSU_OTAKE (day-rotation index=2/6) cap=30 ===
    [2026-09-20T02:30:03.262Z] === competitor-follower start: target=@tokufree3 (day-rotation index=3/6) cap=30 ===
    === competitor-follower start: target=@tokufree3 (day-rotation index=3/6) cap=30 ===

  --- 各回の締め（**何件 打ったか**）---
    [2026-09-17T20:01:05.711Z] === competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=30 ===
    [2026-09-18T02:30:05.280Z] === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    [2026-09-18T09:30:05.271Z] === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    [2026-09-18T20:01:08.416Z] === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=1/6) cap=30 ===
    [2026-09-19T02:30:05.856Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=30 ===
    [2026-09-19T16:15:07.353Z] === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=2/6) cap=30 ===
    [2026-09-20T02:30:03.262Z] === competitor-follower start: target=@<伏せ> (day-rotation index=3/6) cap=30 ===
    === competitor-follower start: target=@<伏せ> (day-rotation index=3/6) cap=30 ===

  --- 9/18〜9/20 の全行から、弾いた理由だけ数える ---
      29 回  ❌ follower count out of range
      26 回  ❌ inactive
      25 回  ❌ random-looking handle
      18 回  ❌ no follow button
      13 回  ❌ off-niche bio
      13 回  ❌ low-density bio
       7 回  ❌ refollow blacklist
       2 回  ❌ Phase : no relevant topic in bio
       2 回  ❌ Phase : no mutual-intent keyword & ratio mismatch

  --- 「もう全員フォロー済み」で終わった回があるか（**候補が尽きた印**）---
    該当行: 0
```

**`cap` で止まっているなら上限の問題。**
**「もう全員フォロー済み」なら候補の問題で、上限を上げても増えない。**
後者なら、**種の差し替えが唯一の手**ということになる。

## 2. `hashtag-follow` 側（**上限 90 に対して 1 日 3 件**）

```
  --- 9/18〜9/20 の弾いた理由 ---
       9 回  ❌ follower count out of range
       2 回  ❌ inactive
       1 回  ❌ random-looking handle
       1 回  ❌ off-niche bio

  --- 1 回あたり何件 拾えているか ---
    [2026-09-18T08:03:05.491Z] picks: 2 authors
    picks: 2 authors
    [2026-09-18T20:05:02.435Z] picks: 0 authors
    picks: 0 authors
    [2026-09-19T01:18:05.374Z] picks: 3 authors
    picks: 3 authors
    [2026-09-19T16:18:52.608Z] picks: 0 authors
    picks: 0 authors
    [2026-09-20T01:18:05.333Z] picks: 4 authors
    picks: 4 authors
    [2026-09-20T08:03:03.463Z] picks: 3 authors
    picks: 3 authors
```

**拾えている数（picks）が小さいなら、上限ではなく入口の問題。**
タグを変えないと増えない。

## 3. **プロフィールのフォロワー数を取る仕組み**はどこにあるか

`hashtag-follow` は `follower count out of range (102000, ...)` と出せている。
**すでに在るものを特定する。新しくセレクタを書かない。**

```
  --- 「follower count」を出している箇所 ---
    /Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js:4:// Tracks: follower count (Playwright), posts/comments count, costs, follow stats
    /Users/ny/.openclaw/workspace/scripts/follow-via-playwright.js:58: * Phase-based filtering by current follower count:
    /Users/ny/.openclaw/workspace/scripts/follow-via-playwright.js:114:// Determine current phase from our X profile follower count
    /Users/ny/.openclaw/workspace/scripts/follow-via-playwright.js:142:  // 2026-05-11 Phase別 follower count 範囲調整 (Phase1のフォロバ系は小規模OK)
    /Users/ny/.openclaw/workspace/scripts/follow-via-playwright.js:144:  if (follower_count < minFollowers || follower_count > 10000) return { ok: false, reason: `follower count out of rang
    /Users/ny/.openclaw/workspace/scripts/daily-follow-summary.js:59: * Section A: 今日の動き (follower count delta / 新規 followback / 報復 / source 別)
    /Users/ny/.openclaw/workspace/scripts/follow-handle.js:72:  // Common: follower count range
    /Users/ny/.openclaw/workspace/scripts/follow-handle.js:75:    return { ok: false, reason: `follower count out of range (${follower_count}, need ${minFollowers}-50000)`, phase };

  --- フォロワー数を読んでいそうな関数 ---
    /Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js:33:async function getFollowerCountViaPlaywright() {
    /Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js:94:  const followerCount = await getFollowerCountViaPlaywright();
    /Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js:71:async function scrapeFollowers(competitor) {
    /Users/ny/.openclaw/workspace/scripts/follower-snapshot.js:40:async function scrollLoadFollowers(page) {
    /Users/ny/.openclaw/workspace/scripts/follower-target-monitor.js:44:function loadLatestFollower() {

  --- 単独で呼べる形になっているスクリプト ---
    check-follower-v2.js
    check-follower-v2.js.bak18800

  --- CDP への繋ぎ方（**写して使う**）---
    /Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js:123:  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    /Users/ny/.openclaw/workspace/scripts/extract-render-v2.js:10:  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    /Users/ny/.openclaw/workspace/scripts/post-qt-manual.js:16:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
    /Users/ny/.openclaw/workspace/scripts/capture-design-v3.js:10:  const browser = await chromium.connectOverCDP("http://127.0.0.1:18810", { timeout: 15000 });
    /Users/ny/.openclaw/workspace/scripts/gen-card-design-v2.js:211:  const browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });

  --- playwright-core を使っているか（**playwright ではない**）---
       1 require("playwright")
     371 require("playwright-core")
```

**単独で呼べるものが在れば、次のタスクは 54 件 を回すだけで済む。**
無ければ、既存の呼び出し方を写して 1 本 書く（それでも $0）。

## 4. 費用

**ログとソースを読むだけ。LLM を呼ばない。フォローもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**フォロワー数を DOM で取るのも $0**（LLM を呼ばない）。
返信ループは `MAX_PICKS` を 6 にしたため **約 $0.95/月（推定）** になる見込み。
実測は次の 24 時間 の `cost_24h_usd` で確かめる。
