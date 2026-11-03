# 未認証・反応なしの相互を外す（2026-11-03 17:58 JST・$0）
```
差し込んだ
入れた・構文 OK
462:    // x408: 記録で認証済みと分かっている相互（badge-followback）はプロフィールを開かない。未認証の相互に時
463:    const x408Ver = new Set(); try { const b = JSON.parse(fs.readFileSync(require("path").join(process.env.HOME, ".openclaw/workspace/data/badge-f
464:    var x408Skip = 0;
470:      if (x408Ver.has(String(h).toLowerCase())) { x408Skip++; continue; }   // x408
479:      // x408（2026-11-03 利用者「未認証の相互は、アンフォローしても影響なさそうなやつは厳選してアンフォ�
485:  if (typeof x408Skip !== "undefined") log("認証済みと記録で分かっていて開かなかった相互: " + x408Skip + " 件（x408）");
--- いま 1 回走らせる
もう走っている（重ねない）
	state = not running 	runs = 3 	last exit code = 0 		state = active 		state = active 
```
**LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。結果は次のタスクで読む**
