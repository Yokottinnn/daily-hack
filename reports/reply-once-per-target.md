# 同じ相手への返信を 1 日 1 回まで・相手を分散（2026-10-11 17:06:35 JST・$0）

## ① 判定の部品を置く

```
  置いた: reply-once-per-day.cjs 3341 B
  money_yossy の今日: {"ok":false,"count":2,"limit":1,"day":"2026-10-11","reason":"今日（2026-10-11 JST）はもう 2 回返している（上限 1）"}
```

## ② comment-orchestrator.sh の選ぶループを直す

```
  直した（退避 comment-orchestrator.sh.bak.20261011-170635）
  bash -n: 通る
```

直したあとの選ぶループ

```js
PICKS_FILE=/tmp/orch-picks.$$.json
echo "$CANDIDATES" | /usr/local/bin/node -e "
const cs = require('child_process');
const fs = require('fs');
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const items = JSON.parse(d);
  const picked = [];
  const seen = new Set();
  // 2026-09-13 x68: 広告投稿を選ぶ前に弾く（asuka-reply.cjs と同じ target_skip を使う）
  var TS = {};
  try { TS = (JSON.parse(fs.readFileSync('/Users/ny/.openclaw/workspace/data/reply-relevance-rules.json', 'utf8')).target_skip) || {}; } catch (e) { TS = {}; }
  var adSkipped = 0;
  var isAdPost = function (it) {
    var t = [it.text, it.tweet_url, it.title, it.bio].filter(Boolean).join(' ');
    var lists = [TS.hashtags || [], TS.domains || [], TS.campaign_words || []];
    for (var li = 0; li < lists.length; li++) {
      for (var i = 0; i < lists[li].length; i++) { if (t.indexOf(lists[li][i]) >= 0) return true; }
    }
    return false;
  };
  // 2026-10-11 x259: 直近 7 日に返した回数が少ない相手を先に選ぶ（同じ回数なら元の順）。返す相手を分散させる
  const ONCE = require('/Users/ny/.openclaw/workspace/scripts/reply-once-per-day.cjs');
  const recent = {};
  try {
    const q = JSON.parse(fs.readFileSync('/Users/ny/.openclaw/workspace/data/post_queue.json', 'utf8')).queue || [];
    const since = Date.now() - 7 * 864e5;
    for (const e of q) { const h = ONCE.handleOf(e); const t = Date.parse(e.posted_at || e.created_at || ''); if (h && t >= since) recent[h] = (recent[h] || 0) + 1; }
  } catch (e) {}
  const rc = (it) => recent[String(it.author || '').replace(/^@/, '').toLowerCase()] || 0;
  items.sort((a, b) => rc(a) - rc(b));
  for (const item of items) {
    if (picked.length >= $MAX_PICKS) break;
    if (seen.has(item.author)) continue;
    if (isAdPost(item)) { adSkipped++; continue; }
    try {
      const can = JSON.parse(cs.execSync('/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/comment-state.js can-comment ' + item.author).toString());
      // 2026-10-11 x259: 同じ相手への返信は 1 日（JST）1 回まで。ジョブをまたいでキューから数える
      const once = ONCE.check(item.author);
      if (can.ok && !once.ok) console.error('skip @' + item.author + ': ' + once.reason);
      if (can.ok && once.ok) { picked.push(item); seen.add(item.author); }
    } catch (e) {}
  }
  try { fs.writeFileSync('/tmp/orch-adskip.json', JSON.stringify({ at: new Date().toISOString(), ad_skipped: adSkipped, considered: items.length, picked: picked.length })); } catch (e) {}
  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
});
"
N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
```

## ③ 直した選ぶループを、偽の候補で走らせる

```
  選ばれた: 今日まだ返していない相手
  はじいた理由: skip @money_yossy: 今日（2026-10-11 JST）はもう 2 回返している（上限 1）
```

**money_yossy が選ばれず、もう一方だけ選ばれていれば効いている**（money_yossy は今日すでに返しているため）。

**LLM を呼んでいない。投稿していない（$0／回・$0／日・$0／月）。返信の件数（16 件/日）は変えていない。**
