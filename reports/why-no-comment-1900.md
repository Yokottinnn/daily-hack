# 19:00 でコメントが 0 件 だった理由（2026-09-27 21:47 JST・$0）

**このレポートが作られた時刻: 2026-09-27 21:47:32 JST**

> **読むだけ。** 撃っていない。トークンも触っていない。

## 1. 19:00 と 22:00 の発火はあったか

**`runs` は載せ直しで 0 に戻るので、これ単体では足りない。** ログと併せて見る。

```
    	path = /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist
    	state = not running
    	runs = 2
    	last exit code = 0
    		state = active
    		state = active
```

```
  ===== comment-orchestrator.log（更新 09-27 19:03:11）=====
    --- 今日の start / picked / candidates ---
      [2026-09-27T16:00:55] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
      [2026-09-27T16:03:56] picked 2 / max 2 (from 26 candidates)
      [2026-09-27T16:04:32]   follow @<伏せ>: skipped (already in reply-followers.json)
      [2026-09-27T17:19:27] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T17:22:28] picked 3 / max 6 (from 4 candidates)
      [2026-09-27T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T19:03:06] picked 2 / max 6 (from 6 candidates)
      [2026-09-27T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が求めているのは『即返信できるDM相手』という人間関係の話。ハッカー子が返すべ�
      [2026-09-27T19:03:11] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。触れるべき固有名詞・数字・状況がない�

    --- 18:30 以降の全部（ここに答えが在る）---
      [2026-09-27T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T19:03:06] picked 2 / max 6 (from 6 candidates)
      [2026-09-27T19:03:06] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
      [2026-09-27T19:03:06] today's reply-connected follows: 11 / 30
      [2026-09-27T19:03:06] --- processing #1/2 for @<伏せ> ---
      [2026-09-27T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が求めているのは『即返信できるDM相手』という人間関係の話。ハッカー子が返すべ�
      [2026-09-27T19:03:09] --- processing #2/2 for @<伏せ> ---
      [2026-09-27T19:03:11] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。触れるべき固有名詞・数字・状況がない�
      [2026-09-27T19:03:11] === orchestrator done: 2 drafts, 11 reply-connected follows today ===

  ===== comment-warmup.log（更新 09-27 19:03:11）=====
    --- 今日の start / picked / candidates ---
      [2026-09-27T17:19:27] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T17:22:28] picked 3 / max 6 (from 4 candidates)
      [2026-09-27T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T19:03:06] picked 2 / max 6 (from 6 candidates)
      [2026-09-27T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が求めているのは『即返信できるDM相手』という人間関係の話。ハッカー子が返すべ�
      [2026-09-27T19:03:11] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。触れるべき固有名詞・数字・状況がない�

    --- 18:30 以降の全部（ここに答えが在る）---
      [2026-09-27T19:00:05] === comment orchestrator start (max_picks=6, reply_follow_cap=30) ===
      [2026-09-27T19:03:06] picked 2 / max 6 (from 6 candidates)
      [2026-09-27T19:03:06] recent template ids (newest first): unknown,unknown,unknown,unknown,unknown
      [2026-09-27T19:03:06] today's reply-connected follows: 11 / 30
      [2026-09-27T19:03:06] --- processing #1/2 for @<伏せ> ---
      [2026-09-27T19:03:08] gen failed (#1): {"ok":false,"error":"生成側が skip: 相手が求めているのは『即返信できるDM相手』という人間関係の話。ハッカー子が返すべ�
      [2026-09-27T19:03:09] --- processing #2/2 for @<伏せ> ---
      [2026-09-27T19:03:11] gen failed (#2): {"ok":false,"error":"生成側が skip: 投稿に具体的な内容がなく、ハッシュタグのみ。触れるべき固有名詞・数字・状況がない�
      [2026-09-27T19:03:11] === orchestrator done: 2 drafts, 11 reply-connected follows today ===

```

**`start` が無ければ①、`from 0 candidates` なら②、`picked` の後で落ちていれば③。**

## 2. 候補が枯れているのか（**②の裏取り**）

候補の条件は `MIN_LIKES=2` / `MAX_AGE_HOURS=18`。
**すでに返信した相手は外れる**ので、同じ日に何度も撃つと枯れる。

```

  --- 今日 弾いた数（入口・出口）---
  comment-orchestrator.log     ng 136 / tone 239 / relevance 0 / 既に返信 204
  comment-warmup.log           ng 5 / tone 3 / relevance 0 / 既に返信 202
```

## 3. トークンは何で測っていて、誰が更新するのか

**`auth.ok` の出どころを特定する。** 分からないままでは直せない。

```
  **ops-heartbeat.sh が見つからない**
    pipeline-heartbeat.js
    pipeline-heartbeat.js.bak.20260726-selfheal
    pipeline-heartbeat.js.bak18800
```

```
  --- トークンの実体が入っているファイル（**中身は出さない**）---

  --- data/ の中で expires を持つ JSON（**キー名だけ**）---

  --- 更新しているらしいスクリプト ---
    （無い）
```

## 4. 失効しても投稿できているのか（**切り分け**）

**`auth` は API 用のトークンで、コメントは Playwright の DOM 操作。**
**別物なら、失効しても投稿はできる。** そこを混同しない。

```
  comment-orchestrator が API トークンを使っているか:
    comment-orchestrator.sh      TOKEN 1 箇所 / Bearer 0 箇所 / playwright 0 箇所
    post-comment.js              TOKEN 0 箇所 / Bearer 0 箇所 / playwright 2 箇所
    asuka-fill.js                TOKEN 0 箇所 / Bearer 0 箇所 / playwright 0 箇所

  --- 17:23 より後に投稿ログが伸びているか ---
    comment-orchestrator.log     更新 09-27 19:03:11
    comment-warmup.log           更新 09-27 19:03:11
```

## 5. キューの実物（**一次情報**）

```json
  今日（JST）の comment エントリ: 5 件

  16:04:12  status=posted  tweet_id=2104104794084544828
  16:04:32  status=posted  tweet_id=2104104877668680175
  17:22:43  status=posted  tweet_id=2104124554331468031
  17:23:01  status=posted  tweet_id=2104124631607378382
  17:23:19  status=posted  tweet_id=2104124707306148018

  → **19:00 以降の行が在るか**が答え。無ければ発火しても積まれていない
```

---

## 読み方

| §1 の出方 | 原因 | 次 |
| --- | --- | --- |
| 19:00 の `start` が**無い** | ① 発火していない | plist の `StartCalendarInterval` と  を見る |
| `from 0 candidates` | ② 候補切れ | **故障ではない。** `MAX_AGE_HOURS` を伸ばすか、対象を広げる |
| `picked N` の後で落ちている | ③ 投稿で落ちた | §4 でトークンと Playwright を切り分ける |

| §3・§4 の出方 | 意味 |
| --- | --- |
| コメント側に `TOKEN` / `Bearer` が 0 箇所 | **失効はコメントに関係ない。** 別の原因 |
| `TOKEN` を使っている | **失効が直接の原因。** 更新の口を探す（§3） |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
