# 歩いてポイ活の告知スレッドを X へ出す（2026-09-21 00:26 JST・費用 $0）

> 本文と画像 4 枚は **2026-09-20 にレビューページとチャットで実物を見たうえで承認済み**。
> **文面は利用者がレビューページで自分で書き換えたもの。**
> ただし「年間300〜1,000マイル」は記事の表の見出しが「月いくら」だったため
> **「月300〜1,000マイル」**に直してある（そのままだと 12 倍 になる）。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**
- ロックを置いた

## 1. X の重みを先に数える（**280 を超えていたら積まない**）

**和文は 1 文字が 2。** URL は t.co で常に 23。

```
  [1/2] 235 / 280（余裕 45）
  [2/2] 155 / 280（余裕 125）
```

## 2. 画像 4 枚を `origin/main` から取り出す

**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。
**絵を直しても取り直さないと古い絵が出る。**

```
  取得  1-summary.jpg    240429 bytes
  取得  2-waon.jpg       109862 bytes
  取得  3-web3.jpg       219969 bytes
  取得  4-mile.jpg       193612 bytes
```

- 順番: **表紙 → WAON → Web3 → マイル**

## 3. キューに積む（契約どおりの形）

```json
{"ok":true,"id":"blog-promo-20260920-walk-poikatsu-2026"}
```

- `id`: `blog-promo-20260920-walk-poikatsu-2026`（`blog-promo-` 始まり）／`kind`: `thread`／`thread_chain`: 2 本

## 4. Chrome は健全か（**口は 18810**）

**ポートが開いているだけでは健全ではない。** ハングした Chrome も
`/json/version` に 200 を返す（`ensure-chrome.sh` の但し書き・CDP timeout 18,087 件）。
**ログアウト中に走らせると [1/2] だけ出て片肺になる。**

```
{"ok":true,"healthy":true,"round_trip_ms":393,"product":"Chrome/140.0.7339.207","tabs":3}
(rc=0)
```

## 5. 出す（**`cut` で切らない**）

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=162ms
[step] find-reply-textarea t=6296ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6345ms
[step] type-text t=6345ms
[step] arm-response-listener t=9826ms
[step] submit t=9829ms
[step] wait-response-or-confirm t=9939ms
[step] wait-textarea-clear t=10333ms
{"ok":true,"tweet_id":"2101694599215599678","url":"https://x.com/heng_ji31590/status/2101694599215599678","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2101694599215599678","url":"https://x.com/heng_ji31590/status/2101694599215599678","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2101694677514846544","url":"https://x.com/heng_ji31590/status/2101694677514846544","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 6. 出たか。**出たならキューに書き戻す**

`run-publish.sh` は成功しても書き戻さない。**放っておくと次が二重投稿する。**

```
  [1/2] tweet_id = 2101694599215599678
  [2/2] tweet_id = 2101694677514846544
  キューを posted に書き戻した
```

### 最終状態

- 投稿済みエントリ: **1 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260920-walk-poikatsu-2026",
 "status": "posted",
 "x_tweet_id": "2101694599215599678",
 "weight": 235,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 235,
   "tweet_id": "2101694599215599678",
   "posted": true
  },
  {
   "n": 2,
   "role": "cta",
   "weight": 192,
   "tweet_id": "2101694677514846544",
   "posted": true
  }
 ],
 "error": null
}
```

**2 本とも `posted: true` でなければ、出ていないか片肺。黙って「出ました」と言わない。**
**一次情報は `x_tweet_id` と投稿 URL の実物だけ**（最上位ルール 11）。

---

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
**X 上の手動投稿はキューからは見えない。**
