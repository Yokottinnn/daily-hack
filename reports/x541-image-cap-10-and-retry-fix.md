# 画像の上限を 10 枚に・出し直しの不具合を直す（2026-11-22 13:16:55 JST・$0）

## ① 画像の上限
```
書き換えた（元は .bak-x541）
37:  if (imagePaths.length > 10) { console.error("[post-via-playwright] max 10 images (2026-11-22 x541: confirmed 10 in the composer), got " + imagePaths.length
```

## ② 出し直しの不具合（明日の湾岸のイルミの予約）
```
直した（元は .bak-x541）
9:TID="$("/opt/homebrew/bin/node" -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const r=Array.isArray(q)?q:(q.queue||q.items||q.posts||[]);const e=r.find(x=>x&&x.id===proc
10:if [ -z "$TID" ] && ! printf "%s" "$OUTP" | grep -q "\"role\":\"hook\",\"ok\":true"; then
```

**投稿はしていない。LLM 不使用（$0）。**
