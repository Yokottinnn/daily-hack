# comment-warmup をいま 1 回 撃つ（2026-09-27 17:19 JST）

**このレポートが作られた時刻: 2026-09-27 17:19:26 JST**

> **設定は変えない。** 量も plist のまま（`MAX_PICKS_PER_FIRE=6`）。
> **この 1 回の費用: 最大 $0.025**（6 picks × 実測 $0.00417/件）

## 1. 撃つ前

```
  載っている / runs = 0
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
    	state = not running
  comment-warmup.log       673722 bytes
  comment-orchestrator.log 516606 bytes
```

## 2. 撃つ

```
  kickstart -k rc=0 
  （**rc=0 は「やった」証拠にならない**。§3 で runs とログを見る）
```

## 3. 本当に走ったか（**runs とログで見る**）

**素の bash で待つ**（`timeout` は Mac に無い）。最大 200 秒。

```
  待った秒数: 0
  runs                      0 → 1 ← **増えた**
  comment-warmup.log        673722 → 673722 bytes 
  comment-orchestrator.log  516606 → 516606 bytes 

  → **走った**
```

## 4. 出力（**見た件数と打った件数を両方**）

```
  ===== comment-orchestrator.log（更新 16:04:32）=====
    [2026-09-25T22:05:39]   follow @<伏せ>: followed
    [2026-09-25T22:05:39]   recorded in reply-followers.json (count now 16/30)
    [2026-09-25T22:05:39] === orchestrator done: 6 drafts, 16 reply-connected follows today ===
    [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    early exit: hashtag loop, all=22
      ng-filter: 27 件中 1 件を弾いた (link=1)
        弾いた理由 link: line.me
    [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
    [2026-09-27T16:03:57] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-27T16:03:57] today's reply-connected follows: 7 / 30
    [2026-09-27T16:03:57] --- processing #1/2 for @<伏せ> ---
      tone-gate: 通過
    [2026-09-27T16:03:59]   → chosen template_id: unknown
    [2026-09-27T16:03:59] enqueue: {"ok":true,"id":"comment-20260927-1603-0"}
    [2026-09-27T16:04:16]   follow @<伏せ>: followed
    [2026-09-27T16:04:16]   recorded in reply-followers.json (count now 8/30)
    [2026-09-27T16:04:17] --- processing #2/2 for @<伏せ> ---
      tone-gate: 通過
    [2026-09-27T16:04:19]   → chosen template_id: unknown
    [2026-09-27T16:04:19] enqueue: {"ok":true,"id":"comment-20260927-1604-1"}
    [2026-09-27T16:04:32]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-27T16:04:32] === orchestrator done: 2 drafts, 8 reply-connected follows today ===

  ===== comment-warmup.log（更新 22:05:39）=====
    [2026-09-25T22:03:33] --- processing #3/6 for @<伏せ> ---
    [2026-09-25T22:03:35]   → chosen template_id: unknown
    [2026-09-25T22:03:35] enqueue: {"ok":true,"id":"comment-20260925-2203-2"}
    {"ok":true,"entry_id":"comment-20260925-2203-2","x_tweet_id":"2103470520159379840","url":"https://x.com/heng_ji31590/status/2103470520159379840","slack_report_ts":"silenced"}
    [2026-09-25T22:03:49]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-25T22:03:49] --- processing #4/6 for @<伏せ> ---
    [2026-09-25T22:03:51]   → chosen template_id: unknown
    [2026-09-25T22:03:51] enqueue: {"ok":true,"id":"comment-20260925-2203-3"}
    {"ok":true,"entry_id":"comment-20260925-2203-3","x_tweet_id":"2103470796253638752","url":"https://x.com/heng_ji31590/status/2103470796253638752","slack_report_ts":"silenced"}
    [2026-09-25T22:04:55]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-25T22:04:55] --- processing #5/6 for @<伏せ> ---
    [2026-09-25T22:04:58]   → chosen template_id: unknown
    [2026-09-25T22:04:58] enqueue: {"ok":true,"id":"comment-20260925-2204-4"}
    {"ok":true,"entry_id":"comment-20260925-2204-4","x_tweet_id":"2103470869985329429","url":"https://x.com/heng_ji31590/status/2103470869985329429","slack_report_ts":"silenced"}
    [2026-09-25T22:05:16]   follow @<伏せ>: filtered
    [2026-09-25T22:05:16] --- processing #6/6 for @<伏せ> ---
    [2026-09-25T22:05:19]   → chosen template_id: unknown
    [2026-09-25T22:05:19] enqueue: {"ok":true,"id":"comment-20260925-2205-5"}
    {"ok":true,"entry_id":"comment-20260925-2205-5","x_tweet_id":"2103470956677398659","url":"https://x.com/heng_ji31590/status/2103470956677398659","slack_report_ts":"silenced"}
    [2026-09-25T22:05:39]   follow @<伏せ>: followed
    [2026-09-25T22:05:39]   recorded in reply-followers.json (count now 16/30)
    [2026-09-25T22:05:39] === orchestrator done: 6 drafts, 16 reply-connected follows today ===

```

## 5. キューに積まれたか（**一次情報**）

**ログではなくキューを見る**（最上位ルール 11）。

```json
  直近 20 分の comment エントリ: 0 件（キュー全体 1281 行）
  **0 件。** 候補が無かったか、まだ生成まで届いていない
```

---

## 読み方

| §3 / §5 の出方 | 意味 |
| --- | --- |
| runs が増え、§5 に `x_tweet_id` が在る | **再開して、実際にコメントが出た** |
| runs が増えたが §5 が 0 件 | **走ったが候補が無かった。** `MIN_LIKES=2` / `MAX_AGE_HOURS=18` の条件次第 |
| runs が増えない | **kickstart が効いていない。** `rc=0` を信じない |
| §4 に `text-mismatch` | **守りが働いた。** 打たずに止めたので成功 |

**この 1 回の費用: 最大 $0.025／回・$0.025／日・$0.025／月**（1 回しか走らない）。
**常駐ぶんは別で、実測 $0.081／日・約 $2.43／月。**
