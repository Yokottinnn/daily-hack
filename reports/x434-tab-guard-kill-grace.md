# tab-guard: 立ち上げ直しの間も止めない（2026-11-07 15:26:08 JST・$0）

## ① ensure-chrome.sh
```
差し込んだ
構文 OK・入れ替えた（退避 ensure-chrome.sh.bak-x434）
167-  log "CDP hang confirmed (${CONFIRM_TRIES} consecutive failures) — 自動化専用 Chrome を再起動"
168:  # x434（2026-11-07）: 終了させる前にも印を書く。tab-guard はこの間のプロセス消滅で止めない
169-  date +%s > "$HOME/.openclaw/workspace/data/ensure-chrome-restart-at" 2>/dev/null || true
170-  kill_chrome
171-fi
```

## ② tab-guard.js
```
差し込んだ
構文 OK・入れ替えた（退避 tab-guard.js.bak-x434）
70:function haltAutomation(reason) {
118:    // x434（2026-11-07）: ensure-chrome が終了させて立ち上げ直している間（約 9 秒）は、プロセスが消えて見える。止めずに記録だけ
119:    { const _rs = restartAgeSec(); if (_rs !== null && _rs >= 0 && _rs < RESTART_GRACE_S) { log(`Chrome のプロセスが見えない。ensure-chrome が ${_rs} 秒前に立�
120:    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
```

## ④ 常駐している tab-guard を立ち上げ直す
```
kickstart rc=0
	state = running 	runs = 28 	pid = 27369 
[2026-11-07T06:07:28.996Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-07T06:26:08.948Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

**LLM を呼ばない（$0／回・$0／日・$0／月）。投稿していない。ジョブは外していない。**
