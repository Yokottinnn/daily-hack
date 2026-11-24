# スレッドの 2 投稿目の直し（2026-11-24 21:58 JST・$0）
```
控え: post-comment.js.bak-x551 19375 bytes
置き換える所: いいね 1 か所 ／ クリック 1 か所
OK 書いた
node --check: 通った
102:        const _x154art = /\/heng_ji31590\/status\//.test(String(targetUrl || "")) ? null : await page.$('article[data-testid="tweet"]'); // x551: 自分の�
135:    // x551: いいねなどで描き直されると先に掴んだ欄が外れる（2026-11-22 CAMP で 2 回）。クリックの直前に取り直す
136:    const _x551ta = (await page.$('div[data-testid^="tweetTextarea_"][contenteditable="true"]')) || ta;
137:    await _x551ta.click();
```

次に 2 投稿のスレッドが出るのは 11/25 11:56（クルーズ船）。そこで 2 投稿目が出るかを見る。**LLM 不使用（$0）。**
