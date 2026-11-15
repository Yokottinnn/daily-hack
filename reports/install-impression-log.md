# 表示回数を 3 時間おきに記録する（2026-09-21 02:30 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 02:30:32 JST**

> **取り方は x113 で確定した。推測ではない。**
> `role="group"` の `aria-label` に 返信・リポスト・いいね・表示 が全部 入っている。
> `textContent` は `"112"` と数字が連結されて出るので使わない。

## 1. 置いたもの

```
  /Users/ny/.openclaw/workspace/scripts/x-impressions.js 3418 bytes
  /Users/ny/Library/LaunchAgents/com.dailyhack.x-impressions.plist 767 bytes
  node: /usr/local/bin/node
```

## 2. 構文は通るか（**走らせる前に見る**）

```
  node --check: 通った
```

## 3. 載せる（**`load` ではなく `bootstrap`**・最上位ルール 13）

```
  bootstrap を打った（rc は証拠にならない）
  **launchctl list に出ている ＝ 載った**
  50373	0	com.dailyhack.x-impressions
```

## 4. 1 回 走らせて、実際に書けるか見る

```
  rc=0
{
 "elapsed_sec": 43,
 "target": 8,
 "read": 7,
 "skipped": 1,
 "appended": 7
}

  記録: 7 行
  --- 直近 3 行 ---
  {"at":"2026-09-20T17:31:05.849Z","id":"blog-promo-20260802-budget-overseas-resorts-2026","tweet_id":"2083939788755964109","posted_at":"2026-08-02T15:37:02.233Z","age_h":1177.9,"replies":1,"reposts":null,"likes":4,"views":237}
  {"at":"2026-09-20T17:31:11.162Z","id":"blog-promo-20260726-summer-electricity-saving-2026","tweet_id":"2083545389777727590","posted_at":"2026-08-01T13:28:50.971Z","age_h":1204,"replies":1,"reposts":null,"likes":1,"views":184}
  {"at":"2026-09-20T17:31:16.432Z","id":"blog-promo-20260726-price-hike-2026-summer-defense","tweet_id":"2083545028316835911","posted_at":"2026-08-01T13:27:23.886Z","age_h":1204.1,"replies":1,"reposts":null,"likes":2,"views":152}
```

## 5. 読み出し方

**この仕組みは push しない。** heartbeat と同じブランチへ同時に書くと競合する。
中身を見るときは `ops/tasks` を 1 本 足して dump する（x111 と同じやり方）。

```
  ~/.openclaw/workspace/data/x-impressions.jsonl
  {"at":…,"id":…,"tweet_id":…,"posted_at":…,"age_h":…,"views":…,…}
```

**`posted_at` を一緒に残している。** これが無いと「何時に出したか」と結びつかない。

## 6. 費用

**DOM を読むだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり（3 時間おき＝8 回） | **$0** |
| 1 か月あたり | **$0** |

**ラベルは `com.dailyhack.*`。** `ai.openclaw.*` にすると `tab-guard.js` に
一斉に外される（2026-09-09 に 48 本 が 11 日間 外れたまま だった）。
