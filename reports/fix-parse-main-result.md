# 出せたのに失敗と返す穴を直す（2026-10-24 21:56:21 JST・$0）

## 1. 置き換え
```
  置き換えた（raw 1 / thread 1）
  bash -n: OK
188:THREAD_RES=""
194:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")
203:  const argOf = (k) => { const h = process.argv.find(x => x.startsWith(k + '=')); return h ? h.slice(k.length + 1) : ''; };
204:  const raw = process.env.MAIN_RES || argOf('MAIN_RES');
211:const threadStr = process.env.THREAD_RES || (process.argv.find(x => x.startsWith('THREAD_RES=')) || '').slice(11);
217:" MAIN_RES="$MAIN_RES" THREAD_RES="$THREAD_RES"
```

## 2. 同じ書き方の小さな再現で確かめる（投稿しない）
```
  {"ok":true,"tweet_id":"123","url":"u"}
  → **直った（ok:true と tweet_id が返る）**
```

**投稿していない。LLM を呼んでいない（$0／回・$0／日・$0／月）。**
