# フォロー前に眺める・ときどきいいね（2026-11-15 21:35:44 JST・$0）

## ① follow-handle.js
```
入れた
node --check 通った（295 行）
263:    /* x502（2026-11-15）: 人の見方に寄せる。押す直前に眺める・スクロール・4 回に 1 回�
273:          if (await _lk.count()) { await _lk.first().scrollIntoViewIfNeeded(); await page.waitForTimeout(_rnd(700, 1
274:        } else console.error("[x502] いいねは間隔待ちで見送り: " + _pl.reason);
```

## ② 呼び出し側の打ち切りを 240 秒に
```
competitor-follower-follow.js: 1 か所
151:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${h}`, { encoding: "utf8", timeout: 240000, maxBuffer: 2*1024*1024 });
hashtag-follow.js: 1 か所
146:      const out = execSync(`/usr/local/bin/node ${FOLLOW_HANDLE} ${p.author}`, { encoding: "utf8", timeout: 240000, maxBuffer: 2 * 1024 
incoming-reply-watcher.js: 1 か所
213:          const followOut = execSync(`/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/follow-handle.js ${r.author} 2>&1`, { en
```

**LLM 不使用（$0）。**
