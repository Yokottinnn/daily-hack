# IKEA豊洲の告知スレッドを X へ出す（2026-09-06 17:13 JST・費用 $0）

> 本文と画像 4 枚は **2026-09-06 にチャットで実物を見たうえで承認済み**。
> モーニングで踏んだ 5 つの穴（重み／画像の取り直し／CDP の口／マスク／書き戻し）は
> **全部 塞いである。**

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**
- ロックを置いた

## 1. X の重みを先に数える（**280 を超えていたら積まない**）

モーニングは 293 で落ちた。**和文は 1 文字が 2。**

```
  [1/2] 274 / 280
  [2/2] 243 / 280
```

## 2. 画像 4 枚を `origin/main` から取り出す

**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。

```
  取得  1-summary.jpg    263758 bytes
  取得  2-access.jpg     200177 bytes
  取得  3-campaign.jpg   118451 bytes
  取得  4-blahaj.jpg     124883 bytes
```

- 順番: **まとめ → 立地 → キャンペーン → サメ**（2026-09-06 に指定）

## 3. キューに積む（契約どおりの形）

```json
{"ok":true,"id":"blog-promo-20260906-ikea-toyosu-2026"}
```

- `id`: `blog-promo-20260906-ikea-toyosu-2026`（`blog-promo-` 始まり）／`kind`: `thread`／`thread_chain`: 2 本

## 4. Chrome は健全か（**口は 18810**）

**ポートが開いているだけでは健全ではない。** ハングした Chrome も
`/json/version` に 200 を返す（`ensure-chrome.sh` の但し書き・CDP timeout 18,087 件）。

```
{"ok":true,"healthy":true,"round_trip_ms":373,"product":"Chrome/140.0.7339.207","tabs":3}
(rc=0)
```

## 5. 出す（**`cut` で切らない**）

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=165ms
[step] find-reply-textarea t=6310ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6357ms
[step] type-text t=6357ms
[step] arm-response-listener t=9943ms
[step] submit t=9946ms
[step] wait-response-or-confirm t=10049ms
[step] wait-textarea-clear t=10478ms
{"ok":true,"tweet_id":"2096512177930903788","url":"https://x.com/heng_ji31590/status/2096512177930903788","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2096512177930903788","url":"https://x.com/heng_ji31590/status/2096512177930903788","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2096512255596900428","url":"https://x.com/heng_ji31590/status/2096512255596900428","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 6. 出たか。**出たならキューに書き戻す**

`run-publish.sh` は成功しても書き戻さない。**放っておくと次のタスクが二重投稿する。**

```
  [1/2] tweet_id = 2096512177930903788
  [2/2] tweet_id = 2096512255596900428
  キューを posted に書き戻した
```

### 最終状態

- 投稿済みエントリ: **1 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260906-ikea-toyosu-2026",
 "status": "posted",
 "x_tweet_id": "2096512177930903788",
 "weight": 274,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 274,
   "tweet_id": "2096512177930903788",
   "posted": true
  },
  {
   "n": 2,
   "role": "cta",
   "weight": 243,
   "tweet_id": "2096512255596900428",
   "posted": true
  }
 ],
 "error": null
}
```

**2 本とも `posted: true` でなければ、出ていないか片肺。黙って「出ました」と言わない。**

---

**LLM を呼んでいない（$0）。** **X 上の手動投稿はキューからは見えない。**
