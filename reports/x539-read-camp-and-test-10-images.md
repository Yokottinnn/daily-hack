# CAMPこよみワークショップが出たか（2026-11-22 12:44:17 JST・読むだけ・$0）

## キュー
```
status=awaiting_approval x_tweet_id=なし posted_at=なし scheduled_at=2026-11-22T03:13:00.000Z
last_result={"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"MuOAnDPkurrjga7ntYTjgafmnIjjgpLlj5fjgZHmjIHjgaPjgabjgIHmnIDlvozjgavnmbrooajkvJrjgb7jgafjgYLjgovjga7jgILmjIHjgaHnianjgajooYzjgY3mlrnjga/jgZPjgZPjgavjgb7jgajjgoHjgZ/jgo/jgIIKaHR0cHM6Ly9kYWlseS1oYWNrLmZpZWxkYmVzaWRlLmNvbS9wb3N0cy9zY3NrLWNhbXA"}
  [1] x_tweet_id=なし
  [2] x_tweet_id=なし
```

## ジョブ
```
載っていない（走り終えて自分を外したか、最初から載っていない）
-rw-r--r--  1 ny  staff  860 Nov 22 00:32 /Users/ny/Library/LaunchAgents/com.dailyhack.publish-camp-koyomi-oneshot.plist
```

## ログ（末尾 40 行）
```
--- publish-camp-koyomi-oneshot.log
[2026-11-22 12:13:05] start
[run-publish] thread_chain mode
[post-via-playwright] attached 2/2 image(s)
[post-via-playwright] alt set for image 1 (52 chars)
[post-via-playwright] alt set for image 2 (146 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=2651ms
[step] find-reply-textarea t=8918ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=8961ms
[step] type-text t=8961ms
[x154] like 付いた
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"MuOAnDPkurrjga7ntYTjgafmnIjjgpLlj5fjgZHmjIHjgaPjgabjgIHmnIDlvozjgavnmbrooajkvJrjgb7jgafjgYLjgovjga7jgILmjIHjgaHnianjgajooYzjgY3mlrnjga/jgZPjgZPjgavjgb7jgajjgoHjgZ/jgo/jgIIKaHR0cHM6Ly9kYWls
[wb] t1=null t2=null ok=false
[2026-11-22 12:13:58] 出ていない。60 秒後に 1 回だけ出し直す（x521 と同じ）
[run-publish] thread_chain mode
[post-via-playwright] attached 2/2 image(s)
[post-via-playwright] alt set for image 1 (52 chars)
[post-via-playwright] alt set for image 2 (146 chars)
[x-action-pacer] tweet: 空いた
[step] connect t=0ms
[step] navigate-target t=2338ms
[step] find-reply-textarea t=8587ms
[textarea] found via primary sel: div[data-testid^="tweetTextarea_"][contenteditable="true"] t=11526ms
[step] type-text t=11527ms
[x154] like 付いた
{"ok":false,"step":"thread-reply-1-exec","error":"Command failed: /usr/local/bin/node scripts/post-comment.js \"MuOAnDPkurrjga7ntYTjgafmnIjjgpLlj5fjgZHmjIHjgaPjgabjgIHmnIDlvozjgavnmbrooajkvJrjgb7jgafjgYLjgovjga7jgILmjIHjgaHnianjgajooYzjgY3mlrnjga/jgZPjgZPjgavjgb7jgajjgoHjgZ/jgo/jgIIKaHR0cHM6Ly9kYWls
[wb] t1=null t2=null ok=false
[2026-11-22 12:15:51] done rc=0
--- publish-camp-koyomi-oneshot-out.log
--- publish-camp-koyomi-oneshot-err.log
```

## ほかの予約ジョブ
```
ai.openclaw.publish-hanabi-oneshot.plist
ai.openclaw.publish-hanabi-oneshot.plist.bak-x352
ai.openclaw.publish-payid-oneshot.plist
ai.openclaw.publish-payid-oneshot.plist.bak-x352
ai.openclaw.publish-points-oneshot.plist
com.dailyhack.publish-bf-matome-oneshot.plist
com.dailyhack.publish-bf-pay-oneshot.plist
com.dailyhack.publish-camp-koyomi-oneshot.plist
com.dailyhack.publish-furusato-portal-comparison-2026-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist
com.dailyhack.publish-hanabi-oneshot.plist.bak-x352
com.dailyhack.publish-lalaport-toyosu-black-friday-2026-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist
com.dailyhack.publish-prime-oneshot.plist.bak-x352
com.dailyhack.publish-rainbow-ride-oneshot.plist
com.dailyhack.publish-wangan-illumination-oneshot.plist
com.dailyhack.publish-wangan-map-oneshot.plist
```

## ① 投稿の仕組みの 4 枚の扱い
```
--- post-via-playwright.js
31:  const imagePaths = (imagePathArg && imagePathArg !== "null") ? imagePathArg.split(",").map(p => p.trim()).filter(Boolean) : [];
36:  const hasImage = imagePaths.length > 0 && !isCharOnly && imagePaths.every(p => fs.existsSync(p));
37:  if (imagePaths.length > 4) { console.error("[post-via-playwright] X allows max 4 images, got " + imagePaths.length); process.exit(1); }
71:      await fileInput.setInputFiles(imagePaths.length > 1 ? imagePaths : imagePaths[0]);
103:      // 2026-10-11 x264: 画像の説明（ALT）。ALT_TEXTS_FILE（JSON 配列）があれば、i 枚目に alts[i] を入れる（空ならその画像は飛ばす）。
104:      // CC BY / CC BY-SA の撮影者名を ALT に書く運用（CLAUDE.md 最上位ルール 8）。**入れられなければ投稿しない**（throw → 投稿ボタンを押さない）。
105:      // 画面の作りは x263 で実物を読んだ: 添付ごとの [data-testid="altTextWrapper"] → 編集画面の textarea → [data-testid="endEditingButton"]
106:      if (process.env.ALT_TEXTS_FILE) {
107:        step = "alt-text";
108:        const alts = JSON.parse(fs.readFileSync(process.env.ALT_TEXTS_FILE, "utf8"));
109:        for (let i = 0; i < alts.length; i++) {
110:          if (!alts[i]) continue;
111:          // 2026-10-11 x265: 複数枚を添付すると altTextWrapper は 1 個にまとまる（x264 で実測）。
114:          const wrappers = page.locator('[data-testid="attachments"] [data-testid="altTextWrapper"]');
116:          if (n === 0) throw new Error("altTextWrapper が無い");
141:          if (!(await box.count())) throw new Error("ALT の入力欄が見つからない（" + (i + 1) + " 枚目）");
142:          await box.fill(alts[i]);
145:          if (got.replace(/\s/g, "") !== String(alts[i]).replace(/\s/g, "")) throw new Error("ALT が入りきらない（" + (i + 1) + " 枚目） got_len=" + got.length + " want_len=" + alts[i].
147:          if (!(await save.count())) throw new Error("ALT の保存ボタンが無い");
150:          console.error("[post-via-playwright] alt set for image " + (i + 1) + " (" + got.length + " chars)");
--- run-publish.sh
35:  process.stdout.write((o.thread_chain && Array.isArray(o.thread_chain) && o.thread_chain.length > 1) ? 'yes' : 'no');
171:# 2026-10-23 x332: IMAGE_PATH はカンマ区切りで最大 4 枚。旧判定 [ -f "$IMAGE_PATH" ] は 2 枚以上で偽になり、黙って画像なしで出していた
172:IMG_STATE=$(IMAGE_PATH="$IMAGE_PATH" /usr/local/bin/node -e 'const fs=require("fs");const p=(process.env.IMAGE_PATH||"").split(",").map(s=>s.trim()).filter(Boolean);process.stdout.write(p.length==
207:  const jsonLine = lines.length > 0 ? lines[lines.length - 1] : raw;
```

画像を 10 枚 用意した

## ② 投稿画面に 10 枚入れる（投稿はしない）
```
入力欄: accept=image/jpeg,image/png,image/webp,image/gif,video/mp4,video/quicktime multiple=
入れた: 10 枚 ／ プレビュー: 10 ／ 添付欄: true ／ 出た文: なし
画面: x539/compose.png
下書きを捨てた（破棄）
```

**読むだけ。LLM 不使用（$0）。**
