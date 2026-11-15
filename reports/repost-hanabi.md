# 画像の穴をふさいで花火の告知を出し直す（2026-10-23 08:28:41 JST・$0）

## 1. run-publish.sh の判定を直す
```
  置き換えた
  bash -n: OK
171:# 2026-10-23 x332: IMAGE_PATH はカンマ区切りで最大 4 枚。旧判定 [ -f "$IMAGE_PATH" ] は 2 枚以上で偽になり、黙って画像なしで出していた
172-IMG_STATE=$(IMAGE_PATH="$IMAGE_PATH" /usr/local/bin/node -e 'const fs=require("fs");const p=(process.env.IMAGE_PATH||"").split(",").map(s=>s.trim()).filter(Boolean);process.stdout.write(p.length===0?"none":(p.every(x
173-if [ "$IMG_STATE" = "missing" ]; then
174-  echo '{"ok":false,"step":"image-missing","error":"image_path is set but some files are missing - refusing to post without images"}'
175-  exit 1
176-fi
177-if [ "$IMG_STATE" = "ok" ]; then
178-  MAIN_RES=$(/usr/local/bin/node scripts/post-via-playwright.js "$TEXT_B64" "$IMAGE_PATH" 2>"$ERR_TMP")
```

## 2. 画像 4 枚と文面を origin/main から取る
```
  1-checklist.jpg    253701 bytes
  2-alcohol.jpg      170264 bytes
  3-roads.jpg        159620 bytes
  4-no-ticket.jpg    147682 bytes
  対象 4 枚 / 取れた 4 枚
  文面: rc=0 / 文字 1539（ロックと照合）
```

## 3. 積んで出す
```
  積んだ: blog-promo-20261023-tokyo-bay-hanabi-r2
[post-via-playwright] attached 4/4 image(s)
{"ok":false,"step":"parse-main-result","error":"main result not valid JSON","raw":""}
  (rc=0)
```

## 4. プロフィールと投稿のページで、出たか・画像が何枚かを数える
```
  {"hit":{"href":"/heng_ji31590/status/2113412348195283225","at":"2026-10-22T23:29:03.000Z","head":"あんたにだけ教えるわね。\n東京湾大華火祭"},"media":4}
  → 出た x_tweet_id=2113412348195283225 ／ 画像 4 枚
  URL: https://x.com/heng_ji31590/status/2113412348195283225
```

**再送していない（1 回だけ出した）。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
