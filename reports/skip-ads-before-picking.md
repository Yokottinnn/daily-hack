# 広告投稿を「選ぶ前」に弾く

**このレポートが作られた時刻: 2026-09-13 21:01:15 JST**

> 2026-09-13: picked 16 件 → **広告 4 件・話題外 3 件 が生成の直前に落ちた。**
> 落ちること自体は正しい（$0）が、**picked の枠を 7 つ 空振りさせている。**

**費用が増える変更（月 +$0.63）。承認を得てから実施している。**

## 0. 当てる前

```
  175 行 / 最終更新 2026-09-13 20:44
  isAdPost を含む箇所: 0
0

  --- 使う判定（既存の JSON。**中身は足さない**） ---
    hashtags      : 17 件
    domains       : 15 件
    campaign_words: 35 件
```

## 1. 当てる（**2 箇所 ＋ 件数の記録 1 箇所**）

```
  目印 ①（判定を置く場所）: 1 箇所
  目印 ②（飛ばす場所）    : 1 箇所
  目印 ③（件数を残す場所）: 1 箇所
  挿入する式の検査: OK（$ / バッククォート / 二重引用符 を含まない）
  当てた（検査待ち）

  --- 検査して置き換える ---
    **置き換えた**（退避 comment-orchestrator.sh.bak-20260913-210115）
```

## 2. 当てた後（**実物**）

```javascript
  59|   const picked = [];
  60|   const seen = new Set();
  61|   // 2026-09-13 x68: 広告投稿を選ぶ前に弾く（asuka-reply.cjs と同じ target_skip を使う）
  62|   var TS = {};
  63|   try { TS = (JSON.parse(fs.readFileSync('/Users/ny/.openclaw/workspace/data/reply-relevance-rules.json', 'utf8')).target_skip) || {}; } catch (e) { TS = {}; }
  64|   var adSkipped = 0;
  65|   var isAdPost = function (it) {
  66|     var t = [it.text, it.tweet_url, it.title, it.bio].filter(Boolean).join(' ');
  67|     var lists = [TS.hashtags || [], TS.domains || [], TS.campaign_words || []];
  68|     for (var li = 0; li < lists.length; li++) {
  69|       for (var i = 0; i < lists[li].length; i++) { if (t.indexOf(lists[li][i]) >= 0) return true; }
  70|     }
  71|     return false;
  72|   };
  73|   for (const item of items) {
  74|     if (picked.length >= $MAX_PICKS) break;
  75|     if (seen.has(item.author)) continue;
  76|     if (isAdPost(item)) { adSkipped++; continue; }
  77|     try {
  78|       const can = JSON.parse(cs.execSync('/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/comment-state.js can-comment ' + item.author).toString());
  79|       if (can.ok) { picked.push(item); seen.add(item.author); }
  80|     } catch (e) {}
  81|   }
```

```
  --- bash の構文検査（置き換えた後の実物） ---
    OK
```

## 3. 効いたかの確かめ方（**rc=0 は証拠にならない**）

次の周回のあと、**次の 2 つ**で見る。

| 見るもの | 効いていれば |
| --- | --- |
| `/tmp/orch-adskip.json` | `ad_skipped` に 1 以上 が入る |
| `comment-warmup.log` の日次 | **広告の列が 0 に近づき、enqueue が増える** |

```
  /tmp/orch-adskip.json: **まだ無い**（次の周回で作られる）
```

## 4. 費用（**増える**）

| | 1 回あたり | 1 日あたり | 1 か月あたり |
| --- | --- | --- | --- |
| いままで（生成 9 件/日・実績） | $0.003 | $0.027 | 約 $0.81 |
| **この変更の後**（生成 最大 16 件/日） | $0.003 | **$0.048** | **$1.44** |

**増加は月 +$0.63。** 単価は実測（2026-09-06・全文生成・Haiku 4.5）、
件数は 2026-09-13 のログ実測。
**16 件 は上限であって予想ではない。** 候補が足りなければ下回る。

このタスク自体（パッチを当てる処理）は **$0**。文字列の一致だけで LLM を呼ばない。
