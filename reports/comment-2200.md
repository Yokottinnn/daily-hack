# 22:00 の発火の結果（2026-09-27 22:08 JST・$0）

**このレポートが作られた時刻: 2026-09-27 22:08:05 JST**

> **読むだけ。** 撃っていない。閾値も触っていない。

## 1. 落ち着くまで待つ（最大 240 秒）

```
  はじめの pending: 0 件
  待った秒数: 0 / いまの pending: 0 件 ← 落ち着いた
```

## 2. 今日の発火 4 回 の内訳（**picked と出た数を並べる**）

```
  [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
  [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
  [2026-09-27T16:04:32] === orchestrator done: 2 drafts, 8 reply-connected follows today ===
  [2026-09-27T17:19:27] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
  [2026-09-27T17:22:28] picked 3 / max 6 (from 4 candidates)
  [2026-09-27T17:23:24] === orchestrator done: 3 drafts, 10 reply-connected follows today ===
  [2026-09-27T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
  [2026-09-27T19:03:06] picked 2 / max 6 (from 6 candidates)
  [2026-09-27T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が求めているのは『即返信できるDM相手』という人間関係の話。ハッカー子が返すべ�
  [2026-09-27T19:03:11] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。触れるべき固有名詞・数字・状況がない�
  [2026-09-27T19:03:11] === orchestrator done: 2 drafts, 11 reply-connected follows today ===
  [2026-09-27T22:00:00] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
  [2026-09-27T22:03:01] picked 6 / max 6 (from 16 candidates)
  [2026-09-27T22:03:58] gen failed (#4): {"ok":false,"error":"生成側が skip: 相手の投稿が一般的な情報提示（YouTubeはブルーオーシャン）で、具体的な状況・数字・固
  [2026-09-27T22:04:20] gen failed (#6): {"ok":false,"error":"生成側が skip: 金銭授受・貢ぎ募集の投稿。返信すると自分も同意・推奨に見える。X規約リスク（投げ銭
  [2026-09-27T22:04:20] === orchestrator done: 6 drafts, 12 reply-connected follows today ===
```

**`gen failed` の実体は `skip`。** ラベルが誤解を招くが、故障ではない。

## 3. 実際に出たもの（**一次情報：キューの `x_tweet_id`**）

```json
  今日（JST）の comment エントリ: 9 件

  16:04:12  status=posted
    https://x.com/heng_ji31590/status/2104104794084544828
  16:04:32  status=posted
    https://x.com/heng_ji31590/status/2104104877668680175
  17:22:43  status=posted
    https://x.com/heng_ji31590/status/2104124554331468031
  17:23:01  status=posted
    https://x.com/heng_ji31590/status/2104124631607378382
  17:23:19  status=posted
    https://x.com/heng_ji31590/status/2104124707306148018
  22:03:18  status=posted
    https://x.com/heng_ji31590/status/2104195163627368622
  22:03:36  status=posted
    https://x.com/heng_ji31590/status/2104195242643828904
  22:03:51  status=posted
    https://x.com/heng_ji31590/status/2104195303989825760
  22:04:14  status=posted
    https://x.com/heng_ji31590/status/2104195402329444678

  → **出た 9 件 / 出ていない 0 件**
  → **22:00 以降の行が在るか**が今回の答え
```

## 4. 既にある警報はいま何と言っているか

**`last_reply` が 8 時間 を超えると Slack に 🚨。** いまの値を出す。

```
  最後の返信: 2026-09-27 22:04:14 JST
  経過: 0.1 時間 → stale = false（鳴らない）

  **22:00 が 0 件 なら、翌 12:00 まで 14 時間 空く。** 01:00 ごろに 8 時間 を超えて鳴る

  警報の印（/tmp/.x-reply-stale-alerted）: 無い（まだ鳴っていない）
```

## 5. ジョブは載ったままか

```
    	state = not running
    	runs = 3
    	last exit code = 0
    		state = active
    		state = active
    → **載っている**
```

---

## 読み方

| §3 の出方 | 意味 |
| --- | --- |
| 22:00 以降の行が在り `x_tweet_id` 付き | **出た。** 2 回 連続にはならなかった |
| 22:00 以降の行が無く §2 が `skip` | **2 回 連続で 0 件。** 候補の質か検査の厳しさを見る |
| 22:00 の `start` すら無い | **発火していない。** plist を見る |

| §4 の出方 | 次 |
| --- | --- |
| `stale = true` | **もう鳴る状態。** 閾値（8 時間）を発火間隔に合わせるか判断する |
| 印が在る | **既に鳴った。** Slack の `C0B4CJHH797` を見る |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
