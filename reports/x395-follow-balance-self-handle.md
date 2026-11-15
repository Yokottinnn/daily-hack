# 比率の調整：自分のハンドルが読めないときの代わり（2026-11-01 20:45 JST・$0）
```
差し込んだ
入れた・構文 OK
--- 直したところ
222:  // x395: 画面が描かれず自分のハンドルが読めないときは、決まっている自分のハンドルを使う（10/31 18:45 に本文 0 文字で止まった）
223:  if (!me) { me = process.env.SELF_HANDLE || "heng_ji31590"; log("自分のハンドルが画面から読めない → " + me + " を使う（x395）"); }
--- 次に動く時刻（plist の StartCalendarInterval）
[{"Hour":11,"Minute":45},{"Hour":18,"Minute":45},{"Hour":15,"Minute":15}]
	state = not running
	runs = 3
	last exit code = 0
```
**LLM を呼ばない（1 回 $0・1 日 $0・1 か月 $0）。このタスクは外していない・押していない。**
