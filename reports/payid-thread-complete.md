# PAY ID スレッドの続きを足す（2026-09-27 16:41 JST・$0）

**このレポートが作られた時刻: 2026-09-27 16:41:36 JST**

> **[1/3] は触らない。** 足すのは [2/3] と [3/3] だけ。
> **門が 1 つでも通らなければ 1 本も出さない。**

## 1. 落ちた本当の理由（**次の手がかり**）

**`x165` は末尾 14 行しか出していない。** エラー文を最後まで出す。

```
  {"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"QkFTReOBp+S9nOOCieOCjOOBn+OCt+ODp+ODg+ODl+KAlOKAlOOBguOBruWAi+S6uuWVhuW6l+OBv+OBn+OBhOOBquODjeODg+ODiOOCt+ODp+ODg+ODl+OBjOOAgeOBnOOCk+OBtuOBk+OBruOCouODl+ODquOBi+OCieiyt+OBiOOCi+OBruOAgjIsMDAw5LiH44Ki44Kr44Km44Oz44OI56qB56C044CBQXBwIFN0b3Jl44Gu6KmV5L6hNC42NeOAggoK6aOf5ZOB44O76Kq/5ZGz5paZ
  [2026-09-27 12:00:30] done rc=0

  --- 守り（x150）が働いた形跡 ---
  wrong-page       0 件
  no-focus         0 件
  text-mismatch    0 件
```

## 2. 文面を `origin/main` から読む（**作業ツリーを信じない**）

```
    [1/3] 重み 226 / 頭: PAY ID、招待コード入れるだけで500円分もらえ
    [2/3] 重み 218 / 頭: BASEで作られたショップ——あの個人商店みたいなネ
    [3/3] 重み 231 / 頭: 極めつけが「PAY ID あと払い」。⏎今日買って翌
```

## 3. [1/3] を探して、足りない分だけ出す

```
  rc=0

  [x168] TL から読めた件数: 7
  [x168] [1/3] が TL に無い（頭 24 字で一致しない）。読めた 7 件
  [x168]   候補: null | フェアモント東京のクラブラウンジ。朝食はオーダーメニュー＋ビュッフェ
  [x168]   候補: /heng_ji31590/status/2104104877668680175 | クラブラウンジでリコッタパンケーキ、いいわね。焼きたてふわふわって朝
  [x168]   候補: null | おはようございます🍦な、な、ななんとタピオカの日は、本日で最後とな
  [x168]   候補: /heng_ji31590/status/2104104794084544828 | ラスト販売か。タピオカの日って期間限定だったんだ。湘南モールフィルな
  [x168]   候補: null | 特定口座は、、売っても問題ない銘柄を新NISAは、持ち続けられる銘柄
  [x168]   候補: /heng_ji31590/status/2103663023621837140 | あ、権利日狙いか。単元化の手法、アタシもやってるけど、その先の配当狙
  {
    "ok": false,
    "found_root": null,
    "posted": [],
    "skipped": [],
    "error": "[1/3] が TL に無い（頭 24 字で一致しない）。読めた 7 件"
  }
```

## 4. 結果の読み方

| `§3` の出方 | 意味 |
| --- | --- |
| `ok:true` ／ `posted` に 2 本 | **スレッドが揃った。** URL を報告する |
| `ok:true` ／ `skipped` に 2 本 | **すでに揃っていた。** 何もしていない |
| `[1/3] が TL に無い` | **[1/3] も出ていない。** 出し直しが要る（候補を §3 に出してある） |
| `打った文が違う` | **守りが働いた。** 送っていない。入力の壊れ方を見る |
| `押したのに出ていない` | **X 側で弾かれた。** 重み・画像・レート制限を見る |

**`posted` が空で `error` も無いことは起きない。** どちらかが必ず出る。

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
