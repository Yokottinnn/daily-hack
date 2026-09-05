# モーニング告知スレッドを X へ出す（2026-09-05 21:52 JST・費用 $0）

> 本文と画像 4 枚は **2026-09-05 にチャットで実物を見たうえで承認済み**。
> `kind:"thread"` / `id` は `blog-promo-` 始まり / 画像は `image_path` にカンマ区切り /
> スレッドは `thread_chain[]` を `run-publish.sh` で出す——契約どおりに積む。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**
- ロックを置いた

## 1. 画像 4 枚を `origin/main` から取り出す

作業ツリーは main とは限らないので、**`git show` で取り出す。**

```
  取得        1-summary.jpg    245671 bytes
  取得        2-matsuya.jpg    157075 bytes
  取得        3-komeda.jpg     171572 bytes
  取得        4-sukiya.jpg     212141 bytes
```

- `image_path`: 4 枚（**カンマ区切り**）

## 2. キューに積む（契約どおりの形）

```json
{"ok":true,"id":"blog-promo-20260905-morning-500-2026"}
```

- `id`: `blog-promo-20260905-morning-500-2026`（`blog-promo-` 始まり）
- `kind`: `thread` / `thread_chain`: **2 本**

## 3. Chrome / CDP は健全か

**ログアウト状態で `thread_chain` を走らせると [1/2] だけ出て [2/2] が落ちる。**

```
```

- CDP: **NG**

- → **CDP が健全でないので投稿しない。** エントリはキューに残してある。
- Chrome にログインし直したうえで、次のタスクで `run-publish.sh blog-promo-20260905-morning-500-2026` を叩けば出る。

**まだ出していない。**
