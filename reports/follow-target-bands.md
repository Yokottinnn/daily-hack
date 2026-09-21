# フォロー先は帯で絞っているか（2026-09-21 14:22 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 14:22:58 JST**

> `followback_bands` を並べ直したら、**帯で返し率が 10 倍 違った。**
> **300-999 が 42.9%、5000+ が 4.5%。** なのに成熟した試行 81 件 のうち
> **51 件（63%）が 1000 人 以上**に使われている。
>
> **直す前に、いま絞っているかを見る**（最上位ルール 15）。
> 既に絞りが在るのに足すと、二重にかかって候補が消える。

## 1. plist の環境変数（**上限・下限がここに在ることが多い**）

```
  ===== ai.openclaw.competitor-follower-follow =====
        "COMPETITOR_FOLLOW_DAILY_CAP" => "30"
      "Label" => "ai.openclaw.competitor-follower-follow"
      "ProgramArguments" => [
        1 => "/Users/ny/.openclaw/workspace/scripts/competitor-follower-follow.js"
      "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow-err.log"
      "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/competitor-follower-follow.log"
      "StartCalendarInterval" => [
          "Hour" => 11
          "Minute" => 30
          "Hour" => 18
          "Minute" => 30
    --- 載っているか ---
    	state = not running
    	runs = 5
    	last exit code = 0

  ===== ai.openclaw.hashtag-follow =====
        "HASHTAG_FOLLOW_DAILY_CAP" => "90"
      "ProgramArguments" => [
      "StartCalendarInterval" => [
          "Hour" => 10
          "Minute" => 15
          "Hour" => 17
          "Minute" => 0
    --- 載っているか ---
    	state = not running
    	runs = 5
    	last exit code = 0

```

## 2. JS の中で、フォロワー数で弾いているか（**変数名で引く**）

**`readFileSync` のような決め打ちで引かない。** x120 でそれをやって
**「使っていない」と誤判定した**（実体は `loadJson()` 経由だった）。

```javascript
  ===== competitor-follower-follow.js =====
    159:            followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,

  ===== hashtag-follow.js =====
    157:            followers_at_follow: (r.profile && typeof r.profile.follower_count === "number") ? r.profile.follower_count : null,

```

**該当なしなら、いまは帯で絞っていない。** 5000+ に毎日 消えている。

## 3. 種（seeds）は誰か

**種が大手ばかりなら、そのフォロワーを辿っても大手寄りになる。**
絞りを足す前に、**種のほうが原因かもしれない。**

```
    follower-target-config.json
    follower-target-config.json.bak
    post_queue.json.bak.20260515-hashtag-reduce
    quick-reply-targets.json
```

## 4. 直近のログ（**見た人数と、実際にフォローした人数**）

```
  ===== competitor-follower-follow.log / 2026-09-21 11:47 =====
    [2026-09-21T02:43:50.802Z]   @<伏せ>: ❌ inactive (last post 105d ago)
      @<伏せ>: ❌ inactive (last post 105d ago)
    [2026-09-21T02:44:25.521Z]   @<伏せ>: ✅
      @<伏せ>: ✅
    [2026-09-21T02:44:58.853Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    [2026-09-21T02:45:32.221Z]   @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
      @<伏せ>: ❌ low-density bio (空 or テンプレキーワードのみ)
    [2026-09-21T02:46:05.311Z]   @<伏せ>: ❌ inactive (last post 230d ago)
      @<伏せ>: ❌ inactive (last post 230d ago)
    [2026-09-21T02:46:38.315Z]   @<伏せ>: ❌ follower count out of range (0, need 10-50000)
      @<伏せ>: ❌ follower count out of range (0, need 10-50000)
    [2026-09-21T02:47:08.335Z] === end: 5/30 OK ===
    === end: 5/30 OK ===

  ===== hashtag-follow.log / 2026-09-21 10:20 =====
    [2026-09-21T01:18:05.393Z] today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
    today already follows: 0 (A:0+B:0) / DAILY_CAP=90 / remaining=90
    [2026-09-21T01:18:05.393Z] picks: 4 authors
    picks: 4 authors
    [2026-09-21T01:18:08.707Z]   @<伏せ>: ❌ follower count out of range (103000, need 100-50000)
      @<伏せ>: ❌ follower count out of range (103000, need 100-50000)
    [2026-09-21T01:18:41.843Z]   @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
      @<伏せ>: ❌ off-niche bio (ダイエット/オタ活/ペット等)
    [2026-09-21T01:19:15.084Z]   @<伏せ>: ❌ random-looking handle (likely throwaway/spam): toshi00213591
      @<伏せ>: ❌ random-looking handle (likely throwaway/spam): toshi00213591
    [2026-09-21T01:19:50.004Z]   @<伏せ>: ✅
      @<伏せ>: ✅
    [2026-09-21T01:20:20.024Z] === end: 1/4 OK ===
    === end: 1/4 OK ===

```

**「見た N / フォローした M」が両方 出ていないと、絞りが効いたか分からない。**

## 5. 読み方（**このタスクでは直さない**）

| 出方 | 次の一手 |
| --- | --- |
| 帯の絞りが無い | **5000+ を外す上限を入れる。** DOM 操作のみなので $0 |
| 絞りが在るのに 5000+ が多い | **絞りが効いていない。** 判定を見る |
| 種が大手ばかり | **絞りより種を替えるほうが速い** |
| 載っていない | そもそも動いていない。**先に戻す話** |

**母数の注意。** `300-999` は成熟 14 件 しかないので 42.9% は誤差が大きい。
**`5000+` は母数 22 で 4.5%** なので、こちらは低いと言い切れる。
**「300-999 を狙う」より「5000+ を外す」のほうが、根拠が強い。**

## 6. 費用

**plist とソースとログを読むだけ。LLM を呼ばない。**
**フォロー自体も DOM 操作のみで LLM を呼ばない**ので、帯を変えても課金は増えない。

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
