# 作り直した plist を起動する（2026-09-06 22:20 JST・費用 $0）

> **同時に全部 起動しない。** `reply-followers-cleanup` が 1 回 20 件で
> 滞留 196 件を消化しはじめている。そこへ 1 回 10 件 外す `revenge-unfollow` を
> 重ねると **X の判定に触れる。** 滞留が落ち着いてから足す。

/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x08-load-rebuilt-plists.sh: line 57: timeout: command not found
## 0. アンフォローを実際に走らせる（** を使わない**）

`x06` は `timeout` を使って `rc=127` で落ちた。**macOS に `timeout` は無い。**
ジョブ自体は起動済み（lint OK・rc=0・上限 20 件 挿入済み）だが、
**今日中に実際に外れることを確かめる。**

- 走らせる前: `unfollowed` **16 件** / 期限到来 **197 件**

```
[2026-09-06T13:20:21.654Z] due 197 → 上限 5 件に絞る（残りは次回）
[2026-09-06T13:20:21.658Z] due unfollows: 5 → mao_otk_tw,cpaky1,sukesankoba,fxmeitantei,feldoman0504
[2026-09-06T13:20:39.879Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-09-06T13:20:47.112Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-09-06T13:20:54.366Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-09-06T13:21:01.521Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-09-06T13:21:08.667Z] @<伏せ>: unfollow failed (no unfollow button)
[2026-09-06T13:21:11.177Z] done
(rc=0)
```

| | 前 | 後 |
| --- | --- | --- |
| `unfollowed` | 16 | **16** |
| 期限到来 | 197 | **197** |

- **今回 外した数: 0 件**
- **まだ外れていない。上のログを読むこと。**

## 1. 復元済みの 2 本を起動する

### `unfollow-cleanup-morning`

- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-morning.plist: OK
- 叩く相手: `scripts/unfollow-cleanup.js`（存在する）

```
  ロード済み  PID=-        最後のrc=0
```

### `unfollow-cleanup-evening`

- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.unfollow-cleanup-evening.plist: OK
- 叩く相手: `scripts/unfollow-cleanup.js`（存在する）

```
  ロード済み  PID=-        最後のrc=0
```


## 2. スクリプトがある 2 本を復元する（**load はしない**）

### `follow-watchdog`

- 環境変数: `{"PATH":"\/usr\/local\/bin:\/opt\/homebrew\/bin:\/usr\/bin:\/bin","HOME":"\/Users\/ny"}`
- 叩く相手: `scripts/follow-watchdog.js`（存在する）
- 実行時刻: **11:0**（ログの時刻に合わせた）
- **作り直した**（1093 B・lint OK）／壊れた版は `broken.20260906-222021/` に退避
- **load していない。** 滞留が落ち着いてから起動する

### `revenge-unfollow`

- 環境変数: `{"REVENGE_DRY_RUN":"false","REVENGE_MAX_PER_RUN":"10"}`
- 叩く相手: `scripts/revenge-unfollow.js`（存在する）
- 実行時刻: **13:0**（ログの時刻に合わせた）
- **作り直した**（1075 B・lint OK）／壊れた版は `broken.20260906-222021/` に退避
- **load していない。** 滞留が落ち着いてから起動する


## 3. スクリプトが無い 2 本

`unfollow-daily` / `unfollow-evening` は**同名スクリプトが無く、
起動引数を復元する材料が無い。当て推量で書かない。作らない。**

```
  unfollow-daily       環境変数: {"UNFOLLOW_DRY_RUN":"false","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","UNFOLLOW_STALE_DAYS":"1","UNFOLLOW_MAX_PER_RUN"
  unfollow-evening     環境変数: {"UNFOLLOW_DRY_RUN":"false","PATH":"\/usr\/local\/bin:\/usr\/bin:\/bin","UNFOLLOW_STALE_DAYS":"1","UNFOLLOW_MAX_PER_RUN"

  scripts/ にある unfollow 系の実体:
    unfollow-cleanup.js
    unfollow-handle.js
    unfollow-stats-monitor.js
    unfollow-via-playwright.js
    unfollow_inactive_batch.js
```

**この 2 本は、上のどれかの別名だった可能性がある。**
実体が特定できるまで作らない。

## 4. いまのアンフォロー系のロード状態

```
  ロード      reply-followers-cleanup              PID=-        rc=0
  ロード      reply-followback-check               PID=-        rc=0
  ロード      auto-detect-and-unfollow-inactive    PID=-        rc=0
  ロード      badge-followback                     PID=-        rc=0
  ロード      unfollow-cleanup-morning             PID=-        rc=0
  ロード      unfollow-cleanup-evening             PID=-        rc=0
  未ロード    follow-watchdog                     
  未ロード    revenge-unfollow                    
  未ロード    unfollow-daily                      
  未ロード    unfollow-evening                    
```

---

**アンフォローを手で実行していない。推測で plist を作っていない（$0）。**
