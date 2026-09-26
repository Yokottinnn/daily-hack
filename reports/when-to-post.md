# いつ投稿すべきか（2026-09-27 00:20 JST・$0）

**このレポートが作られた時刻: 2026-09-27 00:20:50 JST**

> **読むだけ。** 積んでいない。投稿もしていない。
> **一般論ではなく、自分の実績から出す。**

## 1. 自分の投稿を時刻ごとに並べる（**一次情報**）

`post_queue.json` の `posted_at` と `x_tweet_id` を突き合わせる。
**表示回数が取れているものは一緒に出す。**

```
  キューの行 1278 件 / **実際に出たもの 1086 件**

  時刻（JST）  件数  種類
  00:00          5   trend_post,thread,comment
  01:00          1   comment
  03:00          2   comment
  05:00         31   comment
  06:00          2   comment
  08:00          6   thread,comment
  09:00         85   trend_post,comment
  10:00          4   trend_post,comment,thread
  11:00          8   comment
  12:00        120   -,thread,comment
  13:00         12   comment,post,thread
  14:00         93   -,comment
  15:00          6   comment
  16:00        193   comment,trend_post
  17:00          9   comment,thread
  18:00          5   -,comment,thread
  19:00        150   -,comment,trend_post,thread
  20:00         92   -,comment,thread
  21:00          8   -,comment,trend_post,thread
  22:00        254   -,comment,thread,trend_qt

  **これは「何時に出したか」であって「何時が効いたか」ではない。** §2 を見る
```

## 2. 表示回数の実績があるか

**無ければ「何時が効くか」は自分のデータからは言えない。** そう書く。

```
  x-impressions.log                       3840 bytes  更新 09-27 00:05
  post-metrics.json                     213832 bytes  更新 08-09 14:05
```

`x-impressions.log` の中身（末尾 30 行）:

```
   "appended": 7
  }
  {
   "elapsed_sec": 44,
   "target": 8,
   "read": 7,
   "skipped": 1,
   "appended": 7
  }
  {
   "elapsed_sec": 44,
   "target": 8,
   "read": 7,
   "skipped": 1,
   "appended": 7
  }
  {
   "elapsed_sec": 42,
   "target": 8,
   "read": 7,
   "skipped": 1,
   "appended": 7
  }
  {
   "elapsed_sec": 42,
   "target": 8,
   "read": 7,
   "skipped": 1,
   "appended": 7
  }
```

## 3. 予約が効く状態か（**ジョブが載っていなければ出ない**）

```
  ai.openclaw.auto-x-publisher         載っていない
  ai.openclaw.poll-approvals           載っていない
  ai.openclaw.x-publisher              載っていない
  ai.openclaw.publish-queue            載っていない

  --- LaunchAgents に在る publisher 系の plist ---
  ai.openclaw.poll-approvals.plist
  ai.openclaw.publish-hanabi-oneshot.plist
  disabled-no-approval
```

publisher の実体が在るか:

```
  auto-x-publisher.js            250 行  更新 07-25 16:26
  poll-approvals.js              267 行  更新 08-15 15:07
  run-publish.sh                 210 行  更新 09-23 21:06
```

## 4. `scheduled_at` を実際に使っている行が在るか

**在れば書式を写せる。** 無ければ契約書どおりに書く。

```
  scheduled_at を含む行: 26
    2398:      "scheduled_at": "2026-06-06T23:00:00.000Z",
    2472:      "scheduled_at": "2026-06-07T23:00:00.000Z",
    2547:      "scheduled_at": "2026-06-08T23:00:00.000Z",
    2827:      "scheduled_at": "2026-06-09T23:00:00.000Z",
    2900:      "scheduled_at": "2026-06-10T23:00:00.000Z",
  auto_publish を含む行: 29
```

---

## 読み方

| 出方 | 何が言えるか |
| --- | --- |
| §2 に表示回数が**在る** | **自分の実績で時刻を選べる。** 一般論を使わずに済む |
| §2 が**空** | **自分のデータでは言えない。** そう言ったうえで、外の一般論しか無いと断る |
| §3 でジョブが**載っていない** | **予約しても出ない。** 先に載せる話になる |
| §4 に `scheduled_at` の実績が在る | **その書式を写す**（推測しない） |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
