# 載せた直後に誰が外しているのか

**このレポートが作られた時刻: 2026-09-12 23:11:54 JST**

> `x30` の実測で矛盾が出た。
> **§1: load -w rc=0 / 載ったか 1 本** → **§6: ロード済み 0 / 8**
> **load は成功していた。載った直後に、何かが外している。**

生き残っている `ai.openclaw.*` は **`tab-guard` ただ 1 本**。
`t014`（2026-08-30）の署名と一致する。**実地で捕まえる。**

## 1. `tab-guard.js` の全文

推測しない。**halt の条件・ロックの実体・除外リストを全部 読む。**

```javascript
  // tab-guard.js — 116 行 / 更新 2026-08-15 13:42
     1	#!/usr/bin/env node
     2	/**
     3	 * tab-guard.js — Jordan の Chrome が「丸ごと落とされる」異常だけを検知して自動化を止める。
     4	 *
     5	 * 2026-08-09: 自動化が Chrome を pkill し、Jordan のウィンドウが全消滅する事故を起こした。
     6	 * これが本当に許容できない事象。
     7	 *
     8	 * 一方、タブが1〜2枚減るのは Jordan 自身の通常操作でも起きる。それで cron を止めるのは
     9	 * やり過ぎで無駄な停止を招く（2026-08-09 Jordan 指摘）。
    10	 * → **通常運用ではあり得ない事象だけ**を止める条件にする:
    11	 *     A. Chrome プロセスが消えた / CDP に繋がらない（＝ウィンドウ全消滅）
    12	 *     B. タブが 0〜1 枚になった（＝実質全部消えた）
    13	 *     C. 一度に半分以上のタブが消えた（＝一括破壊）
    14	 *   数枚の増減は Jordan の操作として無視する。
    15	 *
    16	 * Usage:
    17	 *   node scripts/tab-guard.js            1回チェック
    18	 *   node scripts/tab-guard.js --watch    常駐監視（30秒間隔）
    19	 */
    20	const http = require("http");
    21	const fs = require("fs");
    22	const { execSync } = require("child_process");
    23	
    24	const USER_PORT = 18810;
    25	const STATE = "/Users/ny/.openclaw/workspace/data/tab-guard-state.json";
    26	const LOG = "/Users/ny/.openclaw/workspace/logs/tab-guard.log";
    27	const LOCK = "/tmp/x-login-in-progress";
    28	const INTERVAL_MS = 30000;
    29	const MIN_TABS = 1;              // これ未満なら異常（実質全消滅）
    30	const CATASTROPHIC_RATIO = 0.5;  // 一度に半分以上消えたら異常
    31	
    32	function log(msg) {
    33	  try { fs.appendFileSync(LOG, `[${new Date().toISOString()}] ${msg}\n`); } catch {}
    34	  console.log(msg);
    35	}
    36	
    37	function getTabs(port) {
    38	  return new Promise((resolve) => {
    39	    const req = http.get({ host: "127.0.0.1", port, path: "/json/list", timeout: 8000 }, (r) => {
    40	      let d = "";
    41	      r.on("data", c => d += c);
    42	      r.on("end", () => {
    43	        try {
    44	          const list = JSON.parse(d).filter(t => t.type === "page");
    45	          resolve({ reachable: true, count: list.length });
    46	        } catch { resolve({ reachable: false }); }
    47	      });
    48	    });
    49	    req.on("timeout", () => { req.destroy(); resolve({ reachable: false }); });
    50	    req.on("error", () => resolve({ reachable: false }));
    51	  });
    52	}
    53	
    54	// Chrome プロセス自体が生きているか（CDP が重いだけの誤検知を避ける）
    55	function chromeAlive() {
    56	  try {
    57	    execSync(`pgrep -f "remote-debugging-port=${USER_PORT}" >/dev/null 2>&1`, { shell: "/bin/bash" });
    58	    return true;
    59	  } catch { return false; }
    60	}
    61	
    62	function haltAutomation(reason) {
    63	  log(`🚨 ${reason} → 自動化を全停止`);
    64	  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
    65	  try {
    66	    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
    67	      { shell: "/bin/bash", timeout: 60000 });
    68	  } catch {}
    69	  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
    70	  log("停止完了");
    71	}
    72	
    73	async function check() {
    74	  const now = await getTabs(USER_PORT);
    75	  let prev = {};
    76	  try { prev = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch {}
    77	
    78	  // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
    79	  if (!chromeAlive()) {
    80	    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
    81	    return { halted: true, reason: "chrome_process_gone" };
    82	  }
    83	
    84	  // CDP が一時的に重いだけなら判定しない（プロセスは生きている）
    85	  if (!now.reachable) return { ok: true, skipped: "CDP 応答なし（プロセスは生存）" };
    86	
    87	  const result = { count: now.count, prev: prev.count ?? null };
    88	
    89	  // B: 実質全部消えた
    90	  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
    91	    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
    92	    result.halted = true;
    93	  }
    94	  // C: 一度に半分以上が消えた
    95	  else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
    96	    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
    97	    result.halted = true;
    98	  }
    99	  // それ以外の増減は Jordan の通常操作。止めない。
   100	
   101	  try { fs.writeFileSync(STATE, JSON.stringify({ count: now.count, at: new Date().toISOString() }, null, 2)); } catch {}
   102	  return result;
   103	}
   104	
   105	(async () => {
   106	  if (process.argv.includes("--watch")) {
   107	    log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
   108	    for (;;) {
   109	      const r = await check();
   110	      if (r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
   111	      await new Promise(res => setTimeout(res, INTERVAL_MS));
   112	    }
   113	  } else {
   114	    console.log(JSON.stringify(await check()));
   115	  }
   116	})();
```

## 2. **1 本 載せて 60 秒 待つ**（これが決定打）

消えていれば **tab-guard が犯人で確定**。

```
  対象: comment-warmup
  載せる前: 0 本
  載せた直後（2 秒後）: **1 本**

  --- 60 秒 待つ ---
    10 秒後: 1 本
    20 秒後: 1 本
    30 秒後: 1 本
    40 秒後: 1 本
    50 秒後: 1 本
    60 秒後: 1 本

  **結論: 載ったまま生きている。** 外している主は別（または今回は起きなかった）。
```

## 3. その 60 秒に `tab-guard` は何をしたか

```
  [tab-guard.log] 更新 2026-09-12 22:29:59
  --- 末尾 25 行 ---
    [2026-09-12T13:28:57.812Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:28:57.852Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:28:58.050Z] 停止完了
    [2026-09-12T13:28:58.051Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:08.136Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:08.170Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:29:08.366Z] 停止完了
    [2026-09-12T13:29:08.366Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:18.431Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:18.457Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:29:18.636Z] 停止完了
    [2026-09-12T13:29:18.636Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:28.722Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:28.752Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:29:28.976Z] 停止完了
    [2026-09-12T13:29:28.976Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:39.089Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:39.144Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    [2026-09-12T13:29:40.532Z] 停止完了
    [2026-09-12T13:29:40.532Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:49.601Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    [2026-09-12T13:29:49.639Z] 🚨 Jordan のタブが 14 → 1 枚（一括破壊） → 自動化を全停止
    [2026-09-12T13:29:49.860Z] 停止完了
    [2026-09-12T13:29:49.861Z] 監視終了（要因を確認してください）
    [2026-09-12T13:29:59.929Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）

  --- tab-guard のロード状態 ---
    PID=5727 最後のrc=1

  --- 発火間隔 ---
      "KeepAlive" => true
      "Label" => "ai.openclaw.tab-guard"
      "ProgramArguments" => [
        0 => "/usr/local/bin/node"
        1 => "/Users/ny/.openclaw/workspace/scripts/tab-guard.js"
        2 => "--watch"
      "RunAtLoad" => true
      "StandardErrorPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard-err.log"
      "StandardOutPath" => "/Users/ny/.openclaw/workspace/logs/tab-guard.out"
      "WorkingDirectory" => "/Users/ny/.openclaw/workspace"
```

## 4. `tab-guard` は何を見て halt し続けているのか

```
  --- タブ数の記録（いま何枚だと思っているか） ---
  [tab-guard-state.json] 更新 2026-09-12 23:12
    {
      "count": 1,
      "at": "2026-09-12T14:12:34.915Z"
    }

  --- tab-guard.js が参照するファイル ---
    **有る** /Users/ny/.openclaw/workspace/data/tab-guard-state.json 09-12 23:12

  --- いま Chrome のタブは何枚 開いているか ---
    CDP から見えるページ数: 1
```

---

## 次にやること（**この結果で決まる**）

| §2 の結論 | 次の手 |
| --- | --- |
| 載るが外される | **tab-guard の halt 状態を解除する**（§1 の全文から解除条件を読む） |
| 載ったまま生きる | 外していたのは別。**§3 のログで直前に何が動いたかを見る** |
| そもそも載らない | plist か launchd の問題。**plutil -lint と権限を見る** |

**tab-guard を止めるのは、犯人だと確定してから。** 非常ブレーキは軽々に外さない。

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| 返信（**実測** 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**tab-guard を unload していない。Chrome も触っていない。投稿もしていない。**
