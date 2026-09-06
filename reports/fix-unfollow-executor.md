# アンフォローの実行役に上限を入れて起動する（2026-09-06 21:32 JST・費用 $0）

> **真因は「ロードされていなかった」こと。** plist は壊れていない（2026-05-13 のまま）。
> **だがそのまま load してはいけない。** このスクリプトは期限到来分を
> **全件 まとめて処理する。上限が無い。196 件を一度に外すと X の判定に触れる。**
> **先に上限を入れる。**

## 0. 走らせる前の数

- 期限到来: **197 件**
- `unfollowed`: **16 件** / `no`: **207 件**

## 1. 上限を入れる

  差し込んだ（既定 20 件・環境変数 CLEANUP_MAX_PER_RUN で変えられる）
- 構文OK（退避 `.bak.20260906-213249`）

```javascript
46-    return;
47-  }
48:  const CLEANUP_MAX_PER_RUN = Number(process.env.CLEANUP_MAX_PER_RUN || 20);
49:  if (due.length > CLEANUP_MAX_PER_RUN) {
50:    log(`due ${due.length} → 上限 ${CLEANUP_MAX_PER_RUN} 件に絞る（残りは次回）`);
51:    due.length = CLEANUP_MAX_PER_RUN;
52-  }
53-  log(`due unfollows: ${due.length} → ${due.join(",")}`);
54-
55-  // Master rule: 直前再check (batch)
56-  let recheck;
```

## 2. plist を確かめて load する

- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.reply-followers-cleanup.plist: OK

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.reply-followers-cleanup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/ny/.openclaw/workspace/scripts/reply-followers-cleanup.js</string>
  </array>
  <key>StartInterval</key>
  <integer>3600</integer>
  <key>StandardOutPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.out</string>
  <key>StandardErrorPath</key>
  <string>/Users/ny/.openclaw/workspace/logs/reply-followers-cleanup.err</string>
</dict>
</plist>
```

```
```

### `launchctl list` で確かめる

```
  ロード済み  PID=-        最後のrc=0
```

## 3. まず 5 件だけ外す

**いきなり 20 件も外さない。** 外れることを実物で確かめてから増やす。

```
/var/folders/qm/dwxlvygj76q_fq054b8jrrr80000gn/T//ops-tasks/x06-fix-unfollow-executor.sh: line 173: timeout: command not found
(rc=127)
```

## 4. 実際に外れたか（**状態ファイルの前後で数える**）

| | 前 | 後 |
| --- | --- | --- |
| 期限到来 | 197 | **197** |
| `unfollowed` | 16 | **16** |
| `yes_late`（あとからフォロバ） | — | 1 |

- **今回 外した数: 0 件**
- **何も動いていない。上のログを読むこと。**

- 残りの期限到来: **197 件**
  定時実行で 1 回あたり最大 20 件ずつ減る（`CLEANUP_MAX_PER_RUN` の既定）

---

**5 件を超えて外していない。他のジョブは触っていない。LLM も呼んでいない（$0）。**
