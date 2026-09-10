# 誰がブラウザを消しているのか

**このレポートが作られた時刻: 2026-09-10 21:38:25 JST**

> 2026-08-30 にも **タブが 19 → 1 枚**になっている（`t014`）。
> そのときは `tab-guard` が**反応した**ことまでしか分からなかった。
> **今回は「消した本体」を特定する。**

**何も触っていない。読むだけ（$0）。**

## 0. まず除外する: OS の再起動かどうか

```
  uptime: 21:38  up 22:27, 4 users, load averages: 2.05 1.80 1.69
  最後の起動: { sec = 1788963068, usec = 514770 } Wed Sep  9 23:11:08 2026

  --- 直近の再起動・シャットダウン履歴 ---
    reboot time                                Wed Sep  9 23:11
    reboot time                                Mon Aug 10 18:38
    shutdown time                              Mon Aug 10 18:38
    reboot time                                Sun Jun 21 07:55
    reboot time                                Mon May 18 23:30
    
    wtmp begins Sat Jan 17 19:34:00 JST 2026
```

**uptime が長ければ、OS の再起動ではない＝何かが能動的に落としている。**

## 1. Chrome は「いつから」動いているか

**これが決定打になる。** 起動時刻の直前に走ったジョブが犯人。

```
  --- Chrome 本体プロセス（起動時刻つき） ---
      397     1 Wed Sep  9 23:11:20 2026     22:27:05 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing
      412     1 Wed Sep  9 23:11:21 2026     22:27:04 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
      476     1 Wed Sep  9 23:11:22 2026     22:27:03 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/chrome_crashpad_handler
      479     1 Wed Sep  9 23:11:22 2026     22:27:03 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/chrome_crashpad_handler
      512   397 Wed Sep  9 23:11:22 2026     22:27:03 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome for Testing Helper.app/Contents/MacOS/Google Chrome for Testing Helper
      513   397 Wed Sep  9 23:11:22 2026     22:27:03 /Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework/Versions/140.0.7339.207/Helpers/Google Chrome for Testing Helper.app/Contents/MacOS/Google Chrome for Testing Helper

  --- CDP 付きで起動されたものだけ（--remote-debugging-port） ---

  --- 親プロセス（誰が起動したか） ---
    **CDP 付きの Chrome が見つからない（いま落ちている可能性）**
```

**etime が短ければ、最近 起動し直されている。**

## 2. `ensure-chrome.sh` は Chrome を殺すのか（**全文**）

投稿・返信ジョブが**毎回 冒頭で呼ぶ**。頻度がいちばん高い容疑者。

```bash
     1	#!/bin/bash
     2	# Ensure Chrome with --remote-debugging-port=18810 is running AND actually responsive.
     3	# Returns 0 on success (CDP コマンドが通る), 1 on failure.
     4	#
     5	# 2026-07-11 login-mode guard: lock 存在時 は Chrome 起動もしない (user 手動 login 中は Chrome を触らない)
     6	# 2026-08-06 hang detect: ポート LISTEN だけでは不十分。ハングした Chrome も
     7	#   ポートを開いたまま /json/version に 200 を返し ws ハンドシェイクも通るため、
     8	#   従来の lsof チェックはハングを "生存" と誤判定し続けた (CDP timeout ログ 18,087 件)。
     9	# 2026-08-07 誤検知/同時実行対策 (初版の設計ミス修正):
    10	#   このスクリプトは 26 本のジョブから呼ばれ同時起動が日常的に起きる。初版は
    11	#   (a) 負荷で health が 1 回転けただけで健全な Chrome を kill しかけ、
    12	#   (b) 同時呼び出しがクールダウンに当たって exit 1 → 呼び出し元が "Chrome failed" で中断
    13	#   していた。さらに現状 Chrome は cookie をディスクに永続化できていないため
    14	#   (Default/Cookies が 0 行のまま)、再起動 = 即ログアウト であり誤 kill の代償が大きい。
    15	#   → ロックで直列化し、ハングは複数回連続失敗で初めて確定、再起動後は自動再ログインする。
    16	LOCK=/tmp/x-login-in-progress
    17	if [ -f "$LOCK" ]; then
    18	  echo "ensure-chrome: login-mode-guard active, skip launch" >&2
    19	  # Chrome が動いていれば 0、 動いてなければ 0 で return (skip = 意図的な no-op)
    20	  exit 0
    21	fi
    22	
    23	PORT=18810
    24	USER_DATA=/Users/ny/.openclaw/browser/cft-profile
    25	CHROME=/Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google\ Chrome\ for\ Testing.app/Contents/MacOS/Google\ Chrome\ for\ Testing
    26	NODE=/usr/local/bin/node
    27	WS=/Users/ny/.openclaw/workspace
    28	HEALTH="$WS/scripts/cdp-health.js"
    29	LOG="$WS/logs/ensure-chrome.log"
    30	LOCKDIR=/tmp/ensure-chrome.lock
    31	LOCK_STALE=240        # ロック放置の掃除しきい値(秒)
    32	CONFIRM_TRIES=3       # ハング確定に必要な連続失敗回数
    33	CONFIRM_WAIT=8        # 確認の間隔(秒)
    34	WAIT_FOR_PEER=150     # 他インスタンスが修復中のとき待つ上限(秒)
    35	
    36	log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ensure-chrome: $*" >> "$LOG" 2>/dev/null; }
    37	
    38	port_listening() { /usr/sbin/lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; }
    39	cdp_healthy() { "$NODE" "$HEALTH" >/dev/null 2>&1; }
    40	
    41	# 健全になるまで最大 $1 秒待つ
    42	wait_healthy() {
    43	  local limit=$1 i=0
    44	  while [ $i -lt "$limit" ]; do
    45	    port_listening && cdp_healthy && return 0
    46	    sleep 3; i=$((i + 3))
    47	  done
    48	  return 1
    49	}
    50	
    51	acquire_lock() {
    52	  # 放置ロックの掃除 (修復中に kill されたケース)
    53	  if [ -d "$LOCKDIR" ]; then
    54	    local age
    55	    age=$(( $(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || echo 0) ))
    56	    [ "$age" -gt "$LOCK_STALE" ] && rmdir "$LOCKDIR" 2>/dev/null
    57	  fi
    58	  mkdir "$LOCKDIR" 2>/dev/null
    59	}
    60	release_lock() { rmdir "$LOCKDIR" 2>/dev/null; }
    61	
    62	kill_chrome() {
    63	  pkill -f "remote-debugging-port=$PORT" 2>/dev/null
    64	  for _ in $(seq 1 10); do
    65	    pgrep -f "remote-debugging-port=$PORT" >/dev/null 2>&1 || return 0
    66	    sleep 1
    67	  done
    68	  pkill -9 -f "remote-debugging-port=$PORT" 2>/dev/null
    69	  sleep 2
    70	}
    71	
    72	# 2026-08-07: 起動方法を nohup 直実行から `open -n -a` に変更した。
    73	#   SSH / launchd から Chrome を直接 exec すると GUI (Aqua) セッションの外で動くため
    74	#   login keychain の "Chrome Safe Storage" を読めず (`security show-keychain-info` が
    75	#   "User interaction is not allowed."), cookie を暗号化できずディスクに 1 件も書けなかった。
    76	#   結果 セッションがメモリ上にしか存在せず、Chrome の再起動や自動アップデートのたびに
    77	#   X からログアウトしていた (Default/Cookies が 8/2 以降 0 行のまま)。
    78	#   実測: 直接 exec = 0 件 / `open -n -a` = 永続化成功。open は launchservicesd 経由で
    79	#   GUI セッションに起動を委譲するので keychain が使える。
    80	launch_chrome() {
    81	  rm -f "$USER_DATA"/Singleton* 2>/dev/null
    82	  open -n -a "/Users/ny/.openclaw/browser/cft-140/chrome-mac-arm64/Google Chrome for Testing.app" --args \
    83	    "--remote-debugging-port=$PORT" "--remote-allow-origins=*" --remote-debugging-address=127.0.0.1 \
    84	    "--user-data-dir=$USER_DATA" \
    85	    --no-first-run \
    86	    --no-default-browser-check \
    87	    --disable-sync \
    88	    --disable-background-networking \
    89	    --disable-component-update \
    90	    --disable-features=Translate,MediaRouter \
    91	    --disable-session-crashed-bubble \
    92	    --hide-crash-restore-bubble \
    93	    --no-proxy-server \
    94	    >/dev/null 2>&1
    95	}
    96	
    97	logged_in() {
    98	  "$NODE" -e '
    99	const {chromium}=require("playwright-core");
   100	(async()=>{const b=await chromium.connectOverCDP("http://127.0.0.1:'"$PORT"'",{timeout:15000});
   101	const c=await b.contexts()[0].cookies("https://x.com");
   102	const ok=c.some(x=>x.name==="auth_token");await b.close();process.exit(ok?0:1);})()
   103	.catch(()=>process.exit(1));' >/dev/null 2>&1
   104	}
   105	
   106	# 再起動は必ずログアウトを伴う (cookie がメモリ上にしか無いため) → 自動で入り直す。
   107	# ただし短時間に何度もログインすると X に不審検知される (2026-08-07 に knowledge_check が
   108	# 挟まるようになった実績あり)。このスクリプトは 26 本のジョブから呼ばれるため、
   109	# 最短間隔を跨がない限り再ログインしない。
   110	RELOGIN_STAMP=/tmp/x-relogin-last
   111	RELOGIN_MIN_GAP=1200   # 20 分
   112	relogin_if_needed() {
   113	  logged_in && return 0
   114	  local now last
   115	  now=$(date +%s); last=$(cat "$RELOGIN_STAMP" 2>/dev/null || echo 0)
   116	  if [ $((now - last)) -lt $RELOGIN_MIN_GAP ]; then
   117	    log "logged out but re-login throttled ($((now - last))s < ${RELOGIN_MIN_GAP}s) — skip"
   118	    return 0
   119	  fi
   120	  echo "$now" > "$RELOGIN_STAMP" 2>/dev/null
   121	  log "logged out after restart — running x-login.js"
   122	  if "$NODE" "$WS/scripts/x-login.js" >/dev/null 2>&1 && logged_in; then
   123	    log "re-login OK"
   124	  else
   125	    log "re-login FAILED — manual login required"
   126	  fi
   127	}
   128	
   129	# ---- 通常経路: 健全ならそのまま抜ける ----
   130	if port_listening && cdp_healthy; then
   131	  # 2026-06-09: 残骸タブ掃除（8枚超の異常蓄積時のみ発火・進行中の投稿は巻き込まない）
   132	  # 2026-08-09: タブ掃除を停止。Jordan の作業ウィンドウを消す事故を三度起こしたため。
   133	  exit 0
   134	fi
   135	
   136	# ---- 修復が要る。ロックを取れた 1 本だけが実際に手を下す ----
   137	if ! acquire_lock; then
   138	  # 別インスタンスが修復中。待てば直るので落とさない (初版はここで exit 1 して呼び出し元を殺していた)
   139	  if wait_healthy "$WAIT_FOR_PEER"; then exit 0; fi
   140	  log "peer repair did not finish within ${WAIT_FOR_PEER}s"
   141	  exit 1
   142	fi
   143	trap 'release_lock' EXIT
   144	
   145	if port_listening; then
   146	  # 負荷で 1 回転けただけの健全 Chrome を殺さないよう、連続失敗で初めてハング確定
   147	  confirmed=1
   148	  for i in $(seq 1 $CONFIRM_TRIES); do
   149	    if cdp_healthy; then confirmed=0; break; fi
   150	    [ "$i" -lt "$CONFIRM_TRIES" ] && sleep "$CONFIRM_WAIT"
   151	  done
   152	  if [ "$confirmed" -eq 0 ]; then
   153	    exit 0   # 一時的に詰まっていただけ。再起動しない
   154	  fi
   155	  # 2026-08-10: 自動再起動を再有効化。
   156	  #   一度は全面停止したが、それは Jordan の作業 Chrome と自動化が同居していた頃の話。
   157	  #   現在 自動化は専用プロファイル (~/.openclaw/browser/automation) の
   158	  #   別プロセス (ポート 18810) で動いており、これを再起動しても Jordan の
   159	  #   Chrome (18800) には一切影響しない。
   160	  #   逆に再起動しないと CDP ハング時に復旧できず、ガーディアンが 15 分ごとに
   161	  #   同じ失敗を通知し続ける（2026-08-10 Jordan から「通知がうざい」と指摘）。
   162	  #   安全確認: kill 対象は remote-debugging-port=$PORT のみ。$PORT は 18810。
   163	  if [ "$PORT" = "18800" ]; then
   164	    log "PORT=18800 は Jordan の Chrome。安全のため kill しない"
   165	    exit 1
   166	  fi
   167	  log "CDP hang confirmed (${CONFIRM_TRIES} consecutive failures) — 自動化専用 Chrome を再起動"
   168	  kill_chrome
   169	fi
   170	
   171	launch_chrome
   172	if wait_healthy 45; then
   173	  log "Chrome up and CDP responsive"
   174	  relogin_if_needed
   175	  exit 0
   176	fi
   177	
   178	log "Chrome failed to become CDP-responsive within 45s"
   179	echo "ensure-chrome: Chrome failed to become CDP-responsive within 45s" >&2
   180	exit 1
```

## 3. `chrome-cdp-heal` の中身とログ

「治す」方法が「殺して起動し直す」なら、これも本体。

### 3-a. plist（何を、いつ走らせるか）
```
    "Label" => "ai.openclaw.chrome-cdp-heal"
    "ProgramArguments" => [
      0 => "/bin/bash"
      1 => "/Users/ny/openclaw/chrome-cdp-heal.sh"
    "RunAtLoad" => false
    "StandardErrorPath" => "/Users/ny/openclaw/chrome-cdp-heal.stderr.log"
    "StandardOutPath" => "/Users/ny/openclaw/chrome-cdp-heal.stdout.log"
    "StartInterval" => 300
```

### 3-b. 実体スクリプト（**kill / pkill / launch を探す**）
```bash
```

### 3-c. ログ（**いつ発火したか**）
```
```

## 4. `tab-guard.js` — 検知側か、消した側か

### 4-a. **自分でタブや Chrome を閉じる分岐があるか**
```javascript
  5: * 2026-08-09: 自動化が Chrome を pkill し、Jordan のウィンドウが全消滅する事故を起こした。
  66:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
  69:  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
```

### 4-b. しきい値と発火条件
```javascript
  13: *     C. 一度に半分以上のタブが消えた（＝一括破壊）
  29:const MIN_TABS = 1;              // これ未満なら異常（実質全消滅）
  62:function haltAutomation(reason) {
  80:    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
  90:  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
  91:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
  96:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
  107:    log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
```

### 4-c. ログ（**タブ数の推移**）
```
  [tab-guard.log]  更新 2026-09-10 21:38
  --- タブ数の記録・停止イベント（直近 40 行） ---
    151538:[2026-09-10T12:36:03.829Z] 停止完了
    151540:[2026-09-10T12:36:13.909Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151541:[2026-09-10T12:36:13.941Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151542:[2026-09-10T12:36:14.195Z] 停止完了
    151544:[2026-09-10T12:36:24.268Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151545:[2026-09-10T12:36:24.301Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151546:[2026-09-10T12:36:24.556Z] 停止完了
    151548:[2026-09-10T12:36:34.634Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151549:[2026-09-10T12:36:34.666Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151550:[2026-09-10T12:36:34.920Z] 停止完了
    151552:[2026-09-10T12:36:45.003Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151553:[2026-09-10T12:36:45.035Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151554:[2026-09-10T12:36:45.291Z] 停止完了
    151556:[2026-09-10T12:36:55.372Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151557:[2026-09-10T12:36:55.404Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151558:[2026-09-10T12:36:55.660Z] 停止完了
    151560:[2026-09-10T12:37:05.737Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151561:[2026-09-10T12:37:05.768Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151562:[2026-09-10T12:37:06.023Z] 停止完了
    151564:[2026-09-10T12:37:16.099Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151565:[2026-09-10T12:37:16.131Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151566:[2026-09-10T12:37:16.390Z] 停止完了
    151568:[2026-09-10T12:37:26.470Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151569:[2026-09-10T12:37:26.502Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151570:[2026-09-10T12:37:26.758Z] 停止完了
    151572:[2026-09-10T12:37:36.838Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151573:[2026-09-10T12:37:36.870Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151574:[2026-09-10T12:37:37.124Z] 停止完了
    151576:[2026-09-10T12:37:47.206Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151577:[2026-09-10T12:37:47.239Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151578:[2026-09-10T12:37:47.492Z] 停止完了
    151580:[2026-09-10T12:37:57.568Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151581:[2026-09-10T12:37:57.600Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151582:[2026-09-10T12:37:57.856Z] 停止完了
    151584:[2026-09-10T12:38:07.942Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151585:[2026-09-10T12:38:07.975Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151586:[2026-09-10T12:38:08.233Z] 停止完了
    151588:[2026-09-10T12:38:18.314Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
    151589:[2026-09-10T12:38:18.346Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を全停止
    151590:[2026-09-10T12:38:18.603Z] 停止完了
```

## 5. `browser.close()` を呼んでいるスクリプトを全部 洗う

**`connectOverCDP` した接続で `browser.close()` を呼ぶと、Chrome 本体が落ちる。**
Playwright でいちばん多い事故。**該当があれば、それが犯人。**

```javascript
/Users/ny/.openclaw/workspace/scripts/delete-tweet.js.bak.20260809:79:        await page.close(); await browser.close();
/Users/ny/.openclaw/workspace/scripts/delete-tweet.js.bak.20260809:91:        await page.close(); await browser.close();
/Users/ny/.openclaw/workspace/scripts/delete-tweet.js.bak.20260809:98:    await page.close(); await browser.close();
/Users/ny/.openclaw/workspace/scripts/delete-tweet.js.bak.20260809:104:    try { await browser.close(); } catch {}
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js.bak.pinfix.1778638096771:83:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-via-playwright.js.bak.pinfix.1778638096771:94:    if (browser) try { await browser.close(); } catch {}
/Users/ny/.openclaw/workspace/scripts/sc-probe-star2.js.bak18800:60:  await browser.close().catch(()=>{});
/Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js:160:  await browser.close();
/Users/ny/.openclaw/workspace/scripts/probe-upload-flow.js.bak18800:67:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/extract-render-v2.js:72:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-qt-manual.js:62:    if (browser) await browser.close().catch(() => {});
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js.bak.20260607-image:167:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js.bak.20260607-image:185:    if (browser) try { await browser.close(); } catch {}
/Users/ny/.openclaw/workspace/scripts/probe-followback-truth.js.bak18800:50:  await page.close(); await browser.close();
/Users/ny/.openclaw/workspace/scripts/capture-design-v3.js:53:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-publish-watchdog.js.bak18800:78:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-publish-watchdog.js.bak18800:88:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-publish-watchdog.js.bak18800:108:  await browser.close();
/Users/ny/.openclaw/workspace/scripts/gen-card-design-v2.js:400:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-pinned-tweet.js.bak.20260612-textsafety:150:    await browser.close();
/Users/ny/.openclaw/workspace/scripts/post-pinned-tweet.js.bak.20260612-textsafety:156:    if (browser) try { await browser.close(); } catch {}
/Users/ny/.openclaw/workspace/scripts/delete-tweets.js.bak.20260612-safedelete:86:  await browser.close();
/Users/ny/.openclaw/workspace/scripts/qt-past-articles-orchestrator.sh.bak18800:83:  await p.close();await b.close();
/Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js:53:  await browser.close();
/Users/ny/.openclaw/workspace/scripts/check-followback.js.bak.20260613-cdp-retry:46:  await browser.close();
  ---（上が空なら browser.close() は無い）---

  # connectOverCDP を使っているファイル一覧
  /Users/ny/.openclaw/workspace/scripts/delete-tweet.js.bak.20260809
  /Users/ny/.openclaw/workspace/scripts/post-via-playwright.js.bak.pinfix.1778638096771
  /Users/ny/.openclaw/workspace/scripts/sc-probe-star2.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/incoming-reply-watcher.js
  /Users/ny/.openclaw/workspace/scripts/probe-upload-flow.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/extract-render-v2.js
  /Users/ny/.openclaw/workspace/scripts/post-qt-manual.js
  /Users/ny/.openclaw/workspace/scripts/post-quote-tweet.js.bak.20260607-image
  /Users/ny/.openclaw/workspace/scripts/probe-followback-truth.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/capture-design-v3.js
  /Users/ny/.openclaw/workspace/scripts/post-publish-watchdog.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/gen-card-design-v2.js
  /Users/ny/.openclaw/workspace/scripts/post-pinned-tweet.js.bak.20260612-textsafety
  /Users/ny/.openclaw/workspace/scripts/delete-tweets.js.bak.20260612-safedelete
  /Users/ny/.openclaw/workspace/scripts/qt-past-articles-orchestrator.sh.bak18800
  /Users/ny/.openclaw/workspace/scripts/monthly-kpi-report.js
  /Users/ny/.openclaw/workspace/scripts/tmp-verify-x-post.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/check-followback.js.bak.20260613-cdp-retry
  /Users/ny/.openclaw/workspace/scripts/sc-screenshot-memo-edit.js.bak18800
  /Users/ny/.openclaw/workspace/scripts/sc-probe-star.js
```

## 6. `work-window.js` はタブをどう扱うか

```javascript
  6: * 勝手にタブを開き、bringToFront で画面まで奪う事故を繰り返した。
  13: *   4. bringToFront は呼ばない（画面を奪わない）
  37:async function openWorkTab(task, opts = {}) {
  39:    throw new Error("openWorkTab: task 名は必須");
  75:    try { await browser.close(); } catch {}
  76:    throw new Error(`openWorkTab: 保護ウィンドウ(${wid})にタブが作られたため中止・削除しました`);
  89:    try { await browser.close(); } catch {}
  90:    throw new Error("openWorkTab: 作成タブを特定できず中止（他タブには触れていません）");
  112:      try { await browser.close(); } catch {}
  117:module.exports = { openWorkTab, protectedWindows };
```

## 7. 時刻の突き合わせ（**Chrome 起動の直前に何が走ったか**）

Chrome の起動時刻の前後 10 分に書かれたログ行を集める。

```
  Chrome の起動時刻: (取得できない)

```

### 直近 24 時間に更新されたログ（**動いていたものが分かる**）

```
  tab-guard.log                          09-10 21:38
  cost-monitor.log                       09-09 23:03
  cookie-backup.log                      09-09 22:00
  fire-watchdog.log                      09-09 22:59
  ops-heartbeat.log                      09-10 21:18
  ensure-x-login.log                     09-09 22:00
  comment-warmup.log                     09-09 22:03
  poll-approvals.log                     09-09 22:46
  slack-watchdog.log                     09-09 23:11
  pipeline-guardian.log                  09-09 22:59
  ops-heartbeat-err.log                  09-10 21:18
  comment-warmup-err.log                 09-09 22:03
  cost-monitor-health.log                09-09 21:59
  import-manual-image.log                09-09 22:59
  cost-monitor-stdout.log                09-09 23:03
  comment-orchestrator.log               09-09 22:03
  daily-follow-summary.log               09-09 23:00
  incoming-reply-watcher.log             09-09 23:03
  reply-followers-cleanup.log            09-09 22:34
  daily-follow-summary-err.log           09-09 23:00
  auto-detect-and-unfollow-inactive.log  09-09 22:30
```

---

**Chrome を触っていない。タブも開いていない。ジョブも触っていない（$0）。**
