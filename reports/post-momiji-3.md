# 紅葉 2026 の告知スレッドを投稿する（2026-10-11 22:07:34 JST・費用 $0）

> **[1/2] 画像 4 枚（2 枚目に ALT）・[2/2] 記事の紹介。** 文面は承認済みのものを 1 文字も変えていない（最上位ルール 18）。

## 00. 残っているエントリの自動投稿を止める（ALT 無しで出る芽を摘む）

```
  いま: status=pending auto_publish=true x_tweet_id=null
  → auto_publish を false にした
```

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. 文面を origin/main から取り、ロックのハッシュと照合する

```
  [1/2] ロック 一致 ／ 重み 274 / 280
  [2/2] ロック 一致 ／ 重み 212 / 280
  ALT: 1枚目 なし ／ 2枚目 393字 ／ 3枚目 なし ／ 4枚目 なし
```

## 2. post-via-playwright.js の ALT の作りを直す（化けた $eval を戻す）

```
  化けていた $eval を $$eval に戻した（退避 post-via-playwright.js.bak.20261011-220735）
  node --check: 通る
  化けた $eval / 正しい $$eval: 0 3
```

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
{"ok":true,"healthy":true,"round_trip_ms":4688,"product":"Chrome/140.0.7339.207","tabs":28}
(rc=0)
```

## 6. 出す（ALT_TEXTS_FILE を渡す）

```
[run-publish] thread_chain mode
[post-via-playwright] attached 4/4 image(s)
{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js \"5p2x5Lqs44Gu57SF6JGJ44CB6KaL44Gp44GT44KNMTDpgbjjgpLopovpoIPjga7poIbjgavkuKbjgbnjgZ/jgo/jgojwn42BCgrimqDvuI/opoHms6jmhI8K5Y675bm044Gu5oSf6Kaa44GnMTHmnIjjga7poK3jgavooYzjgY/jgajjgb7jgaDpnZLjgYTjga7jgIIKCuWbnuOCi+mghuOBr+OBk+OBhuOAggrjg7sxMOaciOS4rSDihpIg5pel5YWJIDEwLzIx44CcCuODuzEx5pyI5YmN5Y2KIOKGkiDmmK3lkozoqJjlv7XlhazlnJIK44O7MTHmnIjmnKvjgJwxMuaciOmgrSDihpIg6YO95YaF44Gu5bqt5ZyS44Go5aSW6IuRCgrlpJzjga/lha3nvqnlnJLvvIgxMS8yNeOAnDEyLzbvvInjgILliY3lo7Ljga8yMDDlhoblronjgYTjgYvjgonlhYjjgavosrfjgaPjgajjgY3jgarjgZXjgYTjgII=\" \"/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/1-calendar.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/1b-spots.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/2-takao.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/4-nikko.jpg\"\n[post-via-playwright] attached 4/4 image(s)\n","child_stdout":"on disabled role=\\\"button\\\" tabindex=\\\"-1\\\" type=\\\"button\\\" aria-label=\\\"次へ\\\" aria-disabled=\\\"true\\\" class=\\\"css-g5y9jx r-sdzlij r-1phboty r-rs99b7 r-lrvibr r-2yi16 r-1qi8awa r-o7ynqc r-6416eg r-icoktb r-1ny4l3l\\\">…</button>\\n  - attempting click action\\n    2 × waiting for element to be visible, enabled and stable\\n      - element is not enabled\\n    - retrying click action\\n    - waiting 20ms\\n    2 × waiting for element to be visible, enabled and stable\\n      - element is not enabled\\n    - retrying click action\\n      - waiting 100ms\\n    57 × waiting for element to be visible, enabled and stable\\n       - element is not enabled\\n     - retrying click action\\n       - waiting 500ms\\n\"}\n","child_stderr":"[post-via-playwright] attached 4/4 image(s)\n","thread_results":[]}
(rc=0)
```

## 7. 出たか。出たならキューに書き戻す

```
  ok:false。書き戻さない。 step=thread-main-exec error=Command failed: /usr/local/bin/node scripts/post-via-playwright.js "5p2x5Lqs44Gu57SF6JGJ44CB6KaL44Gp44GT44KNMTDpgbjjgpLopovpoIPjga7poIbjgavkuKbjgbnjgZ/jgo/jgojwn42BCgrimqDvuI/opoHms6jmhI8K5Y675bm044Gu5oSf6Kaa44GnMTHmnIjjga7poK3jgavooYzjgY/jgajjgb7jgaDpnZLjgYTjga7jgIIKCuWbnuOCi+mghuOBr+OBk+OBhuOAggrjg7sxMOaciOS4rSDihpIg5pel5YWJIDEwLzIx44CcCuODuzEx5pyI5YmN5Y2KIOKGkiDmmK3lkozoqJjlv7XlhazlnJIK44O7MTHmnIjmnKvjgJwxMuaciOmgrSDihpIg6YO95YaF44Gu5bqt5ZyS44Go5aSW6IuRCgrlpJzjga/lha3nvqnlnJLvvIgxMS8yNeOAnDEyLzbvvInjgILliY3lo7Ljga8yMDDlhoblronjgYTjgYvjgonlhYjjgavosrfjgaPjgajjgY3jgarjgZXjgYTjgII=" "/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/1-calendar.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/1b-spots.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/2-takao.jpg,/Users/ny/.openclaw/workspace/data/x-momiji-2026-kanto/4-nikko.jpg"
[post-via-playwright] attached 4/4 image(s)

```

## 8. 実物を読む（プロフィール → permalink。画像の枚数と alt）

**プロフィールに紅葉の投稿が見つからない**

画面: 

**一次情報は x_tweet_id と投稿 URL の実物だけ**（最上位ルール 11）。**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
