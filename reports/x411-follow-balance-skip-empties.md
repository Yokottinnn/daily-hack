# 比率の調整：空振りする相手を枠から外す（2026-11-03 21:29 JST・$0）
```
置き換え: cuts.length < quota 1 箇所 / cuts.length >= quota 2 箇所
差し込んだ
入れた・構文 OK
279:  // x411: ページが空で押せなかった相手を、7 日以内に 2 回なら今回は見ない（枠を空振りで使わない）
280:  { let n = 0; try { const j = JSON.parse(fs.readFileSync(require("path").join(process.env.HOME, ".openclaw/workspace/data/follow-balance-empty.js
452:    if (cuts.length >= quota * 2) break;
462:  if (cuts.length < quota * 2) {
468:      if (cuts.length >= quota * 2 || reads >= MAX_READS) break;
505:    if (done >= quota) { log("外れた数が上限 " + quota + " 件に届いた。残りの候補は次回（x411）"); break; }
569:          if (why && why.empty) { try { let j = {}; try { j = JSON.parse(fs.readFileSync(require("path").join(process.env.HOME, ".openclaw/workspa
--- 走っていなければ、いま 1 回走らせる
いまの状態: not running
kickstart rc=0
	state = running 	runs = 6 	last exit code = 0 
```
**LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。結果は次のタスクで読む**
