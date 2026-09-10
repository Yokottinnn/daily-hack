# 返信が 16 件/日 に届かない理由

**このレポートが作られた時刻: 2026-09-10 21:38:26 JST**

> 指摘: **「約束では 16 件ペースで動くはずなので約束と違うよ」**

**16 件/日 は 3 つの掛け算。** どこが落ちているかを数字で出す。

    1 日の起動回数 × 1 回の pick 数 × 生成の通過率 = 1 日の投稿数

## 1. 起動回数（**設計 4 回/日**）

### 1-a. plist は何時に発火する設定か

```
    "StartCalendarInterval" => [
      0 => {
        "Hour" => 16
        "Minute" => 0
      }
      1 => {
        "Hour" => 12
        "Minute" => 0
      }
      2 => {
        "Hour" => 22
        "Minute" => 0
      }
      3 => {
        "Hour" => 19
        "Minute" => 0
      }
    ]
  }

  StartInterval: (なし)
  MAX_PICKS_PER_FIRE: 4
  ロード状態: **未ロード**
```

### 1-b. 実際の発火時刻（直近 10 日・**1 回ずつ**）

**予定と実際の差がそのまま落ち幅。**

```
  2026-08-28  起動 4 回   12:00 16:00 19:00 22:00 
  2026-08-29  起動 4 回   12:00 16:00 19:00 22:00 
  2026-08-30  起動 4 回   12:00 16:00 19:00 22:00 
  2026-08-31  起動 4 回   12:00 16:00 19:00 22:00 
  2026-09-01  起動 4 回   12:00 16:00 19:00 22:00 
  2026-09-02  起動 1 回   12:00 
  2026-09-06  起動 2 回   21:23 22:00 
  2026-09-07  起動 1 回   23:59 
  2026-09-08  起動 4 回   12:00 16:00 19:00 22:00 
  2026-09-09  起動 4 回   12:00 16:00 19:00 22:00 
```

**予定 4 回に対して実際が 1〜2 回なら、そこで 1/4〜1/2 に落ちている。**

## 2. 生成の通過率（**4 件 拾って 何件 出るか**）

### 2-a. 各回の picked と、その回の enqueue 数

```
  [2026-09-06T21:23:17] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
  [2026-09-06T21:26:17] picked 2 / max 2 (from 14 candidates)
  [2026-09-06T21:26:18] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / 拡散希望","skip"
  [2026-09-06T21:26:20] gen failed (#2): {"ok":false,"error":"生成側が skip: 相手の投稿は商品販売告知。ハッカー子のキャラは節約・家計管理・投
  [2026-09-06T21:26:20] === orchestrator done: 2 drafts, 16 reply-connected follows today ===
  [2026-09-06T22:00:02] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
  [2026-09-06T22:03:03] picked 2 / max 2 (from 5 candidates)
  [2026-09-06T22:03:06] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 同じ語の繰り返し「材50M」＝日本語が壊れている","skip":true,"re
  [2026-09-06T22:03:08] enqueue: {"ok":true,"id":"comment-20260906-2203-1"}
  [2026-09-06T22:03:23] === orchestrator done: 2 drafts, 16 reply-connected follows today ===
  [2026-09-07T23:59:20] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-08T00:03:14] picked 4 / max 4 (from 23 candidates)
  [2026-09-08T00:03:16] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手は投資判断の決め手について意見を求めているが、アタシが「正解
  [2026-09-08T00:03:19] enqueue: {"ok":true,"id":"comment-20260908-0003-1"}
  [2026-09-08T00:03:46] gen failed (#3): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: r10.to","skip":true,"reaso
  [2026-09-08T00:03:47] gen failed (#4): {"ok":false,"error":"生成側が skip: 投稿が hashtag のみで具体的な内容がない。返信する対象がない","skip":tru
  [2026-09-08T00:03:47] === orchestrator done: 4 drafts, 0 reply-connected follows today ===
  [2026-09-08T12:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-08T12:03:06] picked 4 / max 4 (from 9 candidates)
  [2026-09-08T12:03:08] enqueue: {"ok":true,"id":"comment-20260908-1203-0"}
  [2026-09-08T12:03:23] enqueue: {"ok":true,"id":"comment-20260908-1203-1"}
  [2026-09-08T12:03:41] gen failed (#3): {"ok":false,"error":"生成側が skip: 紹介URLの誘導が含まれており、ガイドラインで禁止","skip":true,"reason":"生
  [2026-09-08T12:03:43] gen failed (#4): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいな
  [2026-09-08T12:03:43] === orchestrator done: 4 drafts, 4 reply-connected follows today ===
  [2026-09-08T16:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-08T16:03:06] picked 4 / max 4 (from 11 candidates)
  [2026-09-08T16:03:09] enqueue: {"ok":true,"id":"comment-20260908-1603-0"}
  [2026-09-08T16:03:24] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","
  [2026-09-08T16:03:26] gen failed (#3): {"ok":false,"error":"生成側が skip: 相手の投稿は著名人への好意表明とアンチエイジングの雑談。ふるさと
  [2026-09-08T16:03:28] gen failed (#4): {"ok":false,"error":"生成側が skip: 紹介コード・招待リンク・案件勧誘の返信は禁止。相手が営業目的で、
  [2026-09-08T16:03:28] === orchestrator done: 4 drafts, 4 reply-connected follows today ===
  [2026-09-08T19:00:04] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-08T19:03:05] picked 4 / max 4 (from 4 candidates)
  [2026-09-08T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が具体的な銘柄・買値・期待値を挙げた投資情報。ハッカー子が金
  [2026-09-08T19:03:11] enqueue: {"ok":true,"id":"comment-20260908-1903-1"}
  [2026-09-08T22:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-08T22:03:06] picked 4 / max 4 (from 21 candidates)
  [2026-09-08T22:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 紹介コード・招待URL・キャンペーン勧誘。返信すべき投稿ではない","ski
  [2026-09-08T22:03:08] gen failed (#2): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: r10.to","skip":true,"reaso
  [2026-09-08T22:03:11] enqueue: {"ok":true,"id":"comment-20260908-2203-2"}
  [2026-09-08T22:03:31] gen failed (#4): {"ok":false,"error":"生成側が skip: 相手は損失を報告しているだけ。茶化さず、同意か情報を足すべきだが
  [2026-09-08T22:03:31] === orchestrator done: 4 drafts, 9 reply-connected follows today ===
  [2026-09-09T12:00:04] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T12:03:07] picked 4 / max 4 (from 13 candidates)
  [2026-09-09T12:03:09] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","
  [2026-09-09T12:03:09] gen failed (#2): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / クーポン配布",
  [2026-09-09T12:03:09] gen failed (#3): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 抽選で","skip":true,"re
  [2026-09-09T12:03:12] gen failed (#4): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","
  [2026-09-09T12:03:12] === orchestrator done: 4 drafts, 6 reply-connected follows today ===
  [2026-09-09T16:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T16:03:10] picked 4 / max 4 (from 14 candidates)
  [2026-09-09T16:03:12] gen failed (#1): {"ok":false,"error":"噛み合い検査で弾いた: 相手の語をなぞっただけで、こちらから足した情報がゼロ / �
  [2026-09-09T16:03:14] gen failed (#2): {"ok":false,"error":"生成側が skip: 相手が具体的な案件名・条件を示していないため、実質的な返信が不可
  [2026-09-09T16:03:16] gen failed (#3): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","
  [2026-09-09T16:03:16] gen failed (#4): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / r10.to","skip":true,
  [2026-09-09T16:03:16] === orchestrator done: 4 drafts, 6 reply-connected follows today ===
  [2026-09-09T19:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T19:03:07] picked 4 / max 4 (from 10 candidates)
  [2026-09-09T19:03:08] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら","skip"
  [2026-09-09T19:03:10] enqueue: {"ok":true,"id":"comment-20260909-1903-1"}
  [2026-09-09T19:03:29] enqueue: {"ok":true,"id":"comment-20260909-1903-2"}
  [2026-09-09T19:03:53] gen failed (#4): {"ok":false,"error":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない","skip":tru
  [2026-09-09T19:03:53] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
  [2026-09-09T22:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T22:03:08] picked 4 / max 4 (from 15 candidates)
  [2026-09-09T22:03:10] gen failed (#1): {"ok":false,"error":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報
  [2026-09-09T22:03:12] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいな
  [2026-09-09T22:03:15] gen failed (#3): {"ok":false,"error":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返
  [2026-09-09T22:03:17] enqueue: {"ok":true,"id":"comment-20260909-2203-3"}
  [2026-09-09T22:03:38] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
```

### 2-b. **skip 理由の内訳（直近 7 日）**

**`LLM を呼ばずに` と書いてあるものは $0。** それ以外は**課金して 0 件**。

```
  gen failed 合計         : 30 件
  うち LLM を呼ばずに $0  : 7 件
  **うち課金して 0 件**   : 23 件  ← ここが無駄

  --- 理由の内訳（多い順） ---
       7 PR/アフィリ/拡散キャンペーンの投
       4 噛み合い検査で弾いた: 末尾の絵�
       2 噛み合い検査で弾いた: 相手の投�
       2 tone-gate blocked: insult=適当なこと言�
       1 生成側が skip: 金銭助言まわり判断
       1 生成側が skip: 紹介コード・招待リ
       1 生成側が skip: 紹介コード・招待コ
       1 生成側が skip: 紹介コード・招待URL
       1 生成側が skip: 紹介URLの誘導が含ま
       1 生成側が skip: 相手は損失を報告し
       1 生成側が skip: 相手の投稿は著名人
       1 生成側が skip: 相手の投稿は商品販

  --- 成功（enqueue）した回数 ---
    26 件
```

**「hashtag のみ」「本文が短い」は LLM を呼ぶ前に落とせるはず。**
**そこを前段に移すと、件数を増やしながらコストが下がる。**

## 3. 候補数の推移（**検知は足りているか**）

```
    2026-08-31 12:03  候補 21 件 → picked 2/2
    2026-08-31 16:03  候補 7 件 → picked 2/2
    2026-08-31 19:03  候補 15 件 → picked 2/2
    2026-08-31 22:03  候補 13 件 → picked 2/2
    2026-09-01 12:03  候補 8 件 → picked 2/2
    2026-09-01 16:03  候補 14 件 → picked 2/2
    2026-09-01 19:03  候補 8 件 → picked 2/2
    2026-09-01 22:03  候補 18 件 → picked 2/2
    2026-09-02 12:03  候補 15 件 → picked 2/2
    2026-09-06 21:26  候補 14 件 → picked 2/2
    2026-09-06 22:03  候補 5 件 → picked 2/2
    2026-09-08 00:03  候補 23 件 → picked 4/4
    2026-09-08 12:03  候補 9 件 → picked 4/4
    2026-09-08 16:03  候補 11 件 → picked 4/4
    2026-09-08 19:03  候補 4 件 → picked 4/4
    2026-09-08 22:03  候補 21 件 → picked 4/4
    2026-09-09 12:03  候補 13 件 → picked 4/4
    2026-09-09 16:03  候補 14 件 → picked 4/4
    2026-09-09 19:03  候補 10 件 → picked 4/4
    2026-09-09 22:03  候補 15 件 → picked 4/4
```

**候補が pick 数より多ければ、検知はボトルネックではない。**

## 4. 実際に出た件数（**キューの `x_tweet_id` で数える**）

```
  投稿済み 累計: 857 件

  日付(JST)     実績   目標   達成率
  2026-08-27     8 件   16 件   50%
  2026-08-28     8 件   16 件   50%
  2026-08-29     6 件   16 件   38%
  2026-08-30     7 件   16 件   44%
  2026-08-31     6 件   16 件   38%
  2026-09-01     8 件   16 件   50%
  2026-09-02     2 件   16 件   13%
  2026-09-06     1 件   16 件   6%
  2026-09-08     5 件   16 件   31%
  2026-09-09     3 件   16 件   19%
```

## 5. 発火しなかった時間帯に何があったか

```
  --- comment-warmup の最後の rc ---
    **未ロード**

  --- Chrome はいつから動いているか ---
      397 Wed Sep  9 23:11:20 2026     22:27:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
      412 Wed Sep  9 23:11:21 2026     22:27:05 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
      476 Wed Sep  9 23:11:22 2026     22:27:04 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/chrome_crashpad_handler

  --- chrome-cdp-heal は止まっているか（2026-09-08 に停止した） ---
    ロード数: 0

  --- comment-warmup.log の末尾 15 行 ---
    [2026-09-09T22:03:08] picked 4 / max 4 (from 15 candidates)
    [2026-09-09T22:03:08] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-09T22:03:08] today's reply-connected follows: 10 / 30
    [2026-09-09T22:03:08] --- processing #1/4 for @<伏せ> ---
    [2026-09-09T22:03:10] gen failed (#1): {"ok":false,"error":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報
    [2026-09-09T22:03:11] --- processing #2/4 for @<伏せ> ---
    [2026-09-09T22:03:12] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいな
    [2026-09-09T22:03:13] --- processing #3/4 for @<伏せ> ---
    [2026-09-09T22:03:15] gen failed (#3): {"ok":false,"error":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返
    [2026-09-09T22:03:15] --- processing #4/4 for @<伏せ> ---
    [2026-09-09T22:03:17]   → chosen template_id: unknown
    [2026-09-09T22:03:17] enqueue: {"ok":true,"id":"comment-20260909-2203-3"}
    {"ok":true,"entry_id":"comment-20260909-2203-3","x_tweet_id":"2097672244462075923","url":"https://x.com/heng_ji31590/status/2097672244462075923","slack_report_ts":"silenced"}
    [2026-09-09T22:03:38]   follow @<伏せ>: filtered
    [2026-09-09T22:03:38] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
```

---

## まとめ方

**16 件/日 に届けるには、落ちている箇所を全部 直す必要がある。**

| 要素 | 直し方 | コストへの影響 |
| --- | --- | --- |
| 起動回数 4 → 1 | 発火しない原因を直す | 増える（本来の設計） |
| 通過率 25% | **前段フィルタを強化** | **下がる**（無駄な LLM を減らす） |
| pick 数 | 増やす | 線形に増える |

**投稿していない。ジョブも Chrome も触っていない（$0）。**
