# 1 投稿に画像を何枚付けられるか（2026-11-22 12:03:33 JST・投稿はしない・$0）

## ① 投稿の仕組みの 4 枚の扱い
```
--- post-via-playwright.js
31:  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
36:  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
--- run-publish.sh
35:  process.stdout.write((o.thread_chain && Array.isArray(o.thread_chain) && o.thread_chain.length > 1) ? 'yes' : 'no');
171:# 2026-10-23 x332: IMAGE_PATH はカンマ区切りで最大 4 枚。旧判定 [ -f "$IMAGE_PATH" ] は 2 枚以上で偽になり、黙って画像なしで出していた
172:IMG_STATE=$(IMAGE_PATH="$IMAGE_PATH" /usr/local/bin/node -e 'const fs=require("fs");const p=(process.env.IMAGE_PATH||"").split(",").map(s=>s.trim()).filter(Boolean);process.stdout.write(p.length==
207:  const jsonLine = lines.length > 0 ? lines[lines.length - 1] : raw;
```

画像を 6 枚 用意した

## ② 投稿画面に 6 枚入れる（投稿はしない）
```
入力欄: accept=image/jpeg,image/png,image/webp,image/gif,video/mp4,video/quicktime multiple=
入れた: 6 枚 ／ プレビュー: 6 ／ 添付欄: true ／ 出た文: なし
画面: x538/compose.png
下書きを捨てた（破棄）
```

**投稿のボタンは押していない。LLM 不使用（$0）。**
