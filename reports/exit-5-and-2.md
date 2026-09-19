# 終了コード 5 と 2 の意味を確定する

**このレポートが作られた時刻: 2026-09-20 02:38:55 JST**

> x87 でログは見えた。**意味が確定していない。**
> comment-warmup は**投稿が出ているのに 5 で終わっている**ので、
> 5 は異常ではなく「候補なし」かもしれない。**ソースで確かめる。**

**測るだけ。直さない。**

## 1. comment-warmup の `exit 5` はどこで打たれるか

```
  --- plist が実行しているもの ---
    Array {
        /bin/bash
        /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
    }

  --- scripts/ の中で 5 を返している箇所 ---
    /Users/ny/.openclaw/workspace/scripts/gen-card-design-v2.js:289:    if (!fileChooser) { log("ERR: no filechooser event"); await page.screenshot({ path: `${DEBUG_PREFIX}-no-fc.png`, full
    /Users/ny/.openclaw/workspace/scripts/gen-card-design-v2.js:300:    if (attached === 0) { log("ERR: attachment not visible after 4s"); await page.screenshot({ path: `${DEBUG_PREFIX}-no-
    /Users/ny/.openclaw/workspace/scripts/auto-reply.js:176:    process.exit(5);

  --- 「no candidates」を出している箇所（その直後が 5 かを見る） ---
    /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh.new:40:  log "no candidates"
    /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh.pre-tonegate.20260828-155126:49:  log "no candidates"
    /Users/ny/.openclaw/workspace/scripts/follow-up-reply.js:47:    log("no candidates in 28-35min window");
    /Users/ny/.openclaw/workspace/scripts/qt-orchestrator.sh:111:  log "no candidates"
    /Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh.pre-ngfilter.20260827-133807:47:  log "no candidates"
    /Users/ny/.openclaw/workspace/scripts/trend-orchestrator.sh:46:  log "no candidates, exit"

  --- その前後 6 行 ---
    ══ comment-orchestrator.sh.new
      38-N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).length)})")
      39-if [ "$N" = "0" ]; then
      40:  log "no candidates"
      41-  exit 0
      42-fi
      43-
      44-# Pick first candidate whose handle passes cooldown
      45-PICK=$(echo "$CANDIDATES" | /usr/local/bin/node -e "
      46-const cs = require('child_process');
```

**5 が「候補なし」なら、直すものではない。** その場合は
「候補が出ない」ほうが本体の問題であり、終了コードは症状ではない。

## 2. 直近の run で**実際に出たか**（一次情報＝`x_tweet_id`）

```
  **/Users/ny/.openclaw/workspace/data/comment-queue.json が無い。** data/ の候補:
    comment-state.json
    comment-templates.json
    comment-templates.json.bak.20260513-100323
    comment-templates.json.bak.20260515-watashi-migration
    comment-templates.json.pre034.20260827-154041
    post_queue.json
    post_queue.json.bak-20260915-004806
    post_queue.json.bak-20260915-005730
```

**`x_tweet_id` と投稿 URL だけが一次情報**（最上位ルール 11）。
ログの行数や `posted_today` はここに含めない。

## 3. pipeline-heartbeat は**どの check が CRIT なのか**

```
  --- 最後の判定 JSON を 1 本 取り出して、CRIT / WARN だけ並べる ---
  overall = CRIT
       OK    login                    logged_in
       OK    chrome_cdp               alive
       OK    comment_posts_24h        4 (target ≥5)
    ** WARN  trend_posts_24h          0 (target ≥1)
    ** INFO  thread_posts_24h         0
       OK    comment_warmup_fire      fire in 24h
    ** CRIT  grok_trending_fire       no fire >24h  （自動復旧できる）
       OK    hashtag_follow_fire      fire in 24h
       OK    badge_followback_fire    fire in 24h
    ** WARN  unfollow_cleanup_morning_fire no fire >24h  （自動復旧できる）
    ** INFO  cost_24h_usd             $0.021

  --- 直近 12 行 ---
    [heartbeat] healed 1 issues, waiting 45s for effect...
    [heartbeat] digest: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789761908.740379","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789761908.740379","bot_id":"B0B2JT
    [heartbeat] actionable-alert: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789761909.113789","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789761909.113789","bot_id":"B
    {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK","detail":"logged_in","healable":false},{"name":"chrome_cdp","level":"OK","detail":"alive","healable":false}
    [heartbeat] healed 1 issues, waiting 45s for effect...
    [heartbeat] digest: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789772463.197839","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789772463.197839","bot_id":"B0B2JT
    [heartbeat] actionable-alert: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789772463.657599","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789772463.657599","bot_id":"B
    {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK","detail":"logged_in","healable":false},{"name":"chrome_cdp","level":"OK","detail":"alive","healable":false}
    [heartbeat] healed 1 issues, waiting 45s for effect...
    [heartbeat] digest: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789834827.353679","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789834827.353679","bot_id":"B0B2JT
    [heartbeat] actionable-alert: {"ok":true,"channel":"C0A5FKU7T5M","ts":"1789834827.732989","message":{"user":"U0B1M7RT9BP","type":"message","ts":"1789834827.732989","bot_id":"B
    {"ok":true,"overall":"CRIT","results":[{"name":"login","level":"OK","detail":"logged_in","healable":false},{"name":"chrome_cdp","level":"OK","detail":"alive","healable":false}

  --- exit 2 を打っている箇所 ---
```

**`overall=CRIT` で 2 を返しているだけなら、2 自体は正常な報告。**
問題は**どの check が CRIT のままか**で、そこは上の一覧に出る。

## 4. 費用

**ソースとログとキューを読むだけ。LLM を呼ばない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44
（`MAX_PICKS` は 4 のまま）。フォロー・アンフォロー系は $0（DOM 操作のみ）。
