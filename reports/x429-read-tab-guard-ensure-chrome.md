# tab-guard.js と ensure-chrome.sh を読む（2026-11-07 14:27 JST・読むだけ・$0）

## tab-guard.js（全文）
```js
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
    64	  // LOCK_WRITE_DISABLED (2026-09-13): このロックは ensure-chrome.sh を no-op に
    65	  // して Chrome の起動を塞ぎ、tab-guard 自身の halt 条件を永久に成立させ続けた
    66	  // （docs/self-healing-deadlock.md 条件 3）。halt と検知はそのまま残す。
    67	  // try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}
    68	  try {
    69	    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
    70	      { shell: "/bin/bash", timeout: 60000 });
    71	  } catch {}
    72	  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
    73	  log("停止完了");
    74	}
    75	
    76	async function check() {
    77	  const now = await getTabs(USER_PORT);
    78	  let prev = {};
    79	  try { prev = JSON.parse(fs.readFileSync(STATE, "utf8")); } catch {}
    80	
    81	  // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
    82	  if (!chromeAlive()) {
    83	    // UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**
    84	    // tab-guard は CDP の /json/list でタブを数えている。CDP が落ちていると
    85	    // 「利用者がウィンドウを全部 閉じた」と誤判定し、Chrome を起動するジョブごと
    86	    // 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。
    87	    // **前回も繋がっていなかったなら、それは「消滅」ではなく「まだ落ちたまま」。**
    88	    if (prev && prev.reachable === false) {
    89	      log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
    90	      return;
    91	    }
    92	    // BOOT_GRACE (2026-09-20 x89): **起動直後は停めない。**
    93	    // 再起動すれば Chrome プロセスは必ず消えるため、この条件を毎回 踏んでいた。
    94	    // 2026-09-12 と 2026-09-20 に、これで ai.openclaw.* が全滅した。
    95	    // **「一度 生きていたのに消えた」ときだけ止める。**
    96	    const aliveAt = prev && prev.chrome_alive_at ? Date.parse(prev.chrome_alive_at) : 0;
    97	    const ALIVE_WINDOW_MS = 15 * 60 * 1000;
    98	    if (!aliveAt || Date.now() - aliveAt > ALIVE_WINDOW_MS) {
    99	      log("Chrome を最近 生きている状態で見ていない（起動直後など）。消滅とみなさず halt しない");
   100	      try {
   101	        fs.writeFileSync(STATE, JSON.stringify({
   102	          count: 0,
   103	          reachable: false,
   104	          chrome_alive_at: (prev && prev.chrome_alive_at) || null,
   105	          at: new Date().toISOString(),
   106	        }, null, 2));
   107	      } catch {}
   108	      return;
   109	    }
   110	    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
   111	    return { halted: true, reason: "chrome_process_gone" };
   112	  }
   113	
   114	  // CDP が一時的に重いだけなら判定しない（プロセスは生きている）
   115	  if (!now.reachable) return { ok: true, skipped: "CDP 応答なし（プロセスは生存）" };
   116	
   117	  const result = { count: now.count, prev: prev.count ?? null };
   118	
   119	  // B: 実質全部消えた
   120	  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
   121	    // LOW_BASELINE_GUARD (2026-09-13): **元が 1 枚なら「全部 消えた」ではない。**
   122	    // 自動化専用 Chrome は起動直後 1 タブしかなく、スクリプトが作業タブを
   123	    // page.close() すると 1 → 0 枚になる。それを「実質全消滅」と見なすと、
   124	    // **自動化そのものが自動化を止める**（2026-09-12 15:24 に実際に起きた）。
   125	    // B は「たくさんあったものが 0〜1 枚になった」を想定した条件。
   126	    // **前回が 3 枚未満なら、そもそも破壊の前提が無い。**
   127	    if (!prev || typeof prev.count !== "number" || prev.count < 3) {
   128	      log(`タブ ${prev && prev.count} → ${now.count} 枚。元が少ないので破壊とみなさない`);
   129	      return;
   130	    }
   131	    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
   132	    result.halted = true;
   133	  }
   134	  // C: 一度に半分以上が消えた
   135	  else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
   136	    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
   137	    result.halted = true;
   138	  }
   139	  // それ以外の増減は Jordan の通常操作。止めない。
   140	
   141	  // x89: **`reachable` を保存していなかったため、88 行 のガードが死んでいた。**
   142	  // ここまで来た時点で Chrome は生きているので `chrome_alive_at` も打つ。
   143	  try {
   144	    fs.writeFileSync(STATE, JSON.stringify({
   145	      count: now.count,
   146	      reachable: now.reachable === true,
   147	      chrome_alive_at: new Date().toISOString(),
   148	      at: new Date().toISOString(),
   149	    }, null, 2));
   150	  } catch {}
   151	  return result;
   152	}
   153	
   154	(async () => {
   155	  if (process.argv.includes("--watch")) {
   156	    log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
   157	    for (;;) {
   158	      const r = await check();
   159	      if (r && r.halted) { log("監視終了（要因を確認してください）"); process.exit(1); }
   160	      await new Promise(res => setTimeout(res, INTERVAL_MS));
   161	    }
   162	  } else {
   163	    console.log(JSON.stringify(await check()));
   164	  }
   165	})();
```

## ensure-chrome.sh（再起動の前後）
```bash
# 180 行
     1	}
     2	
     3	# ---- 通常経路: 健全ならそのまま抜ける ----
     4	if port_listening && cdp_healthy; then
     5	  # 2026-06-09: 残骸タブ掃除（8枚超の異常蓄積時のみ発火・進行中の投稿は巻き込まない）
     6	  # 2026-08-09: タブ掃除を停止。Jordan の作業ウィンドウを消す事故を三度起こしたため。
     7	  exit 0
     8	fi
     9	
    10	# ---- 修復が要る。ロックを取れた 1 本だけが実際に手を下す ----
    11	if ! acquire_lock; then
    12	  # 別インスタンスが修復中。待てば直るので落とさない (初版はここで exit 1 して呼び出し元を殺していた)
    13	  if wait_healthy "$WAIT_FOR_PEER"; then exit 0; fi
    14	  log "peer repair did not finish within ${WAIT_FOR_PEER}s"
    15	  exit 1
    16	fi
    17	trap 'release_lock' EXIT
    18	
    19	if port_listening; then
    20	  # 負荷で 1 回転けただけの健全 Chrome を殺さないよう、連続失敗で初めてハング確定
    21	  confirmed=1
    22	  for i in $(seq 1 $CONFIRM_TRIES); do
    23	    if cdp_healthy; then confirmed=0; break; fi
    24	    [ "$i" -lt "$CONFIRM_TRIES" ] && sleep "$CONFIRM_WAIT"
    25	  done
    26	  if [ "$confirmed" -eq 0 ]; then
    27	    exit 0   # 一時的に詰まっていただけ。再起動しない
    28	  fi
    29	  # 2026-08-10: 自動再起動を再有効化。
    30	  #   一度は全面停止したが、それは Jordan の作業 Chrome と自動化が同居していた頃の話。
    31	  #   現在 自動化は専用プロファイル (~/.openclaw/browser/automation) の
    32	  #   別プロセス (ポート 18810) で動いており、これを再起動しても Jordan の
    33	  #   Chrome (18800) には一切影響しない。
    34	  #   逆に再起動しないと CDP ハング時に復旧できず、ガーディアンが 15 分ごとに
    35	  #   同じ失敗を通知し続ける（2026-08-10 Jordan から「通知がうざい」と指摘）。
    36	  #   安全確認: kill 対象は remote-debugging-port=$PORT のみ。$PORT は 18810。
    37	  if [ "$PORT" = "18800" ]; then
    38	    log "PORT=18800 は Jordan の Chrome。安全のため kill しない"
    39	    exit 1
    40	  fi
    41	  log "CDP hang confirmed (${CONFIRM_TRIES} consecutive failures) — 自動化専用 Chrome を再起動"
    42	  kill_chrome
    43	fi
    44	
    45	launch_chrome
    46	if wait_healthy 45; then
    47	  log "Chrome up and CDP responsive"
    48	  relogin_if_needed
    49	  exit 0
    50	fi
    51	
    52	log "Chrome failed to become CDP-responsive within 45s"
    53	echo "ensure-chrome: Chrome failed to become CDP-responsive within 45s" >&2
    54	exit 1
```

## どのポートの Chrome か
```
2:# Ensure Chrome with --remote-debugging-port=18810 is running AND actually responsive.
23:PORT=18810
63:  pkill -f "remote-debugging-port=$PORT" 2>/dev/null
65:    pgrep -f "remote-debugging-port=$PORT" >/dev/null 2>&1 || return 0
68:  pkill -9 -f "remote-debugging-port=$PORT" 2>/dev/null
83:    "--remote-debugging-port=$PORT" "--remote-allow-origins=*" --remote-debugging-address=127.0.0.1 \
84:    "--user-data-dir=$USER_DATA" \
158:  #   別プロセス (ポート 18810) で動いており、これを再起動しても Jordan の
162:  #   安全確認: kill 対象は remote-debugging-port=$PORT のみ。$PORT は 18810。
12317 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome
13623 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome
54346 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome
71954 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome
92479 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing --remote-debugging-port=18810 --remote-allow-origins=* --remote-debugg
```
