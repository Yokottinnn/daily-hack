# 紅葉 2026 の告知スレッドを投稿する（2026-10-11 22:17:53 JST・費用 $0）

> **[1/2] 画像 4 枚（2 枚目に ALT）・[2/2] 記事の紹介。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。

## 00. 残っているエントリの自動投稿を止める（ALT 無しで出る芽を摘む）

```
  いま: status=pending auto_publish=false x_tweet_id=null
```

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 文面を origin/main から取り、ロックのハッシュと照合する

```
  [1/2] ロック 一致 ／ 重み 274 / 280
  [2/2] ロック 一致 ／ 重み 212 / 280
  ALT: 1枚目 なし ／ 2枚目 393字 ／ 3枚目 なし ／ 4枚目 なし
```

## 2. ALT は付けない（利用者の指示）。post-via-playwright.js は触らない

## 3. 画像 4 枚を origin/main から取り出す

```
  取得  1-calendar.jpg   178012 bytes
  取得  1b-spots.jpg     513991 bytes
  取得  2-takao.jpg      150054 bytes
  取得  4-nikko.jpg      304055 bytes
  対象 4 枚 / 取れた 4 枚
```

## 4. キューに積む（x264 のエントリが残っていれば消してから積み直す）

```json
{"removed_old":1}
{"ok":true,"id":"blog-promo-20261011-momiji"}
```

## 5. Chrome は健全か

```
{"ok":true,"healthy":true,"round_trip_ms":7154,"product":"Chrome/140.0.7339.207","tabs":27}
(rc=0)
```

## 6. 出す（ALT は渡さない）

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
[step] connect t=0ms
[step] navigate-target t=6046ms
[step] find-reply-textarea t=12440ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=12626ms
[step] type-text t=12626ms
[x154] like 付いた
[step] arm-response-listener t=17610ms
[step] submit t=17611ms
[step] wait-response-or-confirm t=17703ms
[step] wait-textarea-clear t=18127ms
{"ok":true,"tweet_id":"2109272420473585757","url":"https://x.com/heng_ji31590/status/2109272420473585757","thread_count":2,"thread_results":[{"index":0,"role":"hook","ok":true,"tweet_id":"2109272420473585757","url":"https://x.com/heng_ji31590/status/2109272420473585757","image_attached":true,"captured_via":"graphql_response"},{"index":1,"role":"link","ok":true,"reply_tweet_id":"2109272532880957630","url":"https://x.com/heng_ji31590/status/2109272532880957630","captured_via":"graphql_response"}],"captured_via":"graphql_response"}
(rc=0)
```

## 7. 出たか。出たならキューに書き戻す

```
  [1/2] tweet_id = 2109272420473585757
  [2/2] tweet_id = 2109272532880957630
  キューを posted に書き戻した
```

## 8. 実物を読む（プロフィール → permalink。画像の枚数と alt）

### [1/2] https://x.com/heng_ji31590/status/2109272420473585757  画像 4 枚

- 1 枚目の alt: 画像
- 2 枚目の alt: 画像
- 3 枚目の alt: 画像
- 4 枚目の alt: 画像

### [2/2] https://x.com/heng_ji31590/status/2109272532880957630

```
「今年の紅葉、東京はいつ？」で調べても、名所ごとの見頃はばらばらのページに出てくるだけ。

だからアタシが関東・甲信の46か所を、見頃が早い順に1枚に並べたわよ。東京は11月29日ごろで平年並み。
```

**判定: [1/2] 在る（画像 4 枚） ／ 2 枚目の ALT（今回は付けない） なし ／ [2/2] 在る**

画面: x268-thread.png

**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
