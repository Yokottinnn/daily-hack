# 都心の格安スーパーの告知を**出し直す**（2026-09-21 18:22 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-21 18:22:52 JST**

> **1 回目（17:00）は利用者が画像を直すため削除した。** 表紙を作り直して出し直す。
> **出す時刻も利用者が選んだ**（「21日中に投稿してほしい」→ 17:00〜18:00 JST）。
> **文面は利用者がレビューページで書き換えたものを 1 文字も変えずに使う。**

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**
- ロックを置いた

## 1. X の重みを先に数える（**280 を超えていたら積まない**）

**和文は 1 文字が 2。** URL は t.co で常に 23。

```
  [1/2] 237 / 280（余裕 43）
  [2/2] 190 / 280（余裕 90）
```

## 2. 画像 4 枚を `origin/main` から取り出す

**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。
**絵を直しても取り直さないと古い絵が出る。**

```
  取得  1-summary.jpg      208259 bytes
  取得  2-maibasket.jpg    269574 bytes
  取得  3-hanamasa.jpg     209413 bytes
  取得  4-tv.jpg           123198 bytes
```

- 順番: **表紙（7社ロゴ）→ まいばすけっと → 肉のハナマサ → TV 3社**
- **出所の行は焼き込んでいない**（2026-09-20 の指示・最上位ルール 8）。
  写真は CC0 と各社ロゴだけで組んであるので、表記を消しても違反にならない

## 3. キューに積む（契約どおりの形）

```json
{"ok":true,"id":"blog-promo-20260921-tokyo-discount-supermarket-2026-v2"}
```

- `id`: `blog-promo-20260921-tokyo-discount-supermarket-2026-v2`（`blog-promo-` 始まり）／`kind`: `thread`／`thread_chain`: 2 本

## 4. Chrome は健全か（**口は 18810**）

**ポートが開いているだけでは健全ではない。** ハングした Chrome も
`/json/version` に 200 を返す。**ログアウト中に走らせると [1/2] だけ出て片肺になる。**

```
{"ok":true,"healthy":true,"round_trip_ms":672,"product":"Chrome/140.0.7339.207","tabs":4}
(rc=0)
```

## 5. 出す（**`cut` で切らない**）

**`run-publish.sh <id>` を使う。** 今日はもう歩いてポイ活を出しているので、
`auto-x-publisher.js` なら同日ガードで弾かれる（契約書 §4）。

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=332ms
[step] find-reply-textarea t=6553ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6617ms
[step] type-text t=6617ms
[step] arm-response-listener t=10493ms
[step] submit t=10497ms
[step] wait-response-or-confirm t=10638ms
[step] wait-textarea-clear t=10976ms
{"ok":true,"tweet_id":"2101965436426564045","url":"https://x.com/heng_ji31590/status/2101965436426564045","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2101965436426564045","url":"https://x.com/heng_ji31590/status/2101965436426564045","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2101965516718187002","url":"https://x.com/heng_ji31590/status/2101965516718187002","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 6. 出たか。**出たならキューに書き戻す**

`run-publish.sh` は成功しても書き戻さない。**放っておくと次が二重投稿する。**

```
  [1/2] tweet_id = 2101965436426564045
  [2/2] tweet_id = 2101965516718187002
  キューを posted に書き戻した
```

### 最終状態

- 投稿済みエントリ: **1 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260921-tokyo-discount-supermarket-2026-v2",
 "status": "posted",
 "x_tweet_id": "2101965436426564045",
 "weight": 237,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 237,
   "tweet_id": "2101965436426564045",
   "posted": true
  },
  {
   "n": 2,
   "role": "cta",
   "weight": 240,
   "tweet_id": "2101965516718187002",
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
