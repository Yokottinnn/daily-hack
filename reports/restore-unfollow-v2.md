# アンフォローと計測を戻した（2026-09-05 19:09:05 JST・費用 $0）

> `t043` は plist を読む部分（**報告用**）で落ち、その下の bootstrap まで届かなかった。
> **報告を先に書き、実行を後ろに置いていた設計ミス。** 今回は実行を先に置いた。
> **アンフォローは kickstart していない**（一斉に外れるとそれ自体がスパム的）。

## 1. ロード結果（**実行済み**）

```
reply-followback-check                   **ロードした**
follow-watchdog                          bootstrap に失敗
unfollow-daily                           bootstrap に失敗
unfollow-evening                         bootstrap に失敗
unfollow-cleanup-morning                 bootstrap に失敗
unfollow-cleanup-evening                 bootstrap に失敗
auto-detect-and-unfollow-inactive        **ロードした**
revenge-unfollow                         bootstrap に失敗
```

- `reply-followback-check`: **kickstart した**

## 2. いまのロード状態と最後の終了コード

```
ラベル                                PID      rc
reply-followback-check                   65318    0
follow-watchdog                          **未ロード**
unfollow-daily                           **未ロード**
unfollow-evening                         **未ロード**
unfollow-cleanup-morning                 **未ロード**
unfollow-cleanup-evening                 **未ロード**
auto-detect-and-unfollow-inactive        -        0
revenge-unfollow                         **未ロード**
competitor-follower-follow               63566    0
hashtag-follow                           -        0
badge-followback                         -        0
```

## 3. 実行間隔（次にいつ回るか）

```
reply-followback-check                   [{"Hour":1,"Minute":15},{"Hour":13,"Minute":15}]
follow-watchdog                          （不明）
unfollow-daily                           （不明）
unfollow-evening                         （不明）
unfollow-cleanup-morning                 （不明）
unfollow-cleanup-evening                 （不明）
auto-detect-and-unfollow-inactive        [{"Hour":22,"Minute":30}]
revenge-unfollow                         （不明）
```

## 4. アンフォローの上限（次の定時で何が起きるか）

```
```

## 5. 当日の実績

```
reply-followers.json: 今日 8 件 / 更新 09-05 18:54
followed.json: 今日 0 件 / 更新 08-30 00:50
unfollow-cleanup-state.json: 今日 0 件 / 更新 08-10 09:31
badge-followback-state.json: 今日 0 件 / 更新 08-30 00:50
```

## 6. フォロー操作そのものの失敗（`t042` で新たに出た）

`follow button click didn't change to unfollow` はフィルタではなく**操作の失敗**。
X のレート制限か UI 変化の可能性がある。**件数を増やすほど効いてくる。**

```
  37 ❌ follower count out of range
  16 ❌ random-looking handle
  15 ❌ low-density bio
  14 ❌ follower>>following exclusion
  13 ❌ inactive
   3 ❌ Phase 2
   2 ❌ off-niche bio
   2 ❌ follow button click didn't change to unfollow
   1 ❌ refollow blacklist
   1 ❌ Phase 1
```

---

**アンフォローは 1 件も実行していない**（ロードしただけ。次の定時から回る）。
**投稿していない。LLM も呼んでいない（$0）。**
