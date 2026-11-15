# tab-guard: タブの数では止めない（2026-11-07 15:07:28 JST・$0）

## ① tab-guard.js
```
置き換えた（2 か所）
構文 OK・入れ替えた（退避 tab-guard.js.bak-x433）
--- 残っている haltAutomation の呼び出し（A のプロセス消滅だけのはず）
70:function haltAutomation(reason) {
118:    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
```

## ③ 常駐している tab-guard を立ち上げ直す
```
kickstart rc=0
	state = running 	runs = 27 	pid = 24637 
[2026-11-07T05:32:53.486Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-07T06:07:28.996Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

**LLM を呼ばない（$0／回・$0／日・$0／月）。投稿していない。ジョブは外していない。**
