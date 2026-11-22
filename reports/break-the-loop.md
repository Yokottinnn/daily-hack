# 悪循環を断つ

**このレポートが作られた時刻: 2026-09-12 23:22:10 JST**

> `tab-guard` は **CDP の `/json/list`** を見てタブを数えている。
> **CDP が落ちているだけで「利用者がウィンドウを全部 閉じた」と誤判定し、全停止する。**
> 止まると Chrome を起動するジョブも消えるので、**永久に抜けられない。**

## 1. 鍵は外れているか

```
  **まだ有る**: /tmp/x-login-in-progress（0 時間）
  → CDP 付き Chrome が動いている。手動ログイン中かもしれないので触らない。
```

## 2. **CDP を戻す**（ここが輪の切断点）

```
  --- 前 ---
    CDP: 健全

  --- ensure-chrome.sh ---
    ensure-chrome: login-mode-guard active, skip launch
    (rc=0)

  --- 45 秒 待って確認 ---
    15 秒後: **健全になった**

  --- ensure-chrome.log の末尾 ---
    [2026-08-09T23:55:56Z] ensure-chrome: Chrome up and CDP responsive
    [2026-08-09T23:55:56Z] ensure-chrome: logged out after restart — running x-login.js
    [2026-08-10T00:49:55Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-08-10T00:50:58Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
    [2026-08-13T15:37:03Z] ensure-chrome: Chrome failed to become CDP-responsive within 45s
    [2026-08-15T04:41:51Z] ensure-chrome: Chrome up and CDP responsive
    [2026-09-07T14:59:29Z] ensure-chrome: Chrome up and CDP responsive
    [2026-09-07T14:59:37Z] ensure-chrome: logged out after restart — running x-login.js
    [2026-09-07T14:59:38Z] ensure-chrome: re-login FAILED — manual login required
    [2026-09-07T15:00:00Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
    [2026-09-07T15:00:13Z] ensure-chrome: Chrome up and CDP responsive
    [2026-09-12T13:29:46Z] ensure-chrome: Chrome up and CDP responsive
```

## 3. `tab-guard` の誤判定を直す（**非常ブレーキは残す**）

**「CDP に繋がらない」は「利用者がタブを消した」ではない。**
前回が `reachable:false` なら**比較そのものを行わない。**
タブが 10 → 1 のような**実際の減少**は、これまでどおり検知する。

```
  退避: tab-guard.js.bak-20260912-232210
  UNREACHABLE_GUARD を入れた
  node --check: OK
```

```diff
--- /Users/ny/.openclaw/workspace/scripts/tab-guard.js.bak-20260912-232210	2026-08-15 13:42:40
+++ /Users/ny/.openclaw/workspace/scripts/tab-guard.js	2026-09-12 23:22:26
@@ -77,6 +77,15 @@
 
   // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
   if (!chromeAlive()) {
+    // UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**
+    // tab-guard は CDP の /json/list でタブを数えている。CDP が落ちていると
+    // 「利用者がウィンドウを全部 閉じた」と誤判定し、Chrome を起動するジョブごと
+    // 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。
+    // **前回も繋がっていなかったなら、それは「消滅」ではなく「まだ落ちたまま」。**
+    if (prev && prev.reachable === false) {
+      log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
+      return;
+    }
     haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
     return { halted: true, reason: "chrome_process_gone" };
   }
```

## 4. CDP が戻らなかった場合の保険

```
  CDP は戻った。**tab-guard は止めない。** 非常ブレーキを残す。
```

## 5. 3 ループを載せる

```
  載らない comment-warmup                          
  **載せた** competitor-follower-follow            
  **載せた** hashtag-follow                        
  **載せた** badge-followback                      
  **載せた** reply-followback-check                
  載らない reply-followers-cleanup                 
  載らない incoming-reply-watcher                  
  載らない pipeline-heartbeat                      
```

## 6. **90 秒 待って、生き残るか**（また外されないか）

```
  30 秒後: 4 / 8 本
  60 秒後: 4 / 8 本
  90 秒後: 5 / 8 本

  **最終: 4 / 8 本**
  tab-guard: 1 本
  CDP: 健全

  --- tab-guard のログ（この間に鳴ったか） ---
    [2026-09-12T13:29:39.144Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:29:40.532Z] 停止完了
    [2026-09-12T13:29:40.532Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:49.601Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:49.639Z] 🚨 Jordan のタブが 14 → 1 枚（一括破壊） → 自動化を全停止
    [2026-09-12T13:29:49.860Z] 停止完了
    [2026-09-12T13:29:49.861Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:59.929Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
```

---

## 判定

| 結果 | 意味 |
| --- | --- |
| 8 / 8 が 90 秒 生きた ＋ CDP 健全 | **輪を断てた。** 次の定時（12/16/19/22 時）から 3 ループが動く |
| 8 / 8 だが CDP が落ちている | ジョブは載った。**CDP の復旧が別途 要る** |
| 途中で減った | **まだ外す主がいる。** tab-guard 以外を疑う |

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（**実測** 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**Chrome を kill していない。投稿もしていない。**
