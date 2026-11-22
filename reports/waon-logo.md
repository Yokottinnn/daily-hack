# WAON POINT のロゴを取る

**このレポートが作られた時刻: 2026-09-20 17:59:25 JST**

> クラウドからは外部 HTTPS が**全部 塞がれている**（`connect_rejected` / 000）。
> `x-post-images` スキルの「**Mac に取らせる**」経路をそのまま使う。

**取るだけ。投稿しない。画像も作らない。**

## 1. 取得

```
  HTTP 200
  大きさ: 10265 bytes
  種類  : PNG image data, 412 x 228, 8-bit colormap, non-interlaced
  PNG の署名: **在る**
```

## 2. base64

クラウド側で次のように戻す。

```bash
git show origin/ops/heartbeat:reports/waon-logo.md \
  | sed -n '/^BEGIN_B64$/,/^END_B64$/p' | sed '1d;$d' | tr -d '\n' \
  | base64 -d > public/images/walk-poikatsu-2026/waon-point.png
```

```
BEGIN_B64
END_B64
```

## 3. 扱いの注意

**これはイオンの商標。** 記事とその告知で WAON POINT を指すために使う
（このリポジトリでは他の記事でも各社のロゴを同じ形で使っている）。
**CC の写真とは扱いが違うので、`credit` は「出典」ではなく商標の表記にする。**

## 4. 費用

**1 ファイル 取るだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループは `MAX_PICKS` 6 で **約 $0.95/月（推定）**。実測は明日 確かめる。
