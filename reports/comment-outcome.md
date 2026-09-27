# 撃った発火の結果（2026-09-27 17:22 JST・$0）

**このレポートが作られた時刻: 2026-09-27 17:22:36 JST**

> **読むだけ。** 撃っていない。設定も触っていない。
> `x173` は `runs` の変化で抜けたため、**走り始めた瞬間を見ていた。** ここで取り直す。

## 1. 今日の発火（**start と結果を対応させる**）

```
  更新 17:22:30 / 517192 bytes

  --- 今日の start と picked ---
    [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
    [2026-09-27T16:03:59] enqueue: {"ok":true,"id":"comment-20260927-1603-0"}
    [2026-09-27T16:04:19] enqueue: {"ok":true,"id":"comment-20260927-1604-1"}
    [2026-09-27T16:04:32]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-27T17:19:27] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
    [2026-09-27T17:22:28] picked 3 / max 6 (from 4 candidates)
    [2026-09-27T17:22:30] enqueue: {"ok":true,"id":"comment-20260927-1722-0"}

  --- 今日の末尾 25 行（そのまま）---
    [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
    [2026-09-27T16:03:57] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-27T16:03:57] today's reply-connected follows: 7 / 30
    [2026-09-27T16:03:57] --- processing #1/2 for @<伏せ> ---
    [2026-09-27T16:03:59]   → chosen template_id: unknown
    [2026-09-27T16:03:59] enqueue: {"ok":true,"id":"comment-20260927-1603-0"}
    [2026-09-27T16:04:16]   follow @<伏せ>: followed
    [2026-09-27T16:04:16]   recorded in reply-followers.json (count now 8/30)
    [2026-09-27T16:04:17] --- processing #2/2 for @<伏せ> ---
    [2026-09-27T16:04:19]   → chosen template_id: unknown
    [2026-09-27T16:04:19] enqueue: {"ok":true,"id":"comment-20260927-1604-1"}
    [2026-09-27T16:04:32]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-27T16:04:32] === orchestrator done: 2 drafts, 8 reply-connected follows today ===
    [2026-09-27T17:19:27] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
    [2026-09-27T17:22:28] picked 3 / max 6 (from 4 candidates)
    [2026-09-27T17:22:28] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-27T17:22:28] today's reply-connected follows: 9 / 30
    [2026-09-27T17:22:28] --- processing #1/3 for @<伏せ> ---
    [2026-09-27T17:22:30]   → chosen template_id: unknown
    [2026-09-27T17:22:30] enqueue: {"ok":true,"id":"comment-20260927-1722-0"}
```

## 2. キューの直近 2 時間（**一次情報**）

**ログではなくキューを見る。** `x_tweet_id` が在れば出ている。

```json
  直近 2 時間の comment エントリ: 3 件（キュー全体 1282 行）
    16:04:12  id=comment-20260927-1603-0  status=posted
      **出た**: https://x.com/heng_ji31590/status/2104104794084544828
      文: ラスト販売か。タピオカの日って期間限定だったんだ。湘南モールフィルなら立地いいし、20:30までなら仕事帰りでも間に合うわね。で、閉店後はそのスペースどうなるの？別の店舗が入るのかな😊 
    16:04:32  id=comment-20260927-1604-1  status=posted
      **出た**: https://x.com/heng_ji31590/status/2104104877668680175
      文: クラブラウンジでリコッタパンケーキ、いいわね。焼きたてふわふわって朝から気分上がるわ。で、隠れメニューのクロワッサンってスタッフに言えば出てくるやつ？それとも何か条件あるの😊 
    17:22:30  id=comment-20260927-1722-0  status=pending
      **tweet_id が無い**
      文: 手取り18万から580万か。任意整理からの立て直しって、固定費の削り方が全部リアルになるのよね。で、そのNoteって月いくらまで削ったの？生活費の目安が知りたいわ💸 

  → **出たもの 2 件 / 積まれたもの 3 件**
```

## 3. ジョブはまだ載っているか

```
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
    	state = running
    	runs = 1
    	last exit code = (never exited)
    		state = active
    		state = active
    → **載っている**
```

## 4. 守りが働いた形跡（**働いたなら成功**）

```
  comment-orchestrator     wrong-page 0 / no-focus 0 / text-mismatch 0 / x154 0
  comment-warmup           wrong-page 0 / no-focus 0 / text-mismatch 0 / x154 0
```

**`text-mismatch` が出ていたら、それは打たずに止めた成功。** 中身を見る。

---

## 読み方

| §2 の出方 | 意味 |
| --- | --- |
| **出たもの 1 件 以上** | **再開して、実際にコメントが出た。** URL を報告する |
| 積まれたが tweet_id が無い | **積んで出ていない。** publisher 側を見る |
| **0 件** ／ §1 に `no candidates` | **走ったが候補が無かった。** `MIN_LIKES=2` / `MAX_AGE_HOURS=18` の条件次第。故障ではない |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
