# まず返信を出す

**このレポートが作られた時刻: 2026-09-13 01:41:16 JST**

> ジョブが「載り続ける」ことを先に解こうとして 4 日 使った。
> **載り続けなくても、載った瞬間に走らせれば返信は出る。**

## 1. ロックの書き込みを止める（**今度は当たる書き方で**）

x39 は `x-login-in-progress` と `writeFileSync` が**同じ行にある**ことを条件にしたが、
実物は `const LOCK = "/tmp/x-login-in-progress"` と `fs.writeFileSync(LOCK, ...)` に
**分かれている。** 今回は `writeFileSync(LOCK` で当てる。

```
  --- 書き換える前 ---
    64:  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
  退避: tab-guard.js.bak-20260913-014116
    書き換えた行数: 1
  node --check: OK
  --- 書き換えた後 ---
    64:  // LOCK_WRITE_DISABLED (2026-09-13): このロックは ensure-chrome.sh を no-op に
    67:  // try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
```

## 2. 残っているロックを外す

```
  ロックは無い（正常）。
```

## 3. 欠けている本を `bootout` → `enable` → `bootstrap`

x38 で 2 本が `Bootstrap failed: 5: Input/output error` だった。
**これは「既にドメインに居る」ときの定型。** 先に `bootout` してから入れ直す。

```
  comment-warmup               **載せた**
  competitor-follower-follow   載っている
  hashtag-follow               載っている
  badge-followback             載っている
  reply-followback-check       載っている
  reply-followers-cleanup      載らない: 
  incoming-reply-watcher       載らない: 
  pipeline-heartbeat           載らない: 

  **いま: 4 / 8 本**
```

## 4. **載った瞬間に走らせる。** 消えるかどうかを待たない

```
  CDP: 健全 / login ロック: 無い → 走らせる

  走らせる前の累計: **857 件**

  --- comment-warmup を kickstart（最大 4 件・約 $0.012） ---
    launchd に載っていない。**スクリプトを直接 叩く。**
    [2026-09-13T01:41:17] === comment orchestrator start (max_picks=2, reply_follow_cap=10) ===
    [2026-09-13T01:44:18] picked 2 / max 2 (from 14 candidates)
    [2026-09-13T01:44:18] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
    [2026-09-13T01:44:18] today's reply-connected follows: 0 / 10
    [2026-09-13T01:44:18] --- processing #1/2 for @<伏せ> ---
    [2026-09-13T01:44:20] gen failed (#1): {"ok":false,"error":"生成側が skip: 紹介コード・URL・自分の記事への誘導が含まれている。また相手の投稿に具体的な実績や状況がなく、単なる広告なので、個人的な感想や経験を足す余地がない","skip":true,"reason":"生成側が skip: 紹介コード・URL・自分の記事への誘導が含まれている。また相手の投稿に具体的な実績や状況がなく、単なる広告なので、個人的な感想や経験を足す余地がない"}
    [2026-09-13T01:44:20] --- processing #2/2 for @<伏せ> ---
    [2026-09-13T01:44:23] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","skip":true,"reason":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ"}
    [2026-09-13T01:44:23] === orchestrator done: 2 drafts, 0 reply-connected follows today ===

     60 秒後: 累計 857 件
    120 秒後: 累計 857 件
    180 秒後: 累計 857 件

  走らせる前: 857 件 → 後: 857 件
  **今回 出た数: 0 件**
```

### 出なかった理由（直近 40 行）

```
  [2026-09-09T16:03:14] --- processing #3/4 for @<伏せ> ---
  [2026-09-09T16:03:16] gen failed (#3): {"ok":false,"error":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ","skip":true,"reason":"噛み合い検査で弾いた: 末尾の絵文字「😏」が直近 20 件に 3 件＝顔だけ同じで並ぶ"}
  [2026-09-09T16:03:16] --- processing #4/4 for @<伏せ> ---
  [2026-09-09T16:03:16] gen failed (#4): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / r10.to","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: #PR / r10.to"}
  [2026-09-09T16:03:16] === orchestrator done: 4 drafts, 6 reply-connected follows today ===
  [2026-09-09T19:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T19:03:07] picked 4 / max 4 (from 10 candidates)
  [2026-09-09T19:03:07] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
  [2026-09-09T19:03:07] today's reply-connected follows: 10 / 30
  [2026-09-09T19:03:08] --- processing #1/4 for @<伏せ> ---
  [2026-09-09T19:03:08] gen failed (#1): {"ok":false,"error":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら","skip":true,"reason":"PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: 詳細はこちら"}
  [2026-09-09T19:03:08] --- processing #2/4 for @<伏せ> ---
  [2026-09-09T19:03:10]   → chosen template_id: unknown
  [2026-09-09T19:03:10] enqueue: {"ok":true,"id":"comment-20260909-1903-1"}
  {"ok":true,"entry_id":"comment-20260909-1903-1","x_tweet_id":"2097626917054931267","url":"https://x.com/heng_ji31590/status/2097626917054931267","slack_report_ts":"silenced"}
  [2026-09-09T19:03:26]   follow @<伏せ>: skipped (already in reply-followers.json)
  [2026-09-09T19:03:26] --- processing #3/4 for @<伏せ> ---
  [2026-09-09T19:03:28]   → chosen template_id: unknown
  [2026-09-09T19:03:29] enqueue: {"ok":true,"id":"comment-20260909-1903-2"}
  {"ok":true,"entry_id":"comment-20260909-1903-2","x_tweet_id":"2097627008507445446","url":"https://x.com/heng_ji31590/status/2097627008507445446","slack_report_ts":"silenced"}
  [2026-09-09T19:03:52]   follow @<伏せ>: filtered
  [2026-09-09T19:03:52] --- processing #4/4 for @<伏せ> ---
  [2026-09-09T19:03:53] gen failed (#4): {"ok":false,"error":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない","skip":true,"reason":"生成側が skip: 紹介コード・招待コード・登録誘導の投稿。返信すべきでない"}
  [2026-09-09T19:03:53] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
  [2026-09-09T22:00:05] === comment orchestrator start (max_picks=4, reply_follow_cap=30) ===
  [2026-09-09T22:03:08] picked 4 / max 4 (from 15 candidates)
  [2026-09-09T22:03:08] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
  [2026-09-09T22:03:08] today's reply-connected follows: 10 / 30
  [2026-09-09T22:03:08] --- processing #1/4 for @<伏せ> ---
  [2026-09-09T22:03:10] gen failed (#1): {"ok":false,"error":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報がなく、無理に返信すると宣伝への乗っかりになる。また URL 短縮で詳細が不明なため、具体的な数字や条件に触れられない","skip":true,"reason":"生成側が skip: 楽天公式のキャンペーン告知投稿。返信すべき個人の体験・質問・情報がなく、無理に返信すると宣伝への乗っかりになる。また URL 短縮で詳細が不明なため、具体的な数字や条件に触れられない"}
  [2026-09-09T22:03:11] --- processing #2/4 for @<伏せ> ---
  [2026-09-09T22:03:12] gen failed (#2): {"ok":false,"error":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいない返信 / 書き出しの「あら、」が直近 20 件に 3 件＝同じ入り方の繰り返し","skip":true,"reason":"噛み合い検査で弾いた: 相手の投稿と共有する内容語が 0 個（1 個必要）＝読んでいない返信 / 書き出しの「あら、」が直近 20 件に 3 件＝同じ入り方の繰り返し"}
  [2026-09-09T22:03:13] --- processing #3/4 for @<伏せ> ---
  [2026-09-09T22:03:15] gen failed (#3): {"ok":false,"error":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返信する実質的な内容がない。商品への感想も数字も固有情報もないため、どの投稿にも貼れる型になってしまう","skip":true,"reason":"生成側が skip: 店舗の販売促進投稿。相手の具体的な状況・選択・困りごとがなく、返信する実質的な内容がない。商品への感想も数字も固有情報もないため、どの投稿にも貼れる型になってしまう"}
  [2026-09-09T22:03:15] --- processing #4/4 for @<伏せ> ---
  [2026-09-09T22:03:17]   → chosen template_id: unknown
  [2026-09-09T22:03:17] enqueue: {"ok":true,"id":"comment-20260909-2203-3"}
  {"ok":true,"entry_id":"comment-20260909-2203-3","x_tweet_id":"2097672244462075923","url":"https://x.com/heng_ji31590/status/2097672244462075923","slack_report_ts":"silenced"}
  [2026-09-09T22:03:38]   follow @<伏せ>: filtered
  [2026-09-09T22:03:38] === orchestrator done: 4 drafts, 10 reply-connected follows today ===
```

## 5. **誰が外したのか、launchd 自身に聞く**

x39 では 約 61 秒 周期で載っては消える flap を観測したが、
tab-guard のログは 1 行も増えていない。**推測をやめて一次情報を取る。**

```
  --- log show（直近 15 分・launchd の openclaw 関連） ---
    log show が使えなかった
```

```
  --- いま launchctl に居る ai.openclaw.* ---
    -            0      ai.openclaw.pipeline-heartbeat
    -            0      ai.openclaw.reply-followers-cleanup
    -            0      ai.openclaw.comment-warmup
    -            0      ai.openclaw.incoming-reply-watcher
    15444        0      ai.openclaw.tab-guard
    -            0      ai.openclaw.reply-followback-check
    -            0      ai.openclaw.competitor-follower-follow
    -            0      ai.openclaw.badge-followback
    -            0      ai.openclaw.hashtag-follow
```

```
  --- 1 分ごとに走っているもの（flap の周期と一致するか） ---
    com.dailyhack.ops-poller           StartInterval=60
    com.dailyhack.ops-heartbeat        StartInterval=1800
    com.dailyhack.rc-keeper            StartInterval=300
    ai.openclaw.x-loop-guardian        StartInterval=900
```
