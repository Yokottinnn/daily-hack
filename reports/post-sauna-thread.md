# サウナ告知スレッドを X へ出す（t004/t005 の失敗を直した版・2026-08-30 22:54 JST）

> t004 は候補条件 5 つを全部外していた。**コードを読んで形を合わせる。**
> [2/2] は `thread_chain` で同じエントリに入れる（t005 の親 id 受け渡しを廃止）。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**
- 本日投稿済みの blog-promo スレッド: **0 件**（1 件以上なら publisher が skip する）

## 1. t004 が積んだ未投稿エントリを片付ける

- `sauna-x-20260830-223943` を skipped に: {"ok":true}

## 2. 画像を用意する（4 枚。**カンマ区切りで image_path に渡す**）

- 1-summary.jpg: 273571 B
- 2-maihama.jpg: 307907 B
- 3-takanawa.jpg: 187614 B
- 4-oimachi.jpg: 199574 B

## 3. 積む（**候補条件 5 つを満たす形**）

- id: `blog-promo-sauna-20260830-225430`（`blog-promo-` で始まる。本文が入っていないことを確認）
- kind: `thread` / status: `awaiting_approval` / auto_publish: `true` / scheduled_at: `2026-08-30T13:53:30Z`
- thread_chain: **2 要素**（[1/2] に画像 4 枚、[2/2] は画像なし）
- トップレベルに `image_path`/`blog_url` は置かない（refreshCover に上書きさせないため）
```
{"ok":true,"id":"blog-promo-sauna-20260830-225430"}
```

### 積んだ結果を、候補条件そのもので照合する

- [x] status===awaiting_approval
- [x] kind===thread
- [x] id.startsWith(blog-promo-)
- [x] auto_publish===true
- [x] scheduled_at<=now
- 全条件: **満たす**

## 4. 出す

```
{"ok":false,"action":"publish_failed","id":"blog-promo-sauna-20260830-225430","kind":"blog-promo","stdout_tail":"_results\":[{\"index\":0,\"role\":\"hook\",\"ok\":true,\"tweet_id\":\"20940613735842081
```

## 5. 件数（**2 件以上なら事故**）

- 前 0 件 → 後 **0 件**
- **出ていない。** ロックを外す
