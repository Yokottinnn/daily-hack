# pipeline-heartbeat の「いま」（2026-09-21 14:10 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 14:10:52 JST**

> **`exit 2` は落ちているのではない。** `overall=CRIT` のとき 2 を返す設計
> （2026-09-20 の x90 で確定済み）。**だがその数字は「いま」ではない。**
>
> **返信の量を増やすかの判断材料は `cost_24h_usd` の実額 1 つ。**
> 推定（1 件 $0.003 × picks）ではなく、Mac 側の自己計測を取りに行く。

## 1. ログはどれか。**いつのものか**

```
  /Users/ny/.openclaw/workspace/logs/pipeline-heartbeat.log
  mtime : 2026-09-21 08:00:51
  いま  : 2026-09-21 14:10:52
  行数  : 213
```

**mtime が数時間 古ければ、そこで止まっている。** その場合 $0.021 も「いま」ではない。

## 2. 最後の判定（**CRIT / WARN / INFO を全部**）

```
  overall = CRIT
     OK   login                      logged_in
     OK   chrome_cdp                 alive
     OK   comment_posts_24h          17 (target ≥5)
  ** WARN trend_posts_24h            0 (target ≥1)
  ** INFO thread_posts_24h           1
     OK   comment_warmup_fire        fire in 24h
  ** CRIT grok_trending_fire         no fire >24h  （自動復旧できる）
     OK   hashtag_follow_fire        fire in 24h
     OK   badge_followback_fire      fire in 24h
  ** WARN unfollow_cleanup_morning_fire no fire >24h  （自動復旧できる）
  ** INFO cost_24h_usd               $0.081

  ===> cost_24h_usd = $0.081
```

## 3. コストの実額（**ここが目的**）

**推定ではなく Mac 側の自己計測。** 過去の値と並べて、動いているかを見る。

```
  --- ログに出た cost_24h_usd を新しい順に 8 件 ---
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"
    cost_24h_usd"

  --- 判定 JSON が何本あるか（＝何回 走ったか）---
    62 本
```

**参考（`docs/recurring-job-costs.md` の実測）**

| | 金額 |
| --- | --- |
| 2026-09-20 の `cost_24h_usd` | **$0.021/日**（≒ $0.63/月） |
| 生成 1 件（2026-09-06 実測） | **$0.003** |
| 上限（**安全弁であって実績ではない**） | $0.048/日・$1.44/月 |

## 4. `exit 2` はどこで打たれているか（裏取り）

```
  ===== pipeline-heartbeat.js =====

```

**`overall==="CRIT"` のときだけ 2 なら、2 は正常な報告。** 直すものではない。

## 5. 読み方

| 出方 | 意味 |
| --- | --- |
| `cost_24h_usd` が出ていて mtime が新しい | **測れている。** この実額で量の増減を判断できる |
| `cost_24h_usd` が出ていない | 集計が壊れている。**先に直す** |
| mtime が古い | ジョブが止まっている。数字は「いま」ではない |
| CRIT が `grok_trending_fire` だけ | **戻していない LLM ジョブが鳴っているだけ**（設計どおり） |
| CRIT が他にもある | そちらを見る |

## 6. 費用

**ログとソースを読むだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
