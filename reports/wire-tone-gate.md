# 出口の検査を差し込む（2026-08-29 00:51 JST）

> ng-filter が入口なら、これが出口。**紹介コードはここで止まる。**

## 1. 部品を配る

- reply-tone-rules.json: 配置（3572 B）
- reply-tone-check.cjs: 配置（3220 B）
- tone-gate.cjs: 配置（4611 B）

配置先の関係: scripts/tone-gate.cjs → ../data/reply-tone-rules.json
  ルール: 有り

## 2. 単体で動くか（差し込む前に）

```
  tone-gate: **送らない** (referral=紹介コード)
    弾いた文: 紹介コード ZOAQ61 入力してで頑張りなさいよ💪
trend: 7 candidates
{"ok":false,"text":"紹介コード ZOAQ61 入力してで頑張りなさいよ💪","template_id":"T11","error":"tone-gate blocked: referra
--- 通るはずの文 ---
  tone-gate: 通過
{"ok":true,"text":"コツコツ積立買い😉 大事よね","template_id":"T30"}```

## 3. comment-orchestrator.sh への挿入

- 代入先の変数: `GEN_OUT`
- 退避: comment-orchestrator.sh.pre-tonegate.20260828-155126
- **組み込んだ**（bash -n 通過）

挿入箇所の前後:
```bash
110-  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
111-  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
112-  # 2026-08-28: 紹介コード・URL・見下しなどを送る前に弾く。判定できないときは素通しする
113:  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
114-  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.pa
115-  if [ "$GEN_OK" != "true" ]; then
116-    log "gen failed (#$((i+1))): $GEN_OUT"
```

## 4. 組み込み後の確認

- comment-orchestrator.sh の構文: **正常**
- 出口の検査: **組み込み済み**
- 入口の検査: **組み込み済み**
- comment-warmup の稼働: 稼働

## 5. 次の発火で確認すること

12:00 / 16:00 / 19:00 / 22:00 JST の発火で、ログに次のどれかが出れば効いている。

```
  tone-gate: 通過
  tone-gate: 送るが記録する (command=なさいよ)
  tone-gate: **送らない** (referral=紹介コード)
```

直近のログ末尾:
    {"ok":true,"entry_id":"comment-20260828-2203-0","x_tweet_id":"2093323602708107540","url":"https://x.<MASKED>","slack_report_ts":"silenced"}
    [2026-08-28T22:03:43]   follow @POIKATSU_OTAKE: filtered
    [2026-08-28T22:03:45] --- processing #2/2 for @muisan1 ---
    [2026-08-28T22:03:48]   → chosen template_id: T16c
    [2026-08-28T22:03:48] enqueue: {"ok":true,"id":"comment-20260828-2203-1"}
    {"ok":true,"entry_id":"comment-20260828-2203-1","x_tweet_id":"2093323736678375524","url":"https://x.<MASKED>","slack_report_ts":"silenced"}
    [2026-08-28T22:04:14]   follow @muisan1: filtered
    [2026-08-28T22:04:15] === orchestrator done: 2 drafts, 2 reply-connected follows today ===
