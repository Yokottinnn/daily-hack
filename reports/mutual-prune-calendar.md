# `mutual-prune` を `StartCalendarInterval` に移す

**このレポートが作られた時刻: 2026-09-15 01:21:22 JST**

> x79 の実測: **20 時間 走っていなかった**（12 時間 間隔のはずが 1 回だけ）。
> `StartInterval` は **Mac が寝ている間の発火を落とす。**
>
> 他の 8 本は `x48` で切り替え済み。**`mutual-prune` は後から設置したので通っていない。**

**発火回数は変えない（12 時間 → 1 日 2 回）。上限も判定条件も触らない。**

## 0. 変える前

```
  載っている: **はい**
    PID=61819  最後の終了コード=-15
  plist: 2026-09-13 10:48
    StartInterval        : 43200
    StartCalendarInterval: 0
0 個
  ログの最終更新: 2026-09-14 05:10
```

## 1. 変える（**6 時 / 18 時 の 2 回**）

```
  退避: ai.openclaw.mutual-prune.plist.bak-20260915-012122
  変換: CONVERTED 43200s -> 2 times/day at 6,18 時
  plutil -lint: OK
  bootstrap rc=0（**rc は載った証拠にならない。下で確かめる**）
```

## 2. 結果（**`launchctl list` で確かめる**・ルール 13）

```
  ai.openclaw.mutual-prune: **載っている**
    PID=-  最後の終了コード=0

  --- 変えた後の plist ---
    StartInterval        : (無し。これでよい)
    StartCalendarInterval: 6,18 時
    RunAtLoad            : false

  --- 環境変数が残っているか（**消えていたら困る**） ---
    MAX_UNFOLLOW     8
    INACTIVE_DAYS    30
    RATIO            0.20
    ABS_MIN          300
    GRACE_DAYS       14
    CDP_URL          http://127.0.0.1:18810
    OPS_WS           /Users/ny/.openclaw/workspace
```

**環境変数が 1 つでも消えていたら、退避から戻す。**
上限や判定条件が既定値に戻ると、外す件数が変わってしまう。

## 3. 次に走る時刻

```
  6 時 と 18 時（JST）に発火する。**寝ていたら、起きたときに 1 回。**
  いま: 2026-09-15 01:21

  番人（daily-supervisor）は 05:00 / 17:00 に走り、
  **「今日 1 回も走っていない」ものを kickstart する。**
  mutual-prune は既にその監視対象（x47 の JOBS_CDP）。**追加は不要。**
```

## 4. 費用

**plist を書き換えて載せ直すだけ。LLM を呼ばない。いま外さない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**`mutual-prune` 自体も $0**（DOM 操作のみ）。**発火回数は変えない**ので、
外す件数の上限も 1 回 8 件・1 日 16 件 のまま（実績は 2026-09-13 に 6 件）。
返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44。
