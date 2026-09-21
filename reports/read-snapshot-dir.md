# `follower-snapshots/` を読む（2026-09-21 12:59 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 12:59:04 JST**

> `follower-history.json` は **2026-05-23 で止まっていた**うえ、
> **最後の行が `followers: 0` の誤読**だった（前日 51 人 → 0 人）。
> `heartbeat` は 266 を出せているので、**実データは別の場所にある。**

## 1. 何が在るか

```
  /Users/ny/.openclaw/workspace/data/follower-snapshots
  ファイル数: 53
  --- 新しい順に 12 件 ---
    2026-09-20.json
    2026-09-08.json
    2026-09-07.json
    2026-08-29.json
    2026-08-28.json
    2026-08-27.json
    2026-08-26.json
    2026-08-25.json
    2026-08-24.json
    2026-08-23.json
    2026-08-22.json
    2026-08-21.json
  --- 古い順に 3 件 ---
    2026-05-26.json
    2026-05-25.json
    2026-05-23.json
```

## 2. 1 本 だけ中身を見る（**形を決め打ちしない**）

```json
  --- 2026-09-20.json ---
{
  "taken_at": "2026-09-20T15:35:49.558Z",
  "username": "heng_ji31590",
  "count": 266,
  "followers": [
    "0025563h",
    "01koara",
    "10qlzr",
    "1192KMKR1185",
    "1UNIApjv3r1051",
    "1oku_made",
    "1xQ12jhpZeUJBRD",
    "2778adg",
    "29_inadaira",
    "5buzuki",
    "7cd2y",
    "8LiSshuKwl1636",
    "AO_flower666",
    "AakritiFla16065",
    "After_All_Lucky",
    "AgentGrow2026",
    "AlinawazTrader",
    "Avery_Ca0rter",
    "Butokumaru_naro",
    "COm9fN5ieL45410",
    "ChangChe_Chuan",
    "Cute1_RinRin",
    "DWkouv",
    "Darkphantom9990",
    "DrLeslieKi1s",
    "Edwarduklfc",
    "FANGsaikyou",
    "FamicammpBazzz",
    "GfbYZbYR3R40255",
    "GpYalaz2ow97965",
    "HARUTO_FIRE",
    "HGqghALjT7T23Bd",
    "Huyegd",
    "HyattMarie3195",
    "IrodoriMoney",
    "JoystersX",
    "Kaosu_099",
    "Ken_ichi_YY",
    "Kerokeroke2020",
    "Key4pso2",
    "Laugh_r
```

## 3. 読めたら日次ペース

```
  日付つきの人数を 1 件も取れなかった
```

## 4. 壊れた記録について

**`follower-history.json` の最終行（2026-05-23・`followers: 0`）は誤読。**
**このタスクでは消さない。** 何が読んでいるかを確かめてから決める
（消してよいか判断する前に、参照元を洗う）。

## 5. 費用

**ファイルを読んで並べるだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |
