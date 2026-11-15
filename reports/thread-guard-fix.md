# 番人の鳴りすぎと、捨てられていた stdout を直す（2026-09-27 17:11 JST・$0）

**このレポートが作られた時刻: 2026-09-27 17:11:04 JST**

> **投稿しない。キューも放置行も触らない。** LLM を呼ばない（$0／回・$0／日・$0／月）。

## 1. 12:00 の失敗ログを、切らずに出す

**`x165` は 300 字、`x170` は 400 字 で切っていた。** 全部 出す。

```
  {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWV
  huW6l+OBv+OBn+OBhOOBquODjeODg+ODiOOCt+ODp+ODg+ODl+OBjOOAgeOBnOOCk+OBtuOBk+OBruOCouODl+ODquOBi+OCieiyt+OBiOOCi+OBruOAgjIsMDAw5LiH44Ki44Kr44Km44Oz44OI56qB56C044CBQXBwIFN0b3Jl44Gu6KmV
  5L6hNC42NeOAggoK6aOf5ZOB44O76Kq/5ZGz5paZ44O744OV44Or44O844OE44O744GK6I+T5a2Q44CC44GK57Gz44KE6YeO6I+c44KS55Sf55Sj6ICF44GL44KJ55u05o6l44Gj44Gm44GE44GG5p6g44KC44GC44KL44KP44CC\" \"htt
  ps://x.com/heng_ji31590/status/2104043402358886416\" \"null\"\n[step] connect t=0ms\n[step] navigate-target t=103ms\n[step] find-reply-textarea t=6236ms\n[textarea] found via prima
  ry sel: div[data-testid^=\"tweetTextarea_\"][contenteditable=\"true\"] t=6280ms\n[step] type-text t=6280ms\n[x154] like 付いた\n","thread_results":[{"index":0,"role":"hook","ok":true,"tw
  eet_id":"2104043402358886416","url":"https://x.com/heng_ji31590/status/2104043402358886416","image_attached":true,"captured_via":"graphql_response"}]}

  --- その前 20 行（どこまで進んだか）---
  1-[run-publish] thread_chain mode
  2-[post-via-playwright] attached 4/4 image(s)
  3-[step] connect t=0ms
  4-[step] navigate-target t=103ms
  5-[step] find-reply-textarea t=6236ms
  6-[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6280ms
  7-[step] type-text t=6280ms
  8-[x154] like 付いた
  9:{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OB
```

**`child_stdout` が無いのが今の姿。** §4 で足す。

## 2. 番人を直したものに差し替える

```
  書いたもの: 9095 bytes / 202 行
  node --check rc=0（打つ名前: .thread-guard-fix-20260927-171104.js）
```
```
  差し替えた: thread-guard.js（202 行）
  上限が入ったか: STALE_MIN 3 箇所 / MAX_ALERTS 3 箇所
```

## 3. 汚れた状態ファイルを捨てる

**`x170` の DRY が 14 件を「既報」にした。** 消さないと本番が黙り続ける。

```
  在った: 1043 bytes / キー 15 件
  → 退避した（消さずにリネーム）
```

## 4. `run-publish.sh` の 2 箇所を直す

```json
  直す前: 210 行 / e.message が 2 箇所 / child_stdout が 0 箇所
  {
    "ok": true,
    "changed": true,
    "report": [
      {
        "from": "{ ok: false, step: 'thread-reply-' + i + '-exec', error:",
        "found": 1,
        "note": "直した"
      },
      {
        "from": "{ ok: false, step: 'thread-main-exec', error: e.message,",
        "found": 1,
        "note": "直した"
      }
    ]
  }

  直した後: 210 行 / child_stdout が 2 箇所

  --- シェルとして壊れていないか ---
    bash -n OK
```

## 5. 直した番人を 1 回 走らせる（**DRY → 本番**）

**DRY は状態ファイルに触らない。** 触っていないことも確かめる。

```
  --- DRY ---
    [thread-guard] A（ログの ok:false / thread 系）: 1 件
    [thread-guard] B（出る時刻を過ぎても posted でない）: 1 件
    [thread-guard] 放置（2880 分 超。鳴らさない）: 13 件
    [thread-guard]   放置: blog-promo-20260515-qr-payment-comparison-2026 110 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-cheap-sim-comparison-2026 109 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-fixed-cost-reduction-guide-202 108 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-jre-bank-campaign-2026 107 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-june-2026-campaigns-roundup 106 日 遅れ
    [thread-guard]   B 通知: blog-promo-20260927-payid-a 311 分 遅れ
    [thread-guard] DRY なので Slack へ出さない: 🚨 *予約投稿が出ていない*
    • id: `blog-promo-20260927-payid-a`
    • status: `awaiting_approval`（`posted` になっていない）
    • 出るはずだった時刻: 2026-09
    [thread-guard]   A 通知: thread-reply-1-exec
    [thread-guard] DRY なので Slack へ出さない: 🚨 *スレッドの投稿が途中で落ちた*
    • ログ: `publish-payid-oneshot.log`
    • step: `thread-reply-1-exec`
    • error: ```Command failed: /usr/loc
    [thread-guard] DRY なので状態ファイルは書かない
    {"ok":true,"at":"2026-09-27 17:11:05","dry":true,"a_count":1,"b_count":1,"stale_count":13,"notified":["B:blog-promo-20260927-payid-a","A:thread-reply-1-exec"]}

  DRY の後に状態ファイルが在るか: 無い（正しい）

  --- 本番（実際に Slack へ出す。上限 3 件）---
    [thread-guard] A（ログの ok:false / thread 系）: 1 件
    [thread-guard] B（出る時刻を過ぎても posted でない）: 1 件
    [thread-guard] 放置（2880 分 超。鳴らさない）: 13 件
    [thread-guard]   放置: blog-promo-20260515-qr-payment-comparison-2026 110 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-cheap-sim-comparison-2026 109 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-fixed-cost-reduction-guide-202 108 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-jre-bank-campaign-2026 107 日 遅れ
    [thread-guard]   放置: blog-promo-20260516-june-2026-campaigns-roundup 106 日 遅れ
    [thread-guard]   B 通知: blog-promo-20260927-payid-a 311 分 遅れ
    [thread-guard] Slack: 出た
    [thread-guard]   A 通知: thread-reply-1-exec
    [thread-guard] Slack: 出た
    {"ok":true,"at":"2026-09-27 17:11:05","dry":false,"a_count":1,"b_count":1,"stale_count":13,"notified":["B:blog-promo-20260927-payid-a","A:thread-reply-1-exec"]}
```

## 6. ジョブがまだ載っているか

```
    	state = not running
    	runs = 0
    	last exit code = (never exited)
    → **載っている**
```

---

## 読み方

| §5 の出方 | 意味 |
| --- | --- |
| `b_count` が 1〜3 ／ `stale_count` が 13 前後 | **狙いどおり。** 放置は数えるだけ |
| DRY の後に状態ファイルが在る | **直っていない。** もう一度 直す |
| 本番で `notified` に 1 件 以上 | **Slack に出た。** 実物を見て文面を確かめる |

| §4 の `child_stdout` | 意味 |
| --- | --- |
| 2 箇所 | **直った。** 次に同じ形で落ちたら真因がログに出る |
| 0 箇所 ／ `見つからない` | **当たらなかった。** §1 の実物を見てアンカーを作り直す |

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
