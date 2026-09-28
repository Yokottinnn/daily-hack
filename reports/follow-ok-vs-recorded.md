# 「通った」と「記録」の差を測る（2026-09-29 01:03 JST・$0）

**このレポートが作られた時刻: 2026-09-29 01:03:14 JST**

> ログのファネルは **8〜22 件/日**、`followed.json` は **1〜4 件/日**。**5〜10 倍 合わない。**
> **決め手は「OK になった相手が、いまフォロー中の一覧に居るか」。**
> **読むだけ。フォローも外しもしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**

## 1. ログの生の行（**当て推量しないために、まず そのまま出す**）

`OK` がどう書かれているかを確かめていないので、**末尾を切らずに見る。**

### 1-A. competitor-follower-follow（末尾 45 行）

```
    @<伏せ>: ❌ follower count out of range (0, need 10-50000)
  [2026-09-28T09:35:43.013Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
    @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
  [2026-09-28T09:36:16.867Z]   @<伏せ>: ❌ inactive (last post 43d ago)
    @<伏せ>: ❌ inactive (last post 43d ago)
  [2026-09-28T09:36:50.539Z]   @<伏せ>: ❌ inactive (last post 57d ago)
    @<伏せ>: ❌ inactive (last post 57d ago)
  [2026-09-28T09:37:23.772Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
    @<伏せ>: ❌ Phase 2: no relevant topic in bio
  [2026-09-28T09:37:57.617Z]   @<伏せ>: ❌ Phase 1: no mutual-intent keyword & ratio mismatch (fw=0/fr=22)
    @<伏せ>: ❌ Phase 1: no mutual-intent keyword & ratio mismatch (fw=0/fr=22)
  [2026-09-28T09:38:33.242Z]   @<伏せ>: ✅
    @<伏せ>: ✅
  [2026-09-28T09:39:06.904Z]   @<伏せ>: ❌ follower count out of range (121000, need 100-50000)
    @<伏せ>: ❌ follower count out of range (121000, need 100-50000)
  [2026-09-28T09:39:40.907Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
    @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
  [2026-09-28T09:40:15.008Z]   @<伏せ>: ❌ inactive (last post 49d ago)
    @<伏せ>: ❌ inactive (last post 49d ago)
  [2026-09-28T09:40:48.977Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): tztRqruHmL46269
    @<伏せ>: ❌ random-looking handle (likely throwaway/spam): tztRqruHmL46269
  [2026-09-28T09:41:23.013Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
    @<伏せ>: ❌ Phase 2: no relevant topic in bio
  [2026-09-28T09:41:56.752Z]   @<伏せ>: ❌ inactive (last post 103d ago)
    @<伏せ>: ❌ inactive (last post 103d ago)
  [2026-09-28T09:42:30.944Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
    @<伏せ>: ❌ Phase 2: no relevant topic in bio
  [2026-09-28T09:43:04.840Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): JSFBowd4aT1890
    @<伏せ>: ❌ random-looking handle (likely throwaway/spam): JSFBowd4aT1890
  [2026-09-28T09:43:38.538Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
  [2026-09-28T09:44:12.675Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
    @<伏せ>: ❌ Phase 2: no relevant topic in bio
  [2026-09-28T09:44:46.623Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): TaWS0SLfVqVJ6XE
    @<伏せ>: ❌ random-looking handle (likely throwaway/spam): TaWS0SLfVqVJ6XE
  [2026-09-28T09:45:19.926Z]   @<伏せ>: ❌ inactive (last post 36d ago)
    @<伏せ>: ❌ inactive (last post 36d ago)
  [2026-09-28T09:45:53.883Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
  [2026-09-28T09:46:27.655Z]   @<伏せ>: ❌ Phase 2: no relevant topic in bio
    @<伏せ>: ❌ Phase 2: no relevant topic in bio
  [2026-09-28T09:47:01.722Z]   @<伏せ>: ❌ inactive (last post 235d ago)
    @<伏せ>: ❌ inactive (last post 235d ago)
  [2026-09-28T09:47:31.740Z] === end: 1/30 OK ===
  === end: 1/30 OK ===
```

### 1-B. 成功らしき行の書き方（**重複を潰して形だけ見る**）

```
   503   @H: ✅
   206   @H: ❌ refollow blacklist (manually unfollowed in past)
    54 === competitor-follower start: target=@H (day-rotation index=N/N) cap=N ===
    52 scraped N followers from @H
    40   @H: ❌ follower count out of range (N, need N-N)
    27   @H: ❌ no follow button (private/blocked/deleted)
    22   @H: ❌ random-looking handle (likely throwaway/spam): momoN
    22   @H: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    18   @H: ❌ random-looking handle (likely throwaway/spam): oyunnN
    16   @H: ❌ random-looking handle (likely throwaway/spam): fYpkHXNwHENoYmG
    16   @H: ❌ random-looking handle (likely throwaway/spam): ZiNCKAHFN
    14   @H: ❌ random-looking handle (likely throwaway/spam): tztRqruHmLN
    14   @H: ❌ random-looking handle (likely throwaway/spam): pesoN
    13   @H: ❌ random-looking handle (likely throwaway/spam): EGarthN
```

## 2. 日ごとの突き合わせ

```
  日付       end の OK     記録  押せず
  2026-09-19           8         1         0
  2026-09-20          18         2         0
  2026-09-21          22         2        10
  2026-09-22          14         3         0
  2026-09-23          10         1         2
  2026-09-24          10         1         2
  2026-09-25          20         4         0
  2026-09-26          16         0         4
  2026-09-27          16         3         0
  2026-09-28           8         2         0
  合計                142        19        18

  ※ 「記録」は competitor だけでなく **全経路ぶん**（hashtag も followback も含む）
  ※ それでも end の OK より小さいなら、**OK が実っていない**
```

## 3. **決め手**: OK になった相手が、いまフォロー中の一覧に居るか

居れば **B（記録の漏れ。実害は小さい）**、居なければ **A（押せていない）**。

```
  対象の日: 2026-09-26 2026-09-27 2026-09-28
  成功らしき行: 32 行 / そこから取れたハンドル: 22 件

  一覧のキャッシュ: 104 分 前 / フォロー中 190 件

  いまフォロー中に **居る**   4 件（うち相互 2 件）
  いまフォロー中に **居ない** 18 件

  → **A の疑いが濃い。押せていないか、すぐ外されている**
     ※ ただし **こちらの unfollow ジョブが外した**可能性も残る。
       `follow-balance-state.json` と突き合わせるのが次の一手
```

## 4. 参考: 押せなかった記録

```
  「クリックしても フォロー中 に変わらなかった」  50 件（competitor 全期間）
  「ボタンが無い」                                602 件
  competitor のログ  436565 bytes / 更新 09-28 18:47
  hashtag のログ     149501 bytes / 更新 09-28 17:03
```

---

## 読み方

| §3 の出方 | どれか | 次にやること |
| --- | --- | --- |
| **70% 以上 が一覧に居る** | **B. 記録の漏れ** | `followed.json` の書き込みを直す。**実害は小さい** |
| **30% 以下** | **A. 押せていない** | **180 回 が無駄になっている。** ここを直すのが最優先 |
| 成功の行が 0 行 | **測れていない** | §1-B の形を見てパターンを直す（**0 は「無い」ではない**）|

**フォローしていない。外していない。設定も変えていない。**
**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
