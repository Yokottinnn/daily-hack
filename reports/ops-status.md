# 返信とフォローは動いているか（2026-08-30 13:29 JST）

> **上限と実績を混同しない。** 両方出す。
> **ログ名を当て推量しない。** logs/ を全部 grep する。

## 1. 出口の検査はどのログに出ているか（040 の訂正）

040 は comment-warmup.log だけを見て「0 行」と報告した。**探す場所が違った可能性がある。**

### `tone-gate`
- comment-orchestrator.log: **7 行**

### `ng-filter`
- comment-orchestrator.log: **9 行**

orchestrator が stderr を書く先（$LOG の定義）:
```bash
8:LOG=$WS/logs/comment-orchestrator.log
```

tone-gate の直近の行（見つかった全ログから）:
      tone-gate: 通過
      tone-gate: 通過
      tone-gate: 通過
      tone-gate: 送るが記録する (command=なさいよ)
      tone-gate: 通過
      tone-gate: 通過
      tone-gate: 通過

## 2. 返信 — 実績

### comment-warmup
- 最終更新: 08-30 12:04
- 本日（2026-08-30）の発火: 1 回
- 本日 実際に投稿できた件数: 1 件
  （日付の接頭辞が無い行があるため entry_id の YYYYMMDD で数えている）
- 直近の締め行:
      [2026-08-29T12:04:20] === orchestrator done: 2 drafts, 1 reply-connected follows today ===
      [2026-08-29T16:04:29] === orchestrator done: 2 drafts, 1 reply-connected follows today ===
      [2026-08-29T19:04:37] === orchestrator done: 2 drafts, 2 reply-connected follows today ===
      [2026-08-30T12:04:07] === orchestrator done: 2 drafts, 0 reply-connected follows today ===

### comment-orchestrator
- 最終更新: 08-30 12:04
- 本日（2026-08-30）の発火: 1 回
- 本日 実際に投稿できた件数: 0 件
  （日付の接頭辞が無い行があるため entry_id の YYYYMMDD で数えている）
- 直近の締め行:
      [2026-08-29T12:04:20] === orchestrator done: 2 drafts, 1 reply-connected follows today ===
      [2026-08-29T16:04:29] === orchestrator done: 2 drafts, 1 reply-connected follows today ===
      [2026-08-29T19:04:37] === orchestrator done: 2 drafts, 2 reply-connected follows today ===
      [2026-08-30T12:04:07] === orchestrator done: 2 drafts, 0 reply-connected follows today ===

### incoming-reply-watcher
- 最終更新: 08-30 13:19
- 本日（2026-08-30）の発火: 0 回
- 本日 実際に投稿できた件数: 0 件
  （日付の接頭辞が無い行があるため entry_id の YYYYMMDD で数えている）
- 直近の締め行:


## 3. フォロー — 実績（cap ではなく実数）

### ④ 競合フォロー — competitor-follower-follow
- **上限**（COMPETITOR_FOLLOW_DAILY_CAP）: 10  ← 安全弁。予想件数ではない
- 最終更新: 08-30 11:30
- 本日の **成功（✅）**: 0 件
- 本日の **失敗（❌）**: 0 件
- 直近 3 日の締め行:
      [2026-08-28T09:36:40.230Z] === end: 0/10 OK ===
      === end: 0/10 OK ===
      [2026-08-29T02:36:36.823Z] === end: 1/10 OK ===
      === end: 1/10 OK ===
      [2026-08-29T09:36:40.174Z] === end: 0/10 OK ===
      === end: 0/10 OK ===
- 本日 弾いた理由の内訳:

### ④ タグフォロー — hashtag-follow
- **上限**（HASHTAG_FOLLOW_DAILY_CAP）: 90  ← 安全弁。予想件数ではない
- 最終更新: 08-30 10:15
- 本日の **成功（✅）**: 0 件
- 本日の **失敗（❌）**: 0 件
- 直近 3 日の締め行:
      [2026-08-28T08:03:43.538Z] === end: 0/1 OK ===
      === end: 0/1 OK ===
      [2026-08-29T01:18:42.162Z] === end: 0/1 OK ===
      === end: 0/1 OK ===
      [2026-08-29T08:05:00.262Z] === end: 1/3 OK ===
      === end: 1/3 OK ===
- 本日 弾いた理由の内訳:

### ② フォロー返し — badge-followback
- 最終更新: 08-30 00:50
- 本日の **成功（✅）**: 0 件
- 本日の **失敗（❌）**: 0 件
- 直近 3 日の締め行:
      {"ok":true,"scanned":207,"verified":67,"followed_back":1,"handles":["Masa62245981"]}
      {"ok":true,"scanned":209,"verified":67,"followed_back":0,"handles":[]}
      {"ok":true,"scanned":208,"verified":65,"followed_back":1,"handles":["AlinawazTrader"]}
      {"ok":true,"scanned":214,"verified":68,"followed_back":1,"handles":["oku_risu"]}
      {"ok":true,"scanned":214,"verified":68,"followed_back":2,"handles":["NV_ShogoTakino","xuwhky"]}
      {"ok":true,"scanned":215,"verified":67,"followed_back":1,"handles":["oyadani7799"]}
- 本日 弾いた理由の内訳:

### ③ アンフォロー — auto-detect-and-unfollow-inactive
- 最終更新: 08-29 22:30
- 本日の **成功（✅）**: 0 件
- 本日の **失敗（❌）**: 0 件
- 直近 3 日の締め行:
- 本日 弾いた理由の内訳:


## 4. フォロワー推移と目標

    2026-08-09  206
    2026-08-21  207  (+1)
    2026-08-22  206  (-1)
    2026-08-23  208  (+2)
    2026-08-24  210  (+2)
    2026-08-25  212  (+2)
    2026-08-26  211  (-1)
    2026-08-27  214  (+3)
    2026-08-28  214  (+0)
    2026-08-29  215  (+1)

  実測ペース: +0.45 人/日
  必要ペース: +2.66 人/日（残り 32 日）
  このままの 9/30 見込み: 約 229 人

## 5. トークンの期限切れ — 再ログインが要るのか、更新で済むのか

`ops-heartbeat.sh:395` を読むと、auth が見ているのは
**Mac の Claude Code のログイン情報**（`security find-generic-password -s 'Claude Code-credentials'`）。
**X の投稿に使う認証ではない。** だから投稿は動き続けている。

> **ここが今の実装の弱いところ。** `expiresAt` はアクセストークンの期限で、
> リフレッシュトークンがあれば次の利用時に自動更新される。
> いまの判定は「更新すれば済む」と「本当に再ログインが要る」を区別していない。

### 5-1. 認証情報の中身（**キーの有無だけ。値は一切出さない**）

- 取得元: Keychain
  - `accessToken`: **有り**
  - `refreshToken`: **有り**
  - `expiresAt`: **有り**
  - `scopes`: **有り**
  - `subscriptionType`: **有り**
  - 期限: 2026-08-27 20:50:24Z
  - 状態: **過ぎている**（55 時間 経過）
  - → **refreshToken がある。** 次の利用時に自動更新される見込み。**再ログインは不要な可能性が高い**

### 5-2. 実際に Claude Code が動くか（一番確かな証拠）

**期限の数字ではなく、動くかどうかで決める。**
- CLI: 有り（/opt/homebrew/bin/claude）
- `claude --version`: 2.1.231 (Claude Code)

### 5-3. 会話ログに認証エラーが出ているか

- 直近 24 時間の会話ログに認証エラーは**出ていない**

### 5-4. ブリッジ（remote-control）は生きているか

- com.dailyhack.rc-keeper: **ロード済み**
- com.dailyhack.openclaw.listener: **ロード済み**

### 5-5. 判定

    refreshToken が有り + 会話ログに認証エラー無し → **更新で済む。再ログイン不要**
    refreshToken が無い、または認証エラーが出ている → **再ログインが要る**
    認証情報そのものが読めない                     → **判定不能。数字を信じない**

**「期限を過ぎている」だけでは再ログインの根拠にならない。** 上の 3 つで決める。
## 6. まとめの判定

- 返信が動いている＝**本日の x_tweet_id が 1 件以上**
- フォローが動いている＝**本日の ✅ が 1 件以上**
- 出口の検査が動いている＝**tone-gate の行がどこかのログに出ている**

**ログがある＝動いている、ではない。** 上の 3 つの実数で判断すること。
