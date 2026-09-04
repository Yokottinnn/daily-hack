# 新しい生成器に 5 件 書かせる（2026-09-04 21:30:06 JST）

> **投稿しない。enqueue しない。ジョブも戻さない。**
> ここで作った文はどこにも送られない。読むためだけに作る。

> 費用: 5 件 × 推定 $0.0019 = **約 $0.01**（1 回きり・承認済み）

## 1. 部品を置く（**origin/main から。作業ツリーからは取らない**）

- `lib/asuka-reply.cjs`: 6589 B
- `lib/reply-relevance-check.cjs`: 9209 B
- `lib/reply-tone-check.cjs`: 3220 B
- `data/reply-relevance-rules.json`: 4191 B
- `data/reply-style-prompt.json`: 3478 B
- `data/reply-tone-rules.json`: 3572 B
- 構文: **OK**

## 2. 候補を取る

### orchestrator が候補をどう取っているか
```bash
38:CANDIDATES=$(echo "$DETECT_OUT" | /usr/local/bin/node -e "
42:  try{const o=JSON.parse(line);console.log(JSON.stringify(o.candidates||[]));}
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
47:N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).length)})")
49:  log "no candidates"
54:echo "$CANDIDATES" | /usr/local/bin/node -e "
73:log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
75:  log "all candidates in cooldown"
```

- **候補ファイルが見つからない。** 過去に返信した相手の投稿も記録されていないため、
  **実データが用意できない。** ここで中止する。

> 作り話の投稿に返信させても、噛み合っているかの検証にならない。
> 候補の取り方が分かるまで、生成は走らせない（費用も発生させない）。

### workspace/data にあるそれらしいファイル
```
trend-cache.json
comment-templates.json
comment-templates.json.pre034.20260827-154041
follower-target-config.json
follower-target-config.json.bak
quick-reply-targets.json
grok-trending-state.json
comment-state.json
comment-templates.json.bak.20260515-watashi-migration
comment-templates.json.bak.20260513-100323
```
