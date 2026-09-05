# アンフォローの bootstrap 失敗を直す（2026-09-05 19:38:40 JST・費用 $0）

> `t044` で 8 本中 2 本しかロードできなかった。**plist はあるのに失敗していた。**
> **推測で `enable` を打たず、まず生のエラーを取ってから**再挑戦した。
> **kickstart しない。** アンフォローは次の定時から回る。

## 1. 結果

### `follow-watchdog` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

### `unfollow-daily` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

### `unfollow-evening` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

### `unfollow-cleanup-morning` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

### `unfollow-cleanup-evening` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

### `revenge-unfollow` — **なお失敗**

1 回目のエラー:
```
Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```

enable 後:
```
 / Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. 
```


## 2. いまのロード状態

```
ラベル                                PID      rc
follow-watchdog                          **未ロード**
unfollow-daily                           **未ロード**
unfollow-evening                         **未ロード**
unfollow-cleanup-morning                 **未ロード**
unfollow-cleanup-evening                 **未ロード**
revenge-unfollow                         **未ロード**
reply-followback-check                   -        0
auto-detect-and-unfollow-inactive        -        0
competitor-follower-follow               -        0
hashtag-follow                           -        0
badge-followback                         -        0
```

## 3. 無効化の一覧（`launchctl print-disabled`）

**disabled になっているものは bootstrap しても起動しない。**

```
（disabled の一覧を取得できない）
```

## 4. 今日の弾き理由（参考・いま最大の障壁）

```
  37 ❌ follower count out of range
  17 ❌ random-looking handle
  16 ❌ low-density bio
  14 ❌ follower>>following exclusion
  13 ❌ inactive
   3 ❌ Phase 2
   2 ❌ off-niche bio
   2 ❌ follow button click didn't change to unfollow
   1 ❌ refollow blacklist
   1 ❌ Phase 1
```

**`follower count out of range` が最大。** ratio ではない。範囲は現在 100〜50000。

```
  20 0
   4 1
   3 2
   1 9
   1 26000
   2 28000
   1 40000
   4 84000
   1 103000
```

上が**弾かれた相手のフォロワー数**。下限 100 未満と上限 50000 超のどちらで落ちているかが分かる。

---

**アンフォローは 1 件も実行していない。投稿もしていない。LLM も呼んでいない（$0）。**
