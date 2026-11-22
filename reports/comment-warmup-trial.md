# comment-warmup を 1 回だけ試す（2026-09-27 16:00 JST）

**このレポートが作られた時刻: 2026-09-27 16:00:55 JST**

> **常駐には戻していない。** plist はリネームしたまま、`bootstrap` もしていない。
> **この試走の費用は最大 $0.0083（2 picks × 実測 $0.00417/件・Haiku 4.5）。**

## 1. 止まったままか（**戻していないことの確認**）

```
  載っていない（止まったまま。想定どおり）
  plist.disabled: あり
  plist（有効な名前）: 無い（対象外のまま）
```

## 2. plist から本当のコマンドを読む（**推測しない**）

```
  Array {
      /bin/bash
      /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
  }

  --- EnvironmentVariables ---
  Dict {
      MIN_LIKES = 2
      MAX_AGE_HOURS = 18
      MAX_PICKS_PER_FIRE = 6
      REPLY_FOLLOW_DAILY_CAP = 30
  }
```

## 3. 守りが入っているか（**実体で確かめる**）

**`x150` / `x154` は「置いた」ことまでは確認済み。ここでは消えていないかを見る。**

```
  対象: engage-via-playwright.js（176 行）

  x150 ① 返信先ページに居るか   0 箇所
  x150 ② フォーカスが載ったか   0 箇所
  x150 ③ 打った文の照合         0 箇所
  x154    いいねを付ける        0 箇所

  （消えていれば 0 になる。0 が在れば、戻す前に入れ直す）

  --- 出口の検査が噛んでいるか（x-reply-style §4 / §4-B）---
  対象: comment-orchestrator.sh
  tone-gate       1 箇所
  relevance       1 箇所
```

## 4. 1 回だけ走らせる（**`MAX_PICKS_PER_FIRE=2` に下げる**）

**量は上げない**（`x-reply-style` §5「量は最後」）。
確かめたいのは守りが効くかで、件数ではない。

```
  打つもの: /bin/bash /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh 
  環境: MAX_PICKS_PER_FIRE=2 FORCE_RUN=1（plist の値は上書きする）

  引き継いだ環境変数: 5 件

  --- 実行（上限 240 秒。超えたら打ち切る）---
  rc=0

  --- 出力の末尾 40 行 ---
    [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
    [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
    [2026-09-27T16:03:57] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-27T16:03:57] today's reply-connected follows: 7 / 30
    [2026-09-27T16:03:57] --- processing #1/2 for @<伏せ> ---
    [2026-09-27T16:03:59]   → chosen template_id: unknown
    [2026-09-27T16:03:59] enqueue: {"ok":true,"id":"comment-20260927-1603-0"}
    [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
    {"ok":true,"entry_id":"comment-20260927-1603-0","x_tweet_id":"2104104794084544828","url":"https://x.com/heng_ji31590/status/2104104794084544828","slack_report_ts":"silenced"}
    [2026-09-27T16:04:16]   follow @<伏せ>: followed
    [2026-09-27T16:04:16]   recorded in reply-followers.json (count now 8/30)
    [2026-09-27T16:04:17] --- processing #2/2 for @<伏せ> ---
    [2026-09-27T16:04:19]   → chosen template_id: unknown
    [2026-09-27T16:04:19] enqueue: {"ok":true,"id":"comment-20260927-1604-1"}
    [silence-enforce] this script kind=auto-reply-complete is silent, slack HTTP calls suppressed
    {"ok":true,"entry_id":"comment-20260927-1604-1","x_tweet_id":"2104104877668680175","url":"https://x.com/heng_ji31590/status/2104104877668680175","slack_report_ts":"silenced"}
    [2026-09-27T16:04:32]   follow @<伏せ>: skipped (already in reply-followers.json)
    [2026-09-27T16:04:32] === orchestrator done: 2 drafts, 8 reply-connected follows today ===
```

## 5. 見た件数と打った件数（**両方 出す**）

**数が合わなければ、そこで気づける**（最上位ルール 14）。

```
  候補として見た      1 件
  生成まで進んだ      0 件
  打った（enqueue）   2 件

  --- 守りが働いた形跡（**働いたなら、それは成功**）---
  wrong-page      0 件
  no-focus        0 件
  text-mismatch   0 件

  --- いいね（x154）---
    **x154 の行が 1 本も無い。いいねの処理まで届いていない。**
```

## 6. キューに実際に積まれたか（**一次情報**）

**ログではなくキューを見る**（最上位ルール 11）。

```json
  直近 30 分の comment エントリ: 2 件（キュー全体 1281 行）
    id=comment-20260927-1603-0 status=posted x_tweet_id=2104104794084544828
      文: ラスト販売か。タピオカの日って期間限定だったんだ。湘南モールフィルなら立地いいし、20:30までなら仕事帰りでも間に合うわね。で、閉店後はそのスペースどうなるの？別の店舗が入るのかな😊 
    id=comment-20260927-1604-1 status=posted x_tweet_id=2104104877668680175
      文: クラブラウンジでリコッタパンケーキ、いいわね。焼きたてふわふわって朝から気分上がるわ。で、隠れメニューのクロワッサンってスタッフに言えば出てくるやつ？それとも何か条件あるの😊 
```

---

## 読み方

| 出方 | 次の一手 |
| --- | --- |
| §3 の守りが 4 つとも 1 以上 ／ §5 に壊れた文が無い | **常駐に戻してよい。** plist をリネームし直す |
| §3 に 0 が在る | **入れ直してから戻す。** 守りが消えている |
| §5 に `text-mismatch` が出た | **守りが働いた。** 打たずに止めたので成功。中身を見る |
| §6 の文が壊れている | **戻さない。** 生成側にまだ穴がある |
| §4 が rc=124 | 打ち切った。**Chrome か CDP を先に見る** |

**この試走の費用: 最大 $0.0083／回・$0.0083／日・$0.0083／月**
（1 回しか走らないため。常駐に戻すと別途 実測 $0.081／日・約 $2.43／月）
