# 誰が `/tmp/x-login-in-progress` を作り続けているのか

**このレポートが作られた時刻: 2026-09-12 22:21:28 JST**

> 4 日 刺さり続けているのに **mtime が 0 時間**。
> **何かが定期的に touch し直している。** 時間だけの判定では永久に外れない。

## 1. 鍵のいまの状態

```
  有る: /tmp/x-login-in-progress
    作成(ctime): 2026-09-12 22:21:24
    更新(mtime): 2026-09-12 22:21:24
    所有者     : ny:wheel
    大きさ     : 9 B
    中身       :
      tab-guard
  --- いま誰か開いているか ---
    誰も開いていない

  --- 退避済みのもの ---
```

## 2. 鍵を**作っている**コード

```bash
/Users/ny/.openclaw/workspace/scripts/chrome-restart-hook.sh:9:LOCK=/tmp/x-login-in-progress
/Users/ny/.openclaw/workspace/scripts/pipeline-guardian.js:33:const LOGIN_LOCK = "/tmp/x-login-in-progress";
/Users/ny/.openclaw/workspace/scripts/ensure-x-login.js:5: * P4 (2026-07-04): main 冒頭で /tmp/x-login-in-progress lock file check、
/Users/ny/.openclaw/workspace/scripts/ensure-x-login.js:35:const LOCK_FILE = "/tmp/x-login-in-progress";  // P4
/Users/ny/.openclaw/workspace/scripts/ensure-x-login.js:248:  lines.push("先に `ssh home-mac 'touch /tmp/x-login-in-progress'` (cron 抑止) → CRD login → `ssh home-mac 
/Users/ny/.openclaw/workspace/scripts/wave-freeze.sh:7:LOCK=/tmp/x-login-in-progress
/Users/ny/.openclaw/workspace/scripts/crd-detect-daemon.js:17: *   - 「自分が set した」 = /tmp/x-login-in-progress.crd-auto marker
/Users/ny/.openclaw/workspace/scripts/crd-detect-daemon.js:26:const LOCK = "/tmp/x-login-in-progress";
/Users/ny/.openclaw/workspace/scripts/crd-detect-daemon.js:27:const AUTO_MARKER = "/tmp/x-login-in-progress.crd-auto";
/Users/ny/.openclaw/workspace/scripts/cookie-restore.sh:6:if [ -f /tmp/x-login-in-progress ]; then
/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh:16:LOCK=/tmp/x-login-in-progress
/Users/ny/.openclaw/workspace/scripts/tab-guard.js:27:const LOCK = "/tmp/x-login-in-progress";
/Users/ny/.openclaw/workspace/scripts/restore-cookies-and-relaunch.sh:9:# 2026-07-11 login-mode guard: /tmp/x-login-in-progress 存在時 は Chrome quit skip
/Users/ny/.openclaw/workspace/scripts/restore-cookies-and-relaunch.sh:10:if [ -f /tmp/x-login-in-progress ]; then
/Users/ny/.openclaw/workspace/scripts/grok-trending-daily.js:22:const LOCK_FILE = "/tmp/x-login-in-progress";
/Users/ny/.openclaw/workspace/scripts/lib/slack-notify.js:18://       { label: "B", description: "Chrome Remote Desktop で手動 login", command: "先に touch /tmp/x-login-i
/Users/ny/.openclaw/workspace/scripts/x-loop-guardian.sh:9:#   B. /tmp/x-login-in-progress が 6 時間 超なら退避
/Users/ny/.openclaw/workspace/scripts/x-loop-guardian.sh:21:LOCK=/tmp/x-login-in-progress
/Users/ny/.openclaw/workspace/scripts/unfollow-cleanup.js:36:const LOGIN_LOCK = "/tmp/x-login-in-progress";
/Users/ny/openclaw/chrome-cdp-heal.sh:6:if [ -f /tmp/x-login-in-progress ]; then
  ---（上が全部。作る側と消す側の両方が入っている）---
```

### そのうち **作る** 行だけ

```bash
/Users/ny/.openclaw/workspace/scripts/ensure-x-login.js:248:  lines.push("先に `ssh home-mac 'touch /tmp/x-login-in-progress'` (cron 抑止) → CRD login → `ssh home-mac 
/Users/ny/.openclaw/workspace/scripts/lib/slack-notify.js:18://       { label: "B", description: "Chrome Remote Desktop で手動 login", command: "先に touch /tmp/x-login-i
```

### そのうち **消す** 行だけ（**これが動いていないのが問題**）

```bash
/Users/ny/.openclaw/workspace/scripts/ensure-x-login.js:248:  lines.push("先に `ssh home-mac 'touch /tmp/x-login-in-progress'` (cron 抑止) → CRD login → `ssh home-mac 
/Users/ny/.openclaw/workspace/scripts/lib/slack-notify.js:18://       { label: "B", description: "Chrome Remote Desktop で手動 login", command: "先に touch /tmp/x-login-i
```

## 3. それを呼ぶジョブは動いているか

```
  [chrome-restart-hook.sh]
    どの plist からも直接 呼ばれていない（別スクリプト経由の可能性）
  [pipeline-guardian.js]
    ai.openclaw.pipeline-guardian                **未ロード**
  [ensure-x-login.js]
    どの plist からも直接 呼ばれていない（別スクリプト経由の可能性）
  [wave-freeze.sh]
    どの plist からも直接 呼ばれていない（別スクリプト経由の可能性）
  [crd-detect-daemon.js]
    ai.openclaw.crd-detect-daemon                **未ロード**
  [cookie-restore.sh]
    どの plist からも直接 呼ばれていない（別スクリプト経由の可能性）
  [ensure-chrome.sh]
    ai.openclaw.follow-watchdog                  **未ロード**
    ai.openclaw.grok-trending-daily              **未ロード**
    ai.openclaw.revenge-unfollow                 **未ロード**
  [tab-guard.js]
    ai.openclaw.tab-guard                        PID=- rc=1
```

## 4. いま走っているプロセスに、鍵を触りそうなものはあるか

```
    397 02-23:10:10 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
    476 02-23:10:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
    479 02-23:10:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
    512 02-23:10:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
    513 02-23:10:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
    518 02-23:10:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
    905 02-23:09:56 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw
   3970 02-23:07:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framewor
  ---（空なら、いま走っているものは無い）---
```

## 5. ログから、鍵が作られた前後を見る

```
  [ensure-chrome.log] 更新 2026-09-08 00:00
    182:[2026-08-07T12:08:39Z] ensure-chrome: logged out but re-login throttled (631s < 1200s) — skip
    186:[2026-08-07T12:13:50Z] ensure-chrome: logged out but re-login throttled (942s < 1200s) — skip
    188:[2026-08-07T12:19:02Z] ensure-chrome: logged out after restart — running x-login.js
    189:[2026-08-07T12:19:10Z] ensure-chrome: re-login FAILED — manual login required
    192:[2026-08-07T12:24:22Z] ensure-chrome: logged out but re-login throttled (320s < 1200s) — skip
    195:[2026-08-07T12:29:34Z] ensure-chrome: logged out but re-login throttled (632s < 1200s) — skip
    197:[2026-08-07T12:31:41Z] ensure-chrome: logged out but re-login throttled (759s < 1200s) — skip
    207:[2026-08-08T15:11:47Z] ensure-chrome: logged out after restart — running x-login.js
    208:[2026-08-08T15:12:42Z] ensure-chrome: re-login OK
    234:[2026-08-09T23:55:56Z] ensure-chrome: logged out after restart — running x-login.js
    240:[2026-09-07T14:59:37Z] ensure-chrome: logged out after restart — running x-login.js
    241:[2026-09-07T14:59:38Z] ensure-chrome: re-login FAILED — manual login required

```

---

## 直し方の見当

| 分かったこと | 直し方 |
| --- | --- |
| 作る側が特定できた ＋ 消す側が無い/壊れている | **消す側に `trap ... EXIT` を足す** |
| 作る側のジョブが未ロード | **誰も作っていない＝残骸。番人が外せば終わり** |
| 作る側が常駐している | **その常駐を直す。番人が外しても戻される** |

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（読むだけ・LLM 不使用） | **$0** | **$0** | **$0** |

**何も変更していない。鍵も消していない。**
