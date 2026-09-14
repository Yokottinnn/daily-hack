# 承認待ちのまま TTL を超えたものを失効させる

**このレポートが作られた時刻: 2026-09-15 00:48:06 JST**

> x75 の実測: 承認待ちのまま **23 件**（最古 54 日前）。
> 残っている理由は `poll-approvals` が停止中で失効処理が走っていないため。
> **`queue-manager` の TTL ガードが投稿対象から除外しているので、投稿の危険は無い。**

**触るのは 7 日 を超えたものだけ。投稿しない。削除しない。印を付けるだけ。**

## 0. 対象（**7 日 を超えたものだけ**）

```
  承認待ち: 23 件
  → **失効させる（7 日 超え）: 19 件**
  → 触らない（TTL 内）        : 4 件

  === 失効させるもの ===
    2026-07-20T23:01  55 日前  grok-comment-20260720-2301-0
    2026-07-20T23:01  55 日前  grok-comment-20260720-2301-1
    2026-07-20T23:01  55 日前  grok-comment-20260720-2301-2
    2026-07-25T07:52  51 日前  grok-comment-20260725-0752-0
    2026-07-25T07:52  51 日前  grok-comment-20260725-0752-1
    2026-07-26T11:54  50 日前  grok-comment-20260726-1154-0
    2026-07-26T11:54  50 日前  grok-comment-20260726-1154-1
    2026-07-26T11:54  50 日前  grok-comment-20260726-1154-2
    2026-08-01T23:02  43 日前  grok-comment-20260801-2302-0
    2026-08-01T23:02  43 日前  grok-comment-20260801-2302-1
    2026-08-01T23:02  43 日前  grok-comment-20260801-2302-2
    2026-08-01T23:02  43 日前  grok-post-20260801-2302
    2026-08-02T23:02  42 日前  grok-comment-20260802-2302-0
    2026-08-02T23:02  42 日前  grok-comment-20260802-2302-1
    2026-08-06T23:02  38 日前  grok-comment-20260806-2302-0
    2026-08-06T23:02  38 日前  grok-comment-20260806-2302-1
    2026-09-07T15:00   7 日前  qt-past-20260908-0000
    2026-09-07T15:02   7 日前  grok-comment-20260907-1502-0
    2026-09-07T15:02   7 日前  grok-comment-20260907-1502-1

  === 触らないもの（まだ出る余地を残す） ===
    2026-09-08T00:33   6 日前  trend-20260908-1
    2026-09-08T00:34   6 日前  trend-20260908-2
    2026-09-09T00:33   5 日前  trend-20260909-1
    2026-09-09T00:34   5 日前  trend-20260909-2
```

## 1. 退避（**先に戻せる状態にする**）

```
  post_queue.json.bak-20260915-004806（919990 bytes）
```

## 2. 印を付ける（`queue-manager.js mark-skipped`）

**JSON を直接 書き換えない。** 既存の口を使う。
理由は `expired_ttl_7d_cleanup`（**後から grep で追える**）。

```
  ✅ grok-comment-20260720-2301-0  {"ok":true}
  ✅ grok-comment-20260720-2301-1  {"ok":true}
  ✅ grok-comment-20260720-2301-2  {"ok":true}
  ✅ grok-comment-20260725-0752-0  {"ok":true}
  ✅ grok-comment-20260725-0752-1  {"ok":true}
  ✅ grok-comment-20260726-1154-0  {"ok":true}
  ✅ grok-comment-20260726-1154-1  {"ok":true}
  ✅ grok-comment-20260726-1154-2  {"ok":true}
  ✅ grok-comment-20260801-2302-0  {"ok":true}
  ✅ grok-comment-20260801-2302-1  {"ok":true}
  ✅ grok-comment-20260801-2302-2  {"ok":true}
  ✅ grok-post-20260801-2302  {"ok":true}
  ✅ grok-comment-20260802-2302-0  {"ok":true}
  ✅ grok-comment-20260802-2302-1  {"ok":true}
  ✅ grok-comment-20260806-2302-0  {"ok":true}
  ✅ grok-comment-20260806-2302-1  {"ok":true}
  ✅ qt-past-20260908-0000  {"ok":true}
  ✅ grok-comment-20260907-1502-0  {"ok":true}

  打った: 18 件 / 成功 18 件 / 失敗 0 件
```

## 3. 結果（**`rc=0` ではなく状態で確かめる**・ルール 13）

```
  キュー全体          : 1111 件
  承認待ちのまま残った: **5 件**
    2026-09-07T15:02  grok-comment-20260907-1502-1  status=awaiting_approval
    2026-09-08T00:33  trend-20260908-1  status=awaiting_approval
    2026-09-08T00:34  trend-20260908-2  status=awaiting_approval
    2026-09-09T00:33  trend-20260909-1  status=awaiting_approval
    2026-09-09T00:34  trend-20260909-2  status=awaiting_approval

  今回の印が付いた    : **18 件**
    grok-comment-20260720-2301-0  status=skipped_expired_ttl_7d_cleanup
    grok-comment-20260720-2301-1  status=skipped_expired_ttl_7d_cleanup
    grok-comment-20260720-2301-2  status=skipped_expired_ttl_7d_cleanup
    grok-comment-20260725-0752-0  status=skipped_expired_ttl_7d_cleanup
    grok-comment-20260725-0752-1  status=skipped_expired_ttl_7d_cleanup
```

**残った件数が「触らないもの」と一致していれば成功。**
一致していなければ、`mark-skipped` の印の付き方が想定と違う。
その場合は **post_queue.json.bak-20260915-004806 から戻せる。**

## 4. 費用

**印を付けるだけ。投稿しない。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44
（`MAX_PICKS` は 4 のまま・2026-09-13 に利用者が判断）。
