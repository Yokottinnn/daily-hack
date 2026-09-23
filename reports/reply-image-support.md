# `thread_chain` の reply に画像を付けられるか（2026-09-23 19:35 JST・$0）

**このレポートが作られた時刻: 2026-09-23 19:35:45 JST**

> **読むだけ。** 投稿していないし、キューにも積んでいない。

## 0. ファイルが在るか

```
  在る  post-via-playwright.js             11446 bytes
  在る  run-publish.sh                     8770 bytes
```

## 1. `image_path` をどこで読んでいるか

**`images` ではなく `image_path`**（契約書 §3）。行番号つきで全部 出す。

```
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:30:  const imagePathArg = process.argv[3] || null;
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:31:  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:32:  const imagePath = imagePaths[0] || null;  // backward compat
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:34:  const isCharOnly = imagePaths.some(p => p.includes("/character-library/"));
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:35:  if (isCharOnly) { console.warn("[post-via-playwright] CHAR_ONLY image refused:", imagePaths.find(p => p.includes("/character-library/"))); }
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:36:  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js:79:      const want = imagePaths.length;
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:7:#   - thread_chain[]: [{text, role: hook|link|body|cta, image_path?, url?}]
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:20:  image_path: e.image_path || null,
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:63:  process.stdout.write(o.image_path || '');
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:96:    const imagePath = item.image_path || null;
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:102:      const imagePathFirst = imagePath ? imagePath.split(',')[0].trim() : null;
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:103:      const cmd = imagePathFirst && fs.existsSync(imagePathFirst)
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:104:        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:157:IMAGE_PATH=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:160:  process.stdout.write(o.image_path || '');
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:171:if [ -n "$IMAGE_PATH" ] && [ -f "$IMAGE_PATH" ]; then
/Users/ny/.openclaw/workspace/scripts/run-publish.sh:172:  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
```

## 2. reply を出している箇所の前後

**1 本目と 2 本目で、画像を付ける処理が分かれているかを見る。**
分かれていて reply 側に無ければ、**[2/2] に画像は付かない。**

```
```

## 3. `run-publish.sh` が chain の各要素をどう渡しているか

```
1-#!/bin/bash
2:# run-publish.sh (v3.2 2026-05-15: thread_chain サポート)
3-# 既存機能: text + image + thread_url_text の自動 reply
4:# 新規: kind=thread / thread_chain[] → main + 各 reply を順次投稿
5-#
6-# Schema:
7:#   - thread_chain[]: [{text, role: hook|link|body|cta, image_path?, url?}]
8-#   - 1個目 = main post (post-via-playwright)
9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
10-ENTRY_ID="${1:-day2-1}"
11-/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}'; exit 1; }
12-cd /Users/ny/.openclaw/workspace
13-
14-ENTRY_JSON=$(/usr/local/bin/node -e "
15-const q = require('./data/post_queue.json');
16-const e = q.queue.find(x => x.id === '$ENTRY_ID');
17-if (!e) { process.exit(1); }
18-process.stdout.write(JSON.stringify({
19-  text: e.text,
20-  image_path: e.image_path || null,
21-  thread_url_text: e.thread_url_text || null,
22:  thread_chain: e.thread_chain || null,
23-  kind: e.kind || null,
24-  target_url: e.target_url || null,
25-}));
26-")
27-if [ -z "$ENTRY_JSON" ]; then
28-  echo '{"ok":false,"step":"read-entry","error":"entry not found"}'
29-  exit 1
30-fi
31-
32-HAS_THREAD=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
33-let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
34-  const o = JSON.parse(d);
35:  process.stdout.write((o.thread_chain && Array.isArray(o.thread_chain) && o.thread_chain.length > 1) ? 'yes' : 'no');
36-});
37-")
38-
39-# 🆕 2026-06-07: trend_qt は post-quote-tweet.js で実 QT 化 (旧: 平 post 扱いで意味なかった)
40-KIND=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
41-let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
42-  const o = JSON.parse(d);
43-  process.stdout.write(o.kind || '');
44-});
45-")
46-TARGET_URL=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
47-let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
48-  const o = JSON.parse(d);
49-  process.stdout.write(o.target_url || '');
--
75-  exit 0
76-fi
77-
78:# === Branch 1: thread_chain mode ===
79-if [ "$HAS_THREAD" = "yes" ]; then
80:  echo "[run-publish] thread_chain mode" >&2
81-  ENTRY_JSON="$ENTRY_JSON" /usr/local/bin/node -e "
82-const { execSync } = require('child_process');
83-const fs = require('fs');
84-
85-const ENTRY_JSON = process.env.ENTRY_JSON;
86-const o = JSON.parse(ENTRY_JSON);
87:const chain = o.thread_chain;
88-
89-const results = [];
90-let prevUrl = null;
91-
92-(async () => {
93:  for (let i = 0; i < chain.length; i++) {
94:    const item = chain[i];
```

## 4. ファイル入力（画像添付）の実装

**X はファイル input に `setInputFiles` で渡す。** その呼び出しが
1 本目のときだけ走る作りなら、reply には付かない。

```
62-    await page.keyboard.insertText(text);
63-    await page.waitForTimeout(800);
64-
65-    let imageAttached = false;
66-    if (hasImage) {
67-      step = "attach-image";
68:      let fileInput = await page.$('input[type="file"][data-testid="fileInput"]');
69:      if (!fileInput) fileInput = await page.$('input[type="file"]');
70-      if (!fileInput) throw new Error("file input not found on compose page");
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
72-      step = "wait-image-upload";
73-
74-      // 2026-08-09 修正: 旧実装は role="progressbar" が 0 になるのを完了条件にしていたが、
75-      // これは X の「文字数カウンターの円形インジケータ」で常時 3 個存在する。
76-      // よって条件は永遠に成立せず、.catch() で握り潰されたままアップロード途中で送信され、
77-      // 画像が 1 枚も付かないまま投稿されていた (画像つき投稿がほぼ毎回これで失敗)。
78-      // 正しい完了サインは「添付プレビューの画像枚数」と「各画像の削除ボタン数」。
79-      const want = imagePaths.length;
80-      let attachedCount = 0;
81-      for (let i = 0; i < 45; i++) {
```

---

## 読み方

- §2 / §4 で、**reply を出す経路から `setInputFiles` に到達できるか**を見る
- 到達できないなら、**[2/2] に画像は付けられない。** 形を決め直す必要がある
- **`rc=0` は証拠にならない**（最上位ルール 13）。ソースの行で判断する

**LLM を呼んでいない（$0／回・$0／日・$0／月）。**
