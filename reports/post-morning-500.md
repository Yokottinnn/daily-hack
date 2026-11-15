# 500円モーニングの告知を出す（2026-09-23 19:40 JST・費用 $0）

**このレポートが作られた時刻: 2026-09-23 19:40:57 JST**

> **画像は [2/2] に 1 枚。** これまでと形が違う（利用者が選んだ）。
> **文面は承認済みのものを 1 文字も変えていない**（最上位ルール 18）。

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

## 1. reply に画像が付く実装があるか（**無ければ積まない**）

`x133` で分かったこと。**reply は `post-comment.js` に渡される**
（`run-publish.sh:9` の "2個目以降 = reply chain (post-comment.js ...)"）。
`post-via-playwright.js` を見ても答えは出ない。**チェーンのループ本体を読む。**

```
  --- run-publish.sh の thread_chain ループ（88〜145 行） ---

const results = [];
let prevUrl = null;

(async () => {
  for (let i = 0; i < chain.length; i++) {
    const item = chain[i];
    const text = item.text;
    const imagePath = item.image_path || null;
    const textB64 = Buffer.from(text, 'utf8').toString('base64');

    if (i === 0) {
      // First = main post
      // 2026-05-21 multi-image: first path may be comma-separated; check existence of first file only, pass full string to script
      const imagePathFirst = imagePath ? imagePath.split(',')[0].trim() : null;
      const cmd = imagePathFirst && fs.existsSync(imagePathFirst)
        ? \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\" \"\${imagePath}\"\`
        : \`/usr/local/bin/node scripts/post-via-playwright.js \"\${textB64}\"\`;
      try {
        const out = execSync(cmd, { encoding: 'utf8' });
        const lines = out.trim().split('\n');
        const r = JSON.parse(lines[lines.length - 1]);
        results.push({ index: i, role: item.role || 'main', ...r });
        if (r.ok && r.url) prevUrl = r.url;
        else { console.log(JSON.stringify({ ok: false, step: 'thread-main', error: r.error || 'main post failed', thread_results: results })); return; }
      } catch (e) {
        console.log(JSON.stringify({ ok: false, step: 'thread-main-exec', error: e.message, thread_results: results }));
        return;
      }
    } else {
      // Reply to previous
      if (!prevUrl) { console.log(JSON.stringify({ ok: false, step: 'thread-reply', error: 'no prev url for reply ' + i, thread_results: results })); return; }
      // Brief delay for X to process previous
      await new Promise(r => setTimeout(r, 5000));
      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\"\`;
      try {
        const out = execSync(cmd, { encoding: 'utf8' });
        const lines = out.trim().split('\n');
        const r = JSON.parse(lines[lines.length - 1]);
        results.push({ index: i, role: item.role || 'reply', ...r });
        if (r.ok && r.url) prevUrl = r.url;
        else { console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i, error: r.error || 'reply ' + i + ' failed', thread_results: results })); return; }
      } catch (e) {
        console.log(JSON.stringify({ ok: false, step: 'thread-reply-' + i + '-exec', error: e.message, thread_results: results })); return;
      }
    }
  }
  // All succeeded
  const main = results[0];
  console.log(JSON.stringify({
    ok: true,
    tweet_id: main.tweet_id || (main.url || '').split('/status/')[1] || null,
    url: main.url,
    thread_count: results.length,
    thread_results: results,
    captured_via: main.captured_via || 'thread_main',
  }));
})();
```

**判定: reply を組み立てている行に画像が乗っているか。**

```
  --- post-comment を呼んでいる行 ---
9:#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
122:      const cmd = \`/usr/local/bin/node scripts/post-comment.js \"\${textB64}\" \"\${prevUrl}\"\`;
188:  THREAD_RES=$(/usr/local/bin/node scripts/post-comment.js "$THREAD_TEXT_B64" "$MAIN_URL" 2>"$ERR_TMP2")

  --- post-comment.js の argv と添付 ---
20:  const [textArg, targetUrl] = process.argv.slice(2);

  reply の呼び出しに画像が乗っている行: 0
  post-comment.js の setInputFiles  : 0
```

- **reply への添付が確認できない。積まないし、出さない。**
- **ここで止めるのは正しい。** 推測で積むと、エラーも出さずに画像なしで出る
- 上の出力を見て決め直すこと（画像を [1/2] に移すか、実装を直すか）
