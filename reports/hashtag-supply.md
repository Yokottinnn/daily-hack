# ハッシュタグ側が 2 件 しか試せない理由

**このレポートが作られた時刻: 2026-09-13 21:01:18 JST**

> `HASHTAG_FOLLOW_DAILY_CAP=90` なのに、2026-09-13 の結果は **1/2 OK**。
> **上限では止まっていない。候補が来ていない。**

**測るだけ。タグを足さない。**

## 1. 見ているタグ（**設定の実物**）

```
  177 行 / 最終更新 2026-09-13 19:58

  --- タグ・検索語の定義 ---
    3: * hashtag-follow.js — Tier A: ハッシュタグ active 投稿者を follow 候補化
    11: *   5. reply-followers.json に source="hashtag-active" で記録 (live-check safety net 自動適用)
    25:const LOG_PATH = `${WS}/logs/hashtag-follow.log`;
    40:    return nx.notify(text, { kind: "hashtag-follow-progress" });
    88:    log(`=== hashtag-follow SKIP (day=${todayDow}, Sun/Mon skip policy) ===`);
    92:  log(`=== hashtag-follow start (cap=${DAILY_CAP}) ===`);
    134:    await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow: cap到達でskip (today=${usedToday}/${DAILY_CAP})`);
    160:            source: "hashtag-follow",
    175:  await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow 完了: ${ok}/${results.length} follow OK (今日合計 follow ≈${usedToday + ok}/${DAILY_CAP})`);

  --- 読み込んでいる設定ファイル ---
    followed.json
    openclaw.json
    reply-followers.json
    silent_slack.json

  --- 何件 取ろうとしているか（上限・slice・件数） ---
    32:const TODAY = new Date().toISOString().slice(0, 10);
    99:    log(`trend-detect failed: ${e.message} | stderr: ${(e.stderr||"").toString().slice(0,500)}`);
    109:  log(`trend candidates: ${candidates.length}`);
    123:  log(`unique new authors: ${targets.length}`);
    138:  const picks = targets.slice(0, remaining);
    139:  log(`picks: ${picks.length} authors`);
    168:      results.push({ author: p.author, ok: false, error: e.message.slice(0, 200) });
    169:      log(`  @${p.author}: ❌ exec err: ${e.message.slice(0, 150)}`);
    174:  const ok = results.filter(r => r.ok).length;
    175:  await slackPost(`<@${OWNER_USER_ID}> 🏷️ Tier A hashtag-follow 完了: ${ok}/${results.length} follow OK (今日合計 follow ≈${usedToday + ok}/${DAILY_CAP})`);
    176:  log(`=== end: ${ok}/${results.length} OK ===`);
```

## 2. どこで減っているか（**ログの推移**）

```
  112135 bytes / 最終更新 09-13 17:04

  --- 直近 30 行（書式を見るため生で出す） ---
    [2026-09-13T01:43:29.642Z] === hashtag-follow start (cap=90) ===
    === hashtag-follow start (cap=90) ===
    [2026-09-13T01:46:21.487Z] === hashtag-follow start (cap=90) ===
    === hashtag-follow start (cap=90) ===
    [2026-09-13T01:49:21.687Z] trend candidates: 0
    trend candidates: 0
    [2026-09-13T01:49:21.692Z] unique new authors: 0
    unique new authors: 0
    [2026-09-13T01:49:21.695Z] today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
    today already follows: 1 (A:0+B:1) / DAILY_CAP=90 / remaining=89
    [2026-09-13T01:49:21.695Z] picks: 0 authors
    picks: 0 authors
    [2026-09-13T01:49:21.698Z] === end: 0/0 OK ===
    === end: 0/0 OK ===
    [2026-09-13T08:00:05.077Z] === hashtag-follow start (cap=90) ===
    === hashtag-follow start (cap=90) ===
    [2026-09-13T08:03:05.301Z] trend candidates: 2
    trend candidates: 2
    [2026-09-13T08:03:05.312Z] unique new authors: 2
    unique new authors: 2
    [2026-09-13T08:03:05.315Z] today already follows: 7 (A:0+B:7) / DAILY_CAP=90 / remaining=83
    today already follows: 7 (A:0+B:7) / DAILY_CAP=90 / remaining=83
    [2026-09-13T08:03:05.315Z] picks: 2 authors
    picks: 2 authors
    [2026-09-13T08:03:09.938Z]   @<伏せ>: ✅
      @<伏せ>: ✅
    [2026-09-13T08:03:42.806Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    [2026-09-13T08:04:12.815Z] === end: 1/2 OK ===
    === end: 1/2 OK ===

  --- 日ごとの推移（start / 集めた数 / 試した数 / 通った数） ---
    日付       発火   SKIP 集めた 試した 通った
    2026-09-02        4      0      14     14      0
    2026-09-03        4      0      20     20      2
    2026-09-04        4      0      14     14      0
    2026-09-05       10      0      20     20      6
    2026-09-06        4      0      22     22      6
    2026-09-07        2      0       2      2      0
    2026-09-08        4      0       2      2      0
    2026-09-09        4      0      10     10      2
    2026-09-12        2      0       0      0      0
    2026-09-13        8      0      16     16      4

  --- 弾かれた理由（上位 12） ---
      94 follower count out of range
      28 exec err: Command failed: /usr/local/bin/node /Users/ny/.ope
      25 random-looking handle
      24 inactive
      19 low-density bio
      16 off-niche bio
      10 no follow button
       6 follower>>following exclusion: ratio=0.11
       6 follower>>following exclusion: ratio=0.00
       4 follower>>following exclusion: ratio=0.23
       4 follower>>following exclusion: ratio=0.22
       4 Phase 2: no relevant topic in bio
```

## 3. `trend-detect` と重なっていないか

**同じタグを見ているなら、返信で拾った相手をフォローでも拾っている。**
その場合は「既にフォロー済み」で落ちるので、**タグを足しても増えない。**

```
  --- trend-detect が見ているタグ ---

  --- hashtag-follow が見ているタグ ---

  --- 設定ファイル側のタグ ---
    ══ reply-relevance-rules.json（09-13 15:27）
      タグらしき値: 17 件
      #PR #ad #広告 #提供 #sponsored #アフィリエイト #乞食 #PayPay乞食 #PayPayください #お金ください #おかねください #現金配布 #投げ銭 #支援希望 #カンパ #物乞い #金欲しい
```

## 4. 費用

**ファイルとログを読むだけ。LLM を呼ばない。ブラウザも触らない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**タグを足す変更も $0**（フォローは DOM 操作で LLM を呼ばない）。
増えるのは Mac の CPU 時間と通信だけ。
返信ループの実績は 1 回 $0.003 ／ 1 日 $0.027 ／ 1 か月 約 $0.81
（x68 の適用後は上限 1 日 $0.048 ／ 1 か月 $1.44）。
