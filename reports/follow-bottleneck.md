# フォロー候補がゼロになる原因（2026-08-28 00:09 JST）

> **上限ではなく供給が詰まっている。** cap を上げても 0/10 になるだけ。
> どの仮説が当たりかを、実機のログとコードで決める。**推測で断定しない。**

## 0. logs/ に実在するファイル名（**ログ名を当て推量しない**）

027 は `auto_detect_and_unfollow_inactive.log` を見に行って「ログ無し＝一度も
動いていない」と判定した。**その名前が実在するかを確かめていない。**
名前が違えば、動いていても「動いていない」と出る。実在する一覧を先に出す。

    incoming-reply-watcher.out                     Aug 28 00:09
    incoming-reply-watcher.log                     Aug 28 00:09
    ops-heartbeat-err.log                          Aug 28 00:08
    import-manual-image.out                        Aug 27 23:44
    import-manual-image.log                        Aug 27 23:44
    ops-heartbeat.log                              Aug 27 23:38
    slack-watchdog.log                             Aug 27 23:24
    auto-detect-and-unfollow-inactive.log          Aug 27 22:30
    comment-warmup.log                             Aug 27 22:04
    comment-orchestrator.log                       Aug 27 22:04
    comment-warmup-err.log                         Aug 27 22:03
    sitemap-autosubmit.log                         Aug 27 19:40
    competitor-follower-follow.log                 Aug 27 18:33
    hashtag-follow.log                             Aug 27 17:03
    auto-thread-chainifier.log                     Aug 27 02:00
    badge-followback.log                           Aug 27 00:50
    follower-snapshot.log                          Aug 27 00:35
    seo-health.log                                 Aug 24 08:15
    auto-detect-and-unfollow-inactive-err.log      Aug 23 22:30
    competitor-follower-follow-err.log             Aug 23 11:30
    hashtag-follow-err.log                         Aug 23 10:15
    auto-thread-chainifier-err.log                 Aug 23 00:11
    quick-reply-watcher.log                        Aug 15 19:28
    poll-approvals.log                             Aug 15 13:45
    tab-guard.out                                  Aug 15 13:43
    tab-guard.log                                  Aug 15 13:43
    ensure-chrome.log                              Aug 15 13:41
    x-login-monitor.log                            Aug 10 09:50
    reply-followers-cleanup.out                    Aug 10 09:49
    reply-followers-cleanup.log                    Aug 10 09:49
    chrome-restart-hook.log                        Aug 10 09:48
    incoming-reply-responder.log                   Aug 10 09:47
    pipeline-guardian.log                          Aug 10 09:45
    pipeline-guardian.out                          Aug 10 09:45
    ensure-x-login.log                             Aug 10 09:44
    trend-daily.log                                Aug 10 09:34
    trend-orchestrator.log                         Aug 10 09:34
    cost-monitor.log                               Aug 10 09:32
    cost-monitor-stdout.log                        Aug 10 09:32
    unfollow-cleanup-morning-err.log               Aug 10 09:31

アンフォロー系にあたるログ:
    auto-detect-and-unfollow-inactive-err.log
    auto-detect-and-unfollow-inactive.log
    revenge-unfollow-err.log
    revenge-unfollow.log
    unfollow-cleanup-evening-err.log
    unfollow-cleanup-evening.log
    unfollow-cleanup-morning-err.log
    unfollow-cleanup-morning.log
    unfollow-daily-err.log
    unfollow-daily.log
    unfollow-evening-err.log
    unfollow-evening.log
    unfollow-stats-monitor.log
    unfollow-stats-monitor.stderr.log
    unfollow-stats-monitor.stdout.log
    x-follower-unfollow-err.log
    x-follower-unfollow.log

## 1. 直近 1 回の実行を丸ごと読む

### competitor-follower-follow
- 最終更新: 08-27 18:33

```
[2026-08-26T02:32:14.615Z]   @<伏せ>: ❌ follower>>following exclusion: ratio=0.06 (fw=127/fr=2137) — フォロバ率低のため skip
  @<伏せ>: ❌ follower>>following exclusion: ratio=0.06 (fw=127/fr=2137) — フォロバ率低のため skip
[2026-08-26T02:32:50.436Z]   @<伏せ>: ❌ follower count out of range (30000, need 100-10000)
  @<伏せ>: ❌ follower count out of range (30000, need 100-10000)
[2026-08-26T02:33:20.454Z] === end: 0/5 OK ===
=== end: 0/5 OK ===
[2026-08-26T09:30:03.707Z] === competitor-follower start: target=@<伏せ> (day-rotation index=6/6) cap=5 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=6/6) cap=5 ===
[2026-08-26T09:30:24.288Z] scraped 65 followers from @<伏せ>
scraped 65 followers from @<伏せ>
[2026-08-26T09:30:24.288Z] new targets (after dedup): 5
new targets (after dedup): 5
[2026-08-26T09:30:29.898Z]   @<伏せ>: ❌ follower count out of range (69000, need 100-10000)
  @<伏せ>: ❌ follower count out of range (69000, need 100-10000)
[2026-08-26T09:31:05.419Z]   @<伏せ>: ❌ follower count out of range (35000, need 100-10000)
  @<伏せ>: ❌ follower count out of range (35000, need 100-10000)
[2026-08-26T09:31:40.550Z]   @<伏せ>: ❌ follower count out of range (0, need 10-10000)
  @<伏せ>: ❌ follower count out of range (0, need 10-10000)
[2026-08-26T09:32:16.153Z]   @<伏せ>: ❌ follower>>following exclusion: ratio=0.06 (fw=127/fr=2137) — フォロバ率低のため skip
  @<伏せ>: ❌ follower>>following exclusion: ratio=0.06 (fw=127/fr=2137) — フォロバ率低のため skip
[2026-08-26T09:32:51.703Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-08-26T09:33:21.861Z] === end: 0/5 OK ===
=== end: 0/5 OK ===
[2026-08-27T02:30:05.272Z] === competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=5 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=5 ===
[2026-08-27T02:30:33.870Z] scraped 47 followers from @<伏せ>
scraped 47 followers from @<伏せ>
[2026-08-27T02:30:33.871Z] new targets (after dedup): 5
new targets (after dedup): 5
[2026-08-27T02:30:42.619Z]   @<伏せ>: ✅
  @<伏せ>: ✅
[2026-08-27T02:31:18.286Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-08-27T02:31:54.918Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
  @<伏せ>: ❌ Phase 2: no relevant topic in bio
[2026-08-27T02:32:31.544Z]   @<伏せ>: ❌ inactive (last post 232d ago)
  @<伏せ>: ❌ inactive (last post 232d ago)
[2026-08-27T02:33:08.073Z]   @<伏せ>: ❌ inactive (last post 36d ago)
  @<伏せ>: ❌ inactive (last post 36d ago)
[2026-08-27T02:33:38.114Z] === end: 1/5 OK ===
=== end: 1/5 OK ===
[2026-08-27T09:30:05.287Z] === competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=5 ===
=== competitor-follower start: target=@<伏せ> (day-rotation index=0/6) cap=5 ===
[2026-08-27T09:30:34.124Z] scraped 47 followers from @<伏せ>
scraped 47 followers from @<伏せ>
[2026-08-27T09:30:34.125Z] new targets (after dedup): 5
new targets (after dedup): 5
[2026-08-27T09:30:41.064Z]   @<伏せ>: ❌ no follow button (private/blocked/deleted)
  @<伏せ>: ❌ no follow button (private/blocked/deleted)
[2026-08-27T09:31:16.795Z]   @<伏せ>: ❌ inactive (last post 233d ago)
  @<伏せ>: ❌ inactive (last post 233d ago)
[2026-08-27T09:31:53.049Z]   @<伏せ>: ❌ inactive (last post 36d ago)
  @<伏せ>: ❌ inactive (last post 36d ago)
[2026-08-27T09:32:30.566Z]   @<伏せ>: ❌ inactive (last post 60d ago)
  @<伏せ>: ❌ inactive (last post 60d ago)
[2026-08-27T09:33:07.484Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
  @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
[2026-08-27T09:33:37.502Z] === end: 0/5 OK ===
=== end: 0/5 OK ===
```

- 弾いた理由の内訳（直近 200 行）:
        34 ❌ follower count out of range 
        11 ❌ inactive 
         6 ❌ no follow button 
         6 ❌ low-density bio 
         5 ❌ follower>>following exclusion: ratio=0.0
         4 ❌ follower>>following exclusion: ratio=0.2
         4 ❌ Phase 2: no relevant topic in bio
         1 ❌ random-looking handle 

### hashtag-follow
- 最終更新: 08-27 17:03

```
[2026-08-25T08:03:05.417Z] === end: 0/0 OK ===
=== end: 0/0 OK ===
[2026-08-26T01:15:05.562Z] === hashtag-follow start (cap=90) ===
=== hashtag-follow start (cap=90) ===
[2026-08-26T01:18:05.822Z] trend candidates: 7
trend candidates: 7
[2026-08-26T01:18:05.830Z] unique new authors: 2
unique new authors: 2
[2026-08-26T01:18:05.833Z] today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
[2026-08-26T01:18:05.833Z] picks: 2 authors
picks: 2 authors
[2026-08-26T01:18:10.846Z]   @<伏せ>: ❌ follower>>following exclusion: ratio=0.11 (fw=143/fr=1270) — フォロバ率低のため skip
  @<伏せ>: ❌ follower>>following exclusion: ratio=0.11 (fw=143/fr=1270) — フォロバ率低のため skip
[2026-08-26T01:18:45.928Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
  @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
[2026-08-26T01:19:15.947Z] === end: 0/2 OK ===
=== end: 0/2 OK ===
[2026-08-26T08:00:05.087Z] === hashtag-follow start (cap=90) ===
=== hashtag-follow start (cap=90) ===
[2026-08-26T08:03:05.340Z] trend candidates: 0
trend candidates: 0
[2026-08-26T08:03:05.349Z] unique new authors: 0
unique new authors: 0
[2026-08-26T08:03:05.352Z] today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
[2026-08-26T08:03:05.352Z] picks: 0 authors
picks: 0 authors
[2026-08-26T08:03:05.358Z] === end: 0/0 OK ===
=== end: 0/0 OK ===
[2026-08-27T01:15:05.809Z] === hashtag-follow start (cap=90) ===
=== hashtag-follow start (cap=90) ===
[2026-08-27T01:18:06.064Z] trend candidates: 7
trend candidates: 7
[2026-08-27T01:18:06.079Z] unique new authors: 3
unique new authors: 3
[2026-08-27T01:18:06.082Z] today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
[2026-08-27T01:18:06.082Z] picks: 3 authors
picks: 3 authors
[2026-08-27T01:18:13.668Z]   @<伏せ>: ✅
  @<伏せ>: ✅
[2026-08-27T01:18:50.983Z]   @<伏せ>: ✅
  @<伏せ>: ✅
[2026-08-27T01:19:26.647Z]   @<伏せ>: ❌ follower count out of range (91000, need 100-10000)
  @<伏せ>: ❌ follower count out of range (91000, need 100-10000)
[2026-08-27T01:19:56.663Z] === end: 2/3 OK ===
=== end: 2/3 OK ===
[2026-08-27T08:00:05.089Z] === hashtag-follow start (cap=90) ===
=== hashtag-follow start (cap=90) ===
[2026-08-27T08:03:05.338Z] trend candidates: 0
trend candidates: 0
[2026-08-27T08:03:05.347Z] unique new authors: 0
unique new authors: 0
[2026-08-27T08:03:05.349Z] today already follows: 4 (A:0+B:4) / DAILY_CAP=90 / remaining=86
today already follows: 4 (A:0+B:4) / DAILY_CAP=90 / remaining=86
[2026-08-27T08:03:05.349Z] picks: 0 authors
picks: 0 authors
[2026-08-27T08:03:05.353Z] === end: 0/0 OK ===
=== end: 0/0 OK ===
```

- 弾いた理由の内訳（直近 200 行）:
         8 ❌ exec err: Command failed: /usr/local/bin
         4 ❌ follower>>following exclusion: ratio=0.0
         4 ❌ follower count out of range 
         3 ❌ follower>>following exclusion: ratio=0.2
         2 ❌ random-looking handle 
         2 ❌ off-niche bio 
         2 ❌ low-density bio 
         2 ❌ follower>>following exclusion: ratio=0.1


## 2. 弾く条件のコード

### competitor-follower-follow.js
- 行数: 168

```javascript
7: * filter: follow-handle.js 経由 (bio mutual-intent / follower-count range)
113:    log(`=== competitor-follower SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
132:  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
136:    await slackPost(`<@${OWNER_USER_ID}> 🌐 Tier B (@${competitor}): 全 follower 既 follow か対象なし、skip`);
146:      log(`  @${h}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
160:      log(`  @${h}: ❌ exec err`);
165:  const ok = results.filter(r => r.ok).length;
```

### hashtag-follow.js
- 行数: 174

```javascript
10: *   4. follow-handle.js 経由で follow (bio/follower-count filter 内蔵)
88:    log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
117:    if (!a) continue;
118:    if (seenAuthors.has(a.toLowerCase())) continue;
119:    if (followed.has(a.toLowerCase())) continue;
134:    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
148:      log(`  @${p.author}: ${r.ok ? "✅" : "❌ " + (r.reason || r.error || "unknown")}`);
166:      log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
171:  const ok = results.filter(r => r.ok).length;
```


## 3. 探索元は枯れていないか

- data/followed.json: 157 件 / 更新 2026-08-26 15:50
- data/quick-reply-targets.json: 8 件 / 更新 2026-08-15 10:25

- followed.json の状態別: unfollowed=129 / following=13 / (なし)=15
  → **解除済みを再候補にしないなら、この数だけプールが減っている**
  最後にフォローできた日時: 2026-08-26T15:50

## 4. 重複除外はどこで効いているか

### competitor-follower-follow.js
```javascript
18:const FOLLOWED_PATH = `${WS}/data/followed.json`;
51:  const set = new Set();
77:  const handles = new Set();
86:        const seen = new Set();
89:          if (m && !/^(home|explore|notifications|messages|i|search)$/.test(m[1])) seen.add(m[1]);
91:        return [...seen];
132:  const targets = scrapedHandles.filter(h => !followed.has(h.toLowerCase())).slice(0, DAILY_CAP);
133:  log(`new targets (after dedup): ${targets.length}`);
```

### hashtag-follow.js
```javascript
8: *   2. 各 candidate の author を抽出、dedupe
23:const FOLLOWED_PATH = `${WS}/data/followed.json`;
62:  const set = new Set();
63:  // followed.json
113:  const seenAuthors = new Set();
118:    if (seenAuthors.has(a.toLowerCase())) continue;
119:    if (followed.has(a.toLowerCase())) continue;
120:    seenAuthors.add(a.toLowerCase());
126:  const alreadyTodayA = todayFollowCountFrom(FOLLOWED_PATH);
127:  const alreadyTodayB = todayFollowCountFrom(REPLY_FOLLOWERS_PATH);
128:  const usedToday = alreadyTodayA + alreadyTodayB;
130:  log(`today already follows: ${usedToday} (A:${alreadyTodayA}+B:${alreadyTodayB}) / DAILY_CAP=${DAILY_CAP} / remaining=${remaining}`);
```


## 5. 取得そのものは成功しているか

候補が 0 なのは「弾いた」のか「そもそも取れていない」のか。**ここを混同しない。**

- competitor-follower-follow の取得件数らしき行（直近 20）:
- エラー行（直近 10）:
      [2026-07-30T02:30:20.184Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-07-30T09:30:20.503Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-07-31T02:30:21.561Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-04T02:30:20.369Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-04T09:30:20.360Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-05T02:30:20.371Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-05T09:30:15.429Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-06T02:30:20.368Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-06T09:30:15.509Z] scrape failure: browserType.connectOverCDP: Timeout 15000ms exceeded.
      [2026-08-07T09:30:05.292Z] scrape failure: browserType.connectOverCDP: connect ECONNREFUSED 127.0.0.1:18800

- hashtag-follow の取得件数らしき行（直近 20）:
      picks: 2
      picks: 2
      candidates: 0
      candidates: 0
      authors: 0
      authors: 0
      picks: 0
      picks: 0
      candidates: 7
      candidates: 7
      authors: 3
      authors: 3
      picks: 3
      picks: 3
      candidates: 0
      candidates: 0
      authors: 0
      authors: 0
      picks: 0
      picks: 0
- エラー行（直近 10）:
      [2026-08-06T04:03:20.927Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-06T04:04:06.348Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-06T08:03:20.781Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-06T08:04:06.160Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-06T11:03:20.122Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-06T11:04:06.517Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-07T08:03:05.583Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-07T08:03:35.857Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-07T11:03:04.761Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl
      [2026-08-07T11:03:35.047Z]   @<伏せ>: ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handl


## 6. どの仮説だったか

上を読んで、次のどれかに丸を付けること。**複数でも良いが、根拠の行を必ず添える。**

    A. 弾く条件が厳しすぎる（取れているのに全部落ちる）
    B. 探索元が枯れている（そもそも新しい候補が出てこない）
    C. 重複除外でプールが尽きた（解除済み 129 件が戻らない）
    D. 取得が失敗している（DOM・ログイン・CDP）
