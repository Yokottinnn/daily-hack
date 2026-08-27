# NG 判定の組み込み（2026-08-27 22:38 JST）

## 1. 部品を配る
- reply-ng-rules.json: 配置（3246 B）
- reply-ng-check.cjs: 配置（3006 B）
- ng-filter-candidates.cjs: 配置（3177 B）

## 2. フィルタ単体の動作確認（組み込む前に）
```
  ng-filter: 4 件中 2 件を弾いた (hard=1 link=1)
    弾いた理由 hard: パパ活
    弾いた理由 link: lin.ee
[eval]:1
tryconsole.log(JSON.parse(require('fs').readFileSync('/tmp/ngout.13286'catch(e){console.log('読めない')}
                                                     ^^^^^^^^^^^^^^^^^^
Expected ',', got 'catch'

SyntaxError: missing ) after argument list
    at makeContextifyScript (node:internal/vm:194:14)
    at compileScript (node:internal/process/execution:420:10)
    at evalTypeScript (node:internal/process/execution:292:22)
    at node:internal/main/eval_string:71:3

Node.js v26.0.0
[eval]:1
try'utf8')).length+' 件')catch(e){console.log('読めない')}
   ^^^^^^
Expected '{', got 'string literal'

SyntaxError: Unexpected string
    at makeContextifyScript (node:internal/vm:194:14)
    at compileScript (node:internal/process/execution:420:10)
    at evalTypeScript (node:internal/process/execution:292:22)
    at node:internal/main/eval_string:71:3

Node.js v26.0.0
残った候補:  残った候補: 
```

## 3. comment-orchestrator.sh への挿入

- 退避: comment-orchestrator.sh.pre-ngfilter.20260827-133807
- **組み込んだ**（bash -n 通過）

挿入箇所の前後:
```bash
43-  catch(e){console.log('[]');}
44-})")
45-# 2026-08-27: 売春系などへの返信を弾く。判定できないときは素通しする（ジョブを落とさない）
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
47-N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.p
48-if [ "$N" = "0" ]; then
49-  log "no candidates"
```

## 4. 組み込み後の確認

- comment-orchestrator.sh の構文: **正常**
- NG 判定の組み込み: **済み**
- comment-warmup の稼働: 稼働

## 5. 次の発火で確認すること

comment-warmup が次に発火したとき、ログに次の行が出れば効いている。

```
  ng-filter: N 件すべて通過
  ng-filter: N 件中 M 件を弾いた (hard=1 link=1)
```

直近のログ末尾:
    [2026-08-27T22:03:39] enqueue: {"ok":true,"id":"comment-20260827-2203-1"}
    {"ok":true,"entry_id":"comment-20260827-2203-1","x_tweet_id":"2092961317967855923","url":"https://x.<MASKED>","slack_report_ts":"silenced"}
    [2026-08-27T22:04:10]   follow @totono_ieie: followed
    [2026-08-27T22:04:10]   recorded in reply-followers.json (count now 7/30)
    [2026-08-27T22:04:10] === orchestrator done: 2 drafts, 7 reply-connected follows today ===
