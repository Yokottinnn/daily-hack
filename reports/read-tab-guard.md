# `tab-guard.js` の全文

**このレポートが作られた時刻: 2026-09-20 02:25:00 JST**

> x87 で犯人は確定した。**tab-guard が `ai.openclaw.*` を全部 外している。**
> 発火条件のひとつが「Chrome プロセスが消滅」で、**再起動すれば必ず成立する。**
>
> 方針: **起動直後は停めない。**「一度 生きていたのに消えた」に限る。

**読むだけ。書き換えない。**

## 1. 全文（**138 行**）

```
  138 行 / 最終更新 2026-09-13 01:41
```

```javascript
   1| #!/usr/bin/env node
   2| /**
   3|  * tab-guard.js — Jordan の Chrome が「丸ごと落とされる」異常だけを検知して自動化を止める。
   4|  *
   5|  * 2026-08-09: 自動化が Chrome を pkill し、Jordan のウィンドウが全消滅する事故を起こした。
   6|  * これが本当に許容できない事象。
   7|  *
   8|  * 一方、タブが1〜2枚減るのは Jordan 自身の通常操作でも起きる。それで cron を止めるのは
   9|  * やり過ぎで無駄な停止を招く（2026-08-09 Jordan 指摘）。
  10|  * → **通常運用ではあり得ない事象だけ**を止める条件にする:
  11|  *     A. Chrome プロセスが消えた / CDP に繋がらない（＝ウィンドウ全消滅）
  12|  *     B. タブが 0〜1 枚になった（＝実質全部消えた）
  13|  *     C. 一度に半分以上のタブが消えた（＝一括破壊）
  14|  *   数枚の増減は Jordan の操作として無視する。
  15|  *
  16|  * Usage:
  17|  *   node scripts/tab-guard.js            1回チェック
  18|  *   node scripts/tab-guard.js --watch    常駐監視（30秒間隔）
  19|  */
  20| const http = require("http");
  21| const fs = require("fs");
  22| const { execSync } = require("child_process");
  23| 
  24| const USER_PORT = 18810;
  25| const STATE = "/Users/ny/.openclaw/workspace/data/tab-guard-state.json";
  26| const LOG = "/Users/ny/.openclaw/workspace/logs/tab-guard.log";
  27| const LOCK = "/tmp/x-login-in-progress";
  28| const INTERVAL_MS = 30000;
  29| const MIN_TABS = 1;              // これ未満なら異常（実質全消滅）
  30| const CATASTROPHIC_RATIO = 0.5;  // 一度に半分以上消えたら異常
  31| 
  32| function log(msg) {
  33|   try { fs.appendFileSync(LOG, `[${new Date().toISOString()}] ${msg}\n`); } catch {}
  34|   console.log(msg);
  35| }
  36| 
  37| function getTabs(port) {
  38|   return new Promise((resolve) => {
  39|     const req = http.get({ host: "127.0.0.1", port, path: "/json/list", timeout: 8000 }, (r) => {
  40|       let d = "";
  41|       r.on("data", c => d += c);
  42|       r.on("end", () => {
  43|         try {
  44|           const list = JSON.parse(d).filter(t => t.type === "page");
  45|           resolve({ reachable: true, count: list.length });
  46|         } catch { resolve({ reachable: false }); }
  47|       });
  48|     });
  49|     req.on("timeout", () => { req.destroy(); resolve({ reachable: false }); });
  50|     req.on("error", () => resolve({ reachable: false }));
  51|   });
  52| }
  53| 
  54| // Chrome プロセス自体が生きているか（CDP が重いだけの誤検知を避ける）
  55| function chromeAlive() {
  56|   try {
  57|     execSync(`pgrep -f "remote-debugging-port=${USER_PORT}" >/dev/null 2>&1`, { shell: "/bin/bash" });
  58|     return true;
  59|   } catch { return false; }
  60| }
  61| 
  62| function haltAutomation(reason) {
  63|   log(`🚨 ${reason} → 自動化を全停止`);
  64|   // LOCK_WRITE_DISABLED (2026-09-13): このロックは ensure-chrome.sh を no-op に
  65|   // して Chrome の起動を塞ぎ、tab-guard 自身の halt 条件を永久に成立させ続けた
  66|   // （docs/self-healing-deadlock.md 条件 3）。halt と検知はそのまま残す。
  67|   // try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
  68|   try {
  69|     execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
  70|       { shell: "/bin/bash", timeout: 60000 });
  71|   } catch {}
  72|   try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
  73|   log("停止完了");
  74| }
  75| 
  76| async function check() {
  77|   const now = await getTabs(USER_PORT);
  78|   let prev = {};
  79|   try { prev = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch {}
  80| 
  81|   // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
  82|   if (!chromeAlive()) {
  83|     // UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**
  84|     // tab-guard は CDP の /json/list でタブを数えている。CDP が落ちていると
  85|     // 「利用者がウィンドウを全部 閉じた」と誤判定し、Chrome を起動するジョブごと
  86|     // 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。
  87|     // **前回も繋がっていなかったなら、それは「消滅」ではなく「まだ落ちたまま」。**
  88|     if (prev && prev.reachable === false) {
  89|       log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
  90|       return;
  91|     }
  92|     haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
  93|     return { halted: true, reason: "chrome_process_gone" };
  94|   }
  95| 
  96|   // CDP が一時的に重いだけなら判定しない（プロセスは生きている）
  97|   if (!now.reachable) return { ok: true, skipped: "CDP 応答なし（プロセスは生存）" };
  98| 
  99|   const result = { count: now.count, prev: prev.count ?? null };
 100| 
 101|   // B: 実質全部消えた
 102|   if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
 103|     // LOW_BASELINE_GUARD (2026-09-13): **元が 1 枚なら「全部 消えた」ではない。**
 104|     // 自動化専用 Chrome は起動直後 1 タブしかなく、スクリプトが作業タブを
 105|     // page.close() すると 1 → 0 枚になる。それを「実質全消滅」と見なすと、
 106|     // **自動化そのものが自動化を止める**（2026-09-12 15:24 に実際に起きた）。
 107|     // B は「たくさんあったものが 0〜1 枚になった」を想定した条件。
 108|     // **前回が 3 枚未満なら、そもそも破壊の前提が無い。**
 109|     if (!prev || typeof prev.count !== "number" || prev.count < 3) {
 110|       log(`タブ ${prev && prev.count} → ${now.count} 枚。元が少ないので破壊とみなさない`);
 111|       return;
 112|     }
 113|     haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
 114|     result.halted = true;
 115|   }
 116|   // C: 一度に半分以上が消えた
 117|   else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
 118|     haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
 119|     result.halted = true;
 120|   }
 121|   // それ以外の増減は Jordan の通常操作。止めない。
 122| 
 123|   try { fs.writeFileSync(STATE, JSON.stringify({ count: now.count, at: new Date().toISOString() }, null, 2)); } catch {}
 124|   return result;
 125| }
 126| 
 127| (async () => {
 128|   if (process.argv.includes("--watch")) {
 129|     log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
 130|     for (;;) {
 131|       const r = await check();
 132|       if (r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
 133|       await new Promise(res => setTimeout(res, INTERVAL_MS));
 134|     }
 135|   } else {
 136|     console.log(JSON.stringify(await check()));
 137|   }
 138| })();
```

## 2. 状態をどこに持っているか

```
  --- 読み書きしているファイル ---
    /Users/ny/.openclaw/workspace/data/tab-guard-state.json

  --- data/ にある tab-guard 関連 ---
    tab-guard-state.json                                 2026-09-20 02:24
      {
        "count": 3,
        "at": "2026-09-19T17:24:32.633Z"
      }
```

## 3. plist（**10 秒 ごとに再起動している件**）

```
  更新: 2026-08-09 18:19
    KeepAlive            true
    RunAtLoad            true
    StartInterval        (無し)
    ThrottleInterval     (無し)

  --- ProgramArguments ---
    Array {
        /usr/local/bin/node
        /Users/ny/.openclaw/workspace/scripts/tab-guard.js
        --watch
    }

  --- いまの状態 ---
    PID=18057  最後の終了コード=1
```

**`KeepAlive` が true なら、落ちるたびに launchd が上げ直す。**
10 秒 ごとの再起動は `ThrottleInterval`（既定 10 秒）と一致する。
つまり**毎回 落ちていて、launchd が 10 秒 おきに上げ直している。**

## 4. 落ちている理由（**エラーログ**）

```
  ══ tab-guard-err.log（2958020 bytes / 09-20 01:14）
    
    Node.js v24.14.0
    /Users/ny/.openclaw/workspace/scripts/tab-guard.js:132
          if (r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
                ^
    
    TypeError: Cannot read properties of undefined (reading 'halted')
        at /Users/ny/.openclaw/workspace/scripts/tab-guard.js:132:13
        at process.processTicksAndRejections (node:internal/process/task_queues:104:5)
    
    Node.js v24.14.0
    /Users/ny/.openclaw/workspace/scripts/tab-guard.js:132
          if (r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
                ^
    
    TypeError: Cannot read properties of undefined (reading 'halted')
        at /Users/ny/.openclaw/workspace/scripts/tab-guard.js:132:13
        at process.processTicksAndRejections (node:internal/process/task_queues:104:5)
    
    Node.js v24.14.0

```

## 5. 費用

**読むだけ。LLM を呼ばない。外しも載せもしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**直す場合も $0**（判定条件を変えるだけ。LLM を呼ばない）。
返信ループの実額は 1 回 $0.003 ／ 1 日 上限 $0.048 ／ 1 か月 上限 $1.44。
