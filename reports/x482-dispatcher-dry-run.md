# 押す係の試し運転を入れる（2026-11-14 20:10:10 JST・$0・何も押さない）

## ① ② ファイルを置く
```
置いた: x-action-pacer.cjs
置いた: x-action-dispatcher.cjs
pacer: 押す直前の記録 → 入っている
```

## ③ 試し運転のジョブを載せる
```
/Users/ny/Library/LaunchAgents/com.dailyhack.x-action-dispatcher.plist: OK
bootstrap rc=0 
載っている ←  DRY_RUN => 1  run interval = 900 seconds 
--- 1 回目の出力
[x-action-dispatcher 試し運転] 2026-11-14T11:10:11.908Z {"picked":"列が空","next_in_min":36,"queue":0}
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x482-dispatcher-dry-run.sh: line 47: /Users/ny/.openclaw/workspace/data/x-action-shadow.jsonl: No such file or directory
--- 押す直前の記録（いままでの行数）: 0
```
