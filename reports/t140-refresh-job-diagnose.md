# リフレッシュのジョブが載らない（t140）

生成: **2026-09-21T02:00:43+0900**

## 1) 置いたものは在るか

- plist: **在る** `/Users/ny/Library/LaunchAgents/com.dailyhack.refresh-daily.plist`
- シム: **在る** `/Users/ny/.openclaw/bin/refresh-daily-boot.sh`
- `plutil -lint`: **通る**

## 2) 無効リストに入っていないか

- `print-disabled`: このラベルの行は無い
- `launchctl enable`: rc=0 
- `launchctl bootout`: rc=0 

## 3) 載せ直す（**エラー文を残す**）

- 1 回目: rc=0 
- 2 回目: rc=5 — `Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. `
- 3 回目: rc=5 — `Bootstrap failed: 5: Input/output error Try re-running the command as root for richer errors. `

- `launchctl list`: **載っていない** ← **こちらが証拠**


## 4) 走っても何もしない条件（**触らずに見るだけ**）

- 鍵: ⚠️ **どこにも見つからない。** 05:30 に走っても**何もせずに終わる**
- 参考: `~/.claude/.credentials.json` は**在る**（サブスク認証。**API 課金の鍵ではない**）

### 作業ツリーの未コミット（**ファイル名だけ。中身は出さない**）

```text
?? drafts/
?? ops/tasks/t006-post-sauna-thread.sh
```

- HEAD: `17107e9 feat: 記事を定期的に更新する仕組み（AIO ＋ 素材 ＋ リサーチ） (#593)`
- **これが残っている間、ジョブは何もせずに終わる**（人の書きかけを消さないため）
