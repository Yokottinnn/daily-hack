# 返り率の悪い 3 種 を外す

**このレポートが作られた時刻: 2026-09-20 17:10:59 JST**

> 外す 3 つ  mature  89 件 →  7 人   **7.9%**
> 残す 4 つ  mature 133 件 → 28 人   **21.1%**
>
> x99 では、返ってきた 27 人 のうち**外す 3 種 が連れてきたのは 2 人 だけ。**
> 「外すと空振りが増える」懸念は、x101 で **該当 0 件** と実測で否定された。

**$0**（DOM 操作のみ。LLM を呼ばない）。**退避を残すので戻せる。**

## 0. 当てる前

```
  171 行 / 最終更新 2026-09-13 19:58

  --- いまの配列 ---
    27:const COMPETITORS = [
    28-  "himawari56757", "ukk_hx", "POIKATSU_OTAKE",
    29-  "tokufree3", "okamiler_pn",
    30-  "money_yossy", "haiji_doctor",
    31-];
    32-
    33-const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);
```

## 1. 置き換える（**完全一致で 1 箇所だけ**）

```
    目印の出現回数: 1 箇所
    置き換えた（**検査待ち**）

  --- 検査（**`.js` のままなので macOS でも通る**）---
    node --check: **通った**
    退避: competitor-follower-follow.js.bak-20260920-171059
    **入れ替えた**
```

## 2. 当てた後（**実物**）

```javascript
  27-// 2026-09-20 x102: **返り率の悪い 3 種 を外した。**
  28-//   ukk_hx 4.2% / money_yossy 8.6% / POIKATSU_OTAKE 10.0%
  29-//   群で見ると 外した 3 つ は mature 89 件 → 7 人（7.9%）、
  30-//   残した 4 つ は mature 133 件 → 28 人（21.1%）で **2.7 倍 の差**。
  31-//   9/08→9/20 に返ってきた 27 人 のうち、外した 3 種 は **2 人 だけ**だった。
  32-//   「全 follower 既 follow」で終わった回はログ上 **0 件** で、空振りの懸念は否定済み。
  33-//   **候補が揃ったら 7 種 に戻す。** 退避は .bak-* にある。
  34:const COMPETITORS = [
  35-  "himawari56757", "haiji_doctor",
  36-  "okamiler_pn", "tokufree3",
  37-];
  38-
  39-const DAILY_CAP = parseInt(process.env.COMPETITOR_FOLLOW_DAILY_CAP || "10", 10);

  --- 回し方の行（**種数が 4 になっているか**）---
  123:  const dayIndex = Math.floor(todayDate.getTime() / 86400000) % COMPETITORS.length;
  124:  const competitor = COMPETITORS[dayIndex];
  125:  log(`=== competitor-follower start: target=@${competitor} (day-rotation index=${dayIndex}/${COMPETITORS.length-1}) cap=${DAILY_CAP} ===`);
```

**載せ直しは要らない。** 種はスクリプトの中身で、毎回 読み直される（plist の環境変数ではない）。
**次の定時（11:30 / 18:30）から 4 種 で回る。**

## 3. 期限（9/30）までの当たり方

```
    いままで（7 種）
      9/21 okamiler_pn 18.2%   9/22 **money_yossy 8.6%**   9/23 haiji_doctor 20.8%
      9/24 himawari 26.0%      9/25 **ukk_hx 4.2%**        9/26 **POIKATSU 10.0%**
      → **10 日 のうち 3〜4 日 が悪い種**

    これから（4 種）
      **全部 16.2%〜26.0% の種だけ。** 悪い日は来ない
```

**これは並びの見込みであって、実際の当たりは `epoch 日 % 4` で決まる。**
次の実行ログの `day-rotation index` で確かめる。

## 4. 費用

**`competitor-follower-follow` は DOM 操作のみで LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**種を減らしてもフォロー数の上限は変わらない**（`COMPETITOR_FOLLOW_DAILY_CAP=30`）。
返信ループは `MAX_PICKS` を 6 にしたため **約 $0.95/月（推定）**。
**実測は次の 24 時間 の `cost_24h_usd` で確かめる。**
