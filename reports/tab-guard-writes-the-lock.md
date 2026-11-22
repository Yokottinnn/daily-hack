# tab-guard が login ロックを書いていた

**このレポートが作られた時刻: 2026-09-13 01:26:57 JST**

## 1. `tab-guard.js` のどこがロックを書いているか

```
  --- 該当行 ---
    27:const LOCK = "/tmp/x-login-in-progress";

  --- 書き込みしている行 ---
    33:  try { fs.appendFileSync(LOG, `[${new Date().toISOString()}] ${msg}\n`); } catch {}
    64:  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
    120:  try { fs.writeFileSync(STATE, JSON.stringify({ count: now.count, at: new Date().toISOString() }, null, 2)); } catch {}
```

## 2. ロックを書く行だけ無効化する（**halt は残す**）

止めるのは**ロックの書き込みだけ。** 一括破壊の検知と停止はそのまま残す。
ロックは `ensure-chrome.sh` を no-op にするので、**復帰経路を塞ぐ側の作用しかない。**

```
  退避: tab-guard.js.bak-20260913-012657
    **書き換え対象の行が見つからなかった。何もしていない。**
  node --check: OK
```

## 3. いまロックが在るなら外す

```
  ロックは無い（正常）。
```

## 4. 10 秒おきに 3 分 見張る（**消えた瞬間を押さえる**）

x38 では 30 秒 → 60 秒 のあいだに 5/8 → 4/8 へ減ったが、
**tab-guard はログを 1 行も出していない。** 別の主がいる。

```
  開始時: 4 / 8 本

  ★ 01:27:18 **消えた: incoming-reply-watcher**
    --- tab-guard ログ 直近 5 行 ---
      [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
      [2026-09-12T15:24:13.631Z] 停止完了
      [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
      [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    --- いま動いている openclaw 系プロセス ---
        397 03-02:15:58 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
        476 03-02:15:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        479 03-02:15:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        512 03-02:15:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        513 03-02:15:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        518 03-02:15:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        905 03-02:15:44 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw/listener.py
       3970 03-02:12:56 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
    --- 直近 2 分に更新されたログ ---

  ★ 01:27:28 **消えた: comment-warmup**
    --- tab-guard ログ 直近 5 行 ---
      [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
      [2026-09-12T15:24:13.631Z] 停止完了
      [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
      [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    --- いま動いている openclaw 系プロセス ---
        397 03-02:16:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
        476 03-02:16:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        479 03-02:16:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        512 03-02:16:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        513 03-02:16:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        518 03-02:16:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        905 03-02:15:54 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw/listener.py
       3970 03-02:13:06 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
    --- 直近 2 分に更新されたログ ---

  ★ 01:28:29 **消えた: comment-warmup**
    --- tab-guard ログ 直近 5 行 ---
      [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
      [2026-09-12T15:24:13.631Z] 停止完了
      [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
      [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    --- いま動いている openclaw 系プロセス ---
        397 03-02:17:09 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
        476 03-02:17:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        479 03-02:17:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        512 03-02:17:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        513 03-02:17:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        518 03-02:17:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        905 03-02:16:55 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw/listener.py
       3970 03-02:14:07 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
    --- 直近 2 分に更新されたログ ---

  ★ 01:29:30 **消えた: comment-warmup**
    --- tab-guard ログ 直近 5 行 ---
      [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
      [2026-09-12T15:24:13.631Z] 停止完了
      [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
      [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    --- いま動いている openclaw 系プロセス ---
        397 03-02:18:10 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
        476 03-02:18:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        479 03-02:18:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        512 03-02:18:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        513 03-02:18:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        518 03-02:18:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        905 03-02:17:56 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw/listener.py
       3970 03-02:15:08 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
    --- 直近 2 分に更新されたログ ---

  ★ 01:29:40 **消えた: incoming-reply-watcher**
    --- tab-guard ログ 直近 5 行 ---
      [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚（実質全消滅） → 自動化を全停止
      [2026-09-12T15:24:13.631Z] 停止完了
      [2026-09-12T15:24:13.633Z] 監視終了（要因を確認してください）
      [2026-09-12T15:24:13.662Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
      [2026-09-12T15:43:41.695Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    --- いま動いている openclaw 系プロセス ---
        397 03-02:18:20 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
        476 03-02:18:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        479 03-02:18:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        512 03-02:18:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        513 03-02:18:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        518 03-02:18:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
        905 03-02:18:06 /Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python /Users/ny/openclaw/listener.py
       3970 03-02:15:18 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.
    --- 直近 2 分に更新されたログ ---

  **3 分後: 4 / 8 本**
```

## 5. `comment-warmup` が生きていれば、待たずに走らせる

```
  comment-warmup が載っていない。**LLM を 1 回も呼ばずに終わる（$0）。**
```
