# 500円モーニングの告知を出す（2026-09-23 21:10 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-23 21:10:19 JST**

> **画像は [2/2] に 1 枚。** これまでと形が違う（利用者が選んだ）。
> **文面は承認済みのものを 1 文字も変えていない**（最上位ルール 18）。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. `x136` のパッチが当たっているか（**当たっていなければ積まない**）

**「マージしたから当たったはず」で進めない**（`rc=0` は証拠にならない・最上位ルール 13）。
**実物のファイルを見て、4 つ揃っているかを確かめる。**

```
  (1) 引数が 3 つ            : OK
  (2) setInputFiles         : OK
  (3) 添付の確認つき        : OK
  (4) reply に画像を渡す    : OK

  --- run-publish.sh の reply 行 ---
9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
122:      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\" \"\${imagePath}\"\`;
188:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
```

- **4 つとも揃っている。** 画像が付かなければ `post-comment.js` 側が `ok:false` で止める
- ロックを置いた

## 2. X の重みを先に数える（**280 を超えていたら積まない**）

**和文は 1 文字が 2。** URL は t.co で常に 23。

```
  [1/2] 266 / 280（余裕 14）
  [2/2] 268 / 280（余裕 12）
```

## 3. 画像 1 枚を `origin/main` から取り出す

**作業ツリーは main とは限らない。** ポーラーはタスクを読むだけで切り替えない。
**絵を直しても取り直さないと古い絵が出る。**

```
  取得  cover-a.jpg    179000 bytes
```

- **出所の行は焼き込んでいない**（最上位ルール 8）。ロゴは商標・識別目的

## 4. キューに積む（**画像は chain[1] にだけ**）

```json
{"ok":true,"id":"blog-promo-20260923-morning-500-2026-v2"}
```

- `id`: `blog-promo-20260923-morning-500-2026-v2`／`kind`: `thread`／`thread_chain`: 2 本
- **画像は `chain[1]` にだけ 1 枚**（`chain[0]` は文字だけ）

## 5. Chrome は健全か（**口は 18810**）

**ポートが開いているだけでは健全ではない。** ハングした Chrome も
`/json/version` に 200 を返す。**ログアウト中に走らせると [1/2] だけ出て片肺になる。**

```
/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26
    throw new Error(message || "Assertion error");
          ^

Error: targetInfo: {
  "targetId": "2E0A90F0485A72303301ACCAB665F8A1",
  "type": "shared_worker",
  "title": "",
  "url": "blob:https://www.jal.co.jp/44753b3e-d0f1-4f21-907a-73d43e699a13",
  "attached": true,
  "canAccessOpener": false
}
    at assert (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/utils/isomorphic/assert.js:26:11)
    at CRBrowser._onAttachedToTarget (/Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crBrowser.js:140:30)
    at CRSession.emit (node:events:509:20)
    at /Users/ny/.openclaw/workspace/node_modules/playwright-core/lib/server/chromium/crConnection.js:138:14

Node.js v26.0.0
(rc=1)
```

## 6. 出す（**`cut` で切らない**）

```
[run-publish] thread_chain mode
[step] connect t=0ms
[step] navigate-target t=186ms
[step] find-reply-textarea t=6608ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=6693ms
[step] type-text t=6693ms
[step] attach-image n=1 t=11087ms
[step] arm-response-listener t=13580ms
[step] submit t=13581ms
[step] wait-response-or-confirm t=13698ms
[step] wait-textarea-clear t=14445ms
{"ok":true,"tweet_id":"2102732457930064353","url":"https://x.com/heng_ji31590/status/2102732457930064353","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2102732457930064353","url":"https://x.com/heng_ji31590/status/2102732457930064353","image_attached":false,"captured_via":"graphql_response"},{"index":1,"role":"cta","ok":true,"reply_tweet_id":"2102732550989115457","url":"https://x.com/heng_ji31590/status/2102732550989115457","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 7. 出たか。**出たならキューに書き戻す**

`run-publish.sh` は成功しても書き戻さない。**放っておくと次が二重投稿する。**

```
  [1/2] tweet_id = 2102732457930064353
  [2/2] tweet_id = 2102732550989115457
  キューを posted に書き戻した
```

### 最終状態

- 投稿済みエントリ: **1 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260923-morning-500-2026-v2",
 "status": "posted",
 "x_tweet_id": "2102732457930064353",
 "weight": 266,
 "top_images": 0,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "weight": 266,
   "images": 0,
   "tweet_id": "2102732457930064353",
   "posted": true
  },
  {
   "n": 2,
   "role": "cta",
   "weight": 303,
   "images": 1,
   "tweet_id": "2102732550989115457",
   "posted": true
  }
 ],
 "error": null
}
```

**2 本とも `posted: true` でなければ、出ていないか片肺。黙って「出ました」と言わない。**
**一次情報は `x_tweet_id` と投稿 URL の実物だけ**（最上位ルール 11）。

**[2/2] に画像が付いているかは、キューの数字では分からない。**
X 上の実物を見て確かめること。

---

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
**X 上の手動投稿はキューからは見えない。**
