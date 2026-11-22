# フォロー plist の修復（2026-08-22T13:07:46Z）

## ai.openclaw.competitor-follower-follow

### 現行 .plist
- 更新: 2026-08-22 20:07  サイズ: 79 B
- トップレベルのキー: PATH 
- Label: **無し**
- ProgramArguments: **無し**
- 判定: **壊れている（launchd が読めない）**

### バックアップ候補
- ai.openclaw.competitor-follower-follow.plist.bak.20260615-v6-tactic  更新=2026-08-22 22:07  → 正常

### 復元
- 壊れた現行を ai.openclaw.competitor-follower-follow.plist.broken.20260822-130746 へ退避した
- ai.openclaw.competitor-follower-follow.plist.bak.20260615-v6-tactic から復元した
- 復元後の Label: 読めない
- 復元後の起動設定: StartCalendarInterval=無し / StartInterval=無し
- ProgramArguments: 

### ロード
plist が正常でないので bootstrap しない。

## ai.openclaw.hashtag-follow

### 現行 .plist
- 更新: 2026-08-22 20:07  サイズ: 77 B
- トップレベルのキー: PATH 
- Label: **無し**
- ProgramArguments: **無し**
- 判定: **壊れている（launchd が読めない）**

### バックアップ候補
- ai.openclaw.hashtag-follow.plist.bak.20260615-v6-tactic  更新=2026-08-22 22:07  → 正常

### 復元
- 壊れた現行を ai.openclaw.hashtag-follow.plist.broken.20260822-130746 へ退避した
- ai.openclaw.hashtag-follow.plist.bak.20260615-v6-tactic から復元した
- 復元後の Label: 読めない
- 復元後の起動設定: StartCalendarInterval=無し / StartInterval=無し
- ProgramArguments: 

### ロード
plist が正常でないので bootstrap しない。

## Chrome CDP（ここが死んでいると、載せても実行 0 件のまま）
→ **応答なし。** 別途復旧が必要。

### chrome-cdp の plist とロード状態
- ai.openclaw.chrome-cdp.plist  更新=2026-08-22 22:07  → 正常
- ai.openclaw.chrome-cdp.plist.bak.20260602-keepalive-off  更新=2026-08-22 22:07  → 正常
- ai.openclaw.chrome-cdp.plist.bak.20260602-throttle  更新=2026-08-22 22:07  → 正常
- launchctl: 0 件

## 最終状態（follow 系）
-	0	ai.openclaw.follower-snapshot
-	0	ai.openclaw.badge-followback
