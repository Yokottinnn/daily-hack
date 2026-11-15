# どのタグが何を連れてくるか

**このレポートが作られた時刻: 2026-09-20 17:24:57 JST**

> `hashtag-follow` は**上限 90 に対して 1 日 0〜4 件**（x101）。
> **上限ではなく入口の問題。** 上限を上げても増えない。

**測るだけ。タグを変えない。**

## 1. いま使っているタグ（**実物**）

```
  /Users/ny/.openclaw/workspace/scripts/hashtag-follow.js（177 行 / 2026-09-13 19:58）

  --- タグの一覧を持っていそうな箇所 ---
    3: * hashtag-follow.js — Tier A: ハッシュタグ active 投稿者を follow 候補化
    114:  const targets = [];
    142:  const results = [];


  --- 環境変数で渡せるか ---
    30:const DAILY_CAP = parseInt(process.env.HASHTAG_FOLLOW_DAILY_CAP || "10", 10);
    87:  if ((todayDow === 0 || todayDow === 1) && !process.env.FORCE_RUN) {
```

**環境変数で渡せるなら plist を書き換えるだけで済む。** 戻すのも簡単。

## 2. タグごとの成績（**ログから**）

```
  --- タグを出している行の形を見る ---

  --- 直近 30 回 の拾い件数 ---
    平均 1.5 件/回（30 回 ぶん）

  --- 弾いた理由（全期間）---
      128 回  ❌ follower count out of range
       43 回  ❌ follower>>following exclusion: ratio=.
       42 回  ❌ inactive
       29 回  ❌ random-looking handle
       28 回  ❌ exec err: Command failed: /usr/local/bin/node /Users/ny/.ope
       21 回  ❌ low-density bio
       18 回  ❌ off-niche bio
       10 回  ❌ no follow button
        4 回  ❌ Phase : no relevant topic in bio
        3 回  ❌ Phase : no mutual-intent keyword & ratio mismatch
        2 回  ❌ page.goto: Timeout ms exceeded.
        2 回  ❌ influencer exclusion: following/follower=.

  --- **実際にフォローできた件数**（弾かれなかったもの）---
    63
```

**「大きすぎる」で弾かれる割合が高いタグは、公式アカウントが集まるタグ。**
個人の投稿が多いタグに入れ替えると、拾える数が増える見込み。

## 3. 費用

**ログとソースを読むだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**タグを入れ替えるのも $0**（DOM 操作のみ）。
返信ループは `MAX_PICKS` 6 で **約 $0.95/月（推定）**。実測は明日 確かめる。
