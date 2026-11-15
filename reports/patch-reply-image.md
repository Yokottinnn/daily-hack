# reply に画像を付けられるようにする（2026-09-23 21:06 JST・$0）

**このレポートが作られた時刻: 2026-09-23 21:06:40 JST**

> **投稿しない。** 2 ファイルを書き換えて、構文を確かめるだけ。

## 0. 対象が在るか

```
  post-comment.js           265 行
  run-publish.sh            210 行
```

## 1. バックアップ

```
  post-comment.js.bak-20260923-210640
  run-publish.sh.bak-20260923-210640
```

## 2. `post-comment.js` を書き換える

**`sed -i` は使わない**（macOS は `-i ''` が要る・最上位ルール 14）。node で書く。

```
  (1) 引数を 3 つにした
  (2) 添付の処理を打鍵の直後に入れた
  書き込んだ
```

## 3. `run-publish.sh` に第 3 引数を足す

**常に渡す。** 受け取る側が `"null"` と空を無視するので、分岐は要らない。

```
  122: const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\"\`;
  -> const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\" \"\${imagePath}\"\`;
  書き込んだ
```

## 4. 構文を確かめる（**落ちたら元に戻す**）

```
  post-comment.js  node --check OK
  run-publish.sh   bash -n OK
```

## 5. 入ったか（**当てた証拠を出す**）

```
  --- post-comment.js ---
20:  const [textArg, targetUrl, imageArg] = process.argv.slice(2);
107:    const imagePaths = (imageArg && imageArg !== "null")
108:      ? imageArg.split(",").map((q) => q.trim()).filter(Boolean) : [];
110:      step = "attach-image";
119:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
120:      // **付いたことを確かめてから送信する。** setInputFiles は投げるだけで待たない。
126:      if (!attached) { out({ ok: false, step, error: "attachment did not appear - 画像なしでは出さない" }); process.exit(1); }
  --- run-publish.sh ---
9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
122:      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\" \"\${imagePath}\"\`;
188:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
```

---

## これで何が変わるか

- `thread_chain[i].image_path`（i>=1）が**実際に効くようになる**
- **画像が付かなかったら `ok:false` で止まる。** 黙って画像なしで出ることはもう無い
- **今後のスレッド全部に効く。** この記事だけの話ではない

**まだ投稿していない。** 出すのは次のタスク。

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
