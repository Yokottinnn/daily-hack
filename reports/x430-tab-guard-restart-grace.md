# tab-guard: 再起動の直後は止めない（2026-11-07 14:32:52 JST・$0）

## ① ensure-chrome.sh
```
差し込んだ
構文 OK・入れ替えた（退避 ensure-chrome.sh.bak-x430）
170-
171:# x430（2026-11-07）: 立ち上げ直す時刻を残す。tab-guard はこの直後のタブの減少を「一括破壊」とみなさない
172-date +%s > "$HOME/.openclaw/workspace/data/ensure-chrome-restart-at" 2>/dev/null || true
173-launch_chrome
174-if wait_healthy 45; then
```

## ② tab-guard.js
```
差し込んだ
構文 OK・入れ替えた（退避 tab-guard.js.bak-x430）
62:// x430（2026-11-07）: ensure-chrome が自動化用 Chrome を立ち上げ直した時刻（秒）。無ければ null
65:const RESTART_GRACE_S = 180;
66:function restartAgeSec() {
128:  // x430: 立ち上げ直した直後の減少は、破壊ではない。B・C では止めない（A のプロセス消滅は上で別に見ている）
129:  const _rs = restartAgeSec();
130:  if (_rs !== null && _rs >= 0 && _rs < RESTART_GRACE_S && typeof prev.count === "number" && now.count < prev.count) {
131:    log(`タブ ${prev.count} → ${now.count} 枚。ensure-chrome が ${_rs} 秒前に自動化用 Chrome を立ち上げ直したので、破壊とみなさない（x430）`);
```

## ④ 常駐している tab-guard を立ち上げ直す（判定を手で 1 回走らせることはしない。条件に当たると全停止するため）
```
ラベル: ai.openclaw.tab-guard
kickstart rc=0
	state = running 	runs = 26 	pid = 16913 		state = active 		state = active 
[2026-11-06T08:01:27.854Z] 監視終了（要因を確認してください）
[2026-11-06T08:01:27.902Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-07T05:32:53.486Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

**LLM を呼ばない（$0／回・$0／日・$0／月）。投稿していない。ジョブは外していない。**
