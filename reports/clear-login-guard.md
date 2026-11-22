# `login-mode-guard` を外して Chrome を戻す

**このレポートが作られた時刻: 2026-09-10 22:22:47 JST**

> `x24` の実測: **`ensure-chrome: login-mode-guard active, skip launch`**
> **Chrome が起動していない。** だから CDP も無く、3 ループが全部 空振りしている。

## 1. `ensure-chrome.sh` は何を見て起動を拒否しているか

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

### guard に関わる行だけ抜き出す

```bash
  5:# 2026-07-11 login-mode guard: lock 存在時 は Chrome 起動もしない (user 手動 login 中は Chrome を触らない)
  18:  echo "ensure-chrome: login-mode-guard active, skip launch" >&2
```

## 2. guard のフラグ実体（**何が立っているのか**）

```
  --- ensure-chrome.sh から拾った候補 ---
    $RELOGIN_MIN_GAP
    $RELOGIN_STAMP
    $WS/scripts/x-login.js
    ensure-chrome: login-mode-guard active, skip launch
    logged out after restart — running x-login.js
    logged out but re-login throttled ($((now - last))s < ${RELOGIN_MIN_GAP}s) — skip
    login-mode
    re-login FAILED — manual login required
    re-login OK

  --- 実在するフラグファイル ---
    候補の場所には見つからない（環境変数か、別の判定かもしれない）

  --- login-mode という名前のファイルを workspace から探す ---
    /Users/ny/.openclaw/workspace/scripts/restore-cookies-and-relaunch.sh.bak.20260711-login-mode-guard 07-11 19:06
    /Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh.bak.20260711-login-mode-guard 07-11 19:06
    /Users/ny/.openclaw/workspace/scripts/cookie-restore.sh.bak.20260711-login-mode-guard 07-11 19:06
```

## 3. cookie のバックアップ

```
  /Users/ny/.openclaw/workspace/data/cookie-backups
    2026-09-09.db               217088 B  2026-09-09 22:00
    2026-09-08.db               217088 B  2026-09-08 22:00
    2026-09-07.db               217088 B  2026-09-08 00:00
    2026-08-10.db               217088 B  2026-08-10 04:00
    2026-08-09.db               217088 B  2026-08-09 22:00
    2026-08-08.db               208896 B  2026-08-08 22:00
    2026-08-07.db                28672 B  2026-08-07 22:00

  --- いま使われている cookie の実体 ---
```

**バックアップが auth 失効（2026-09-10 10:11 UTC）より前なら、戻しても切れている。**
**9/09 のものが失効前なら、戻す価値がある。**

## 4. guard を外す（**退避してから**）

**消さない。名前を変えて退避する。** 元に戻せる形にしておく。

```
  フラグファイルが特定できていないので、**触らない**。
  上の §1 全文から、判定が環境変数かどうかを読む必要がある。
```

## 5. Chrome を起動して CDP を確かめる

```
  --- ensure-chrome.sh をもう一度 ---
    ensure-chrome: login-mode-guard active, skip launch
    (rc=0)

  --- CDP の健全性（ポートの LISTEN では足りない） ---
    {"ok":false,"healthy":false,"reason":"port_closed","detail":"Chrome not running","port":18810}

  --- Chrome のプロセス ---
```

## 6. X にログインできているか

**前回は `node -e` を cwd `/` で走らせて `MODULE_NOT_FOUND` になった。**
`playwright-core` は `workspace/node_modules` にあるので、
**一時 js を `scripts/` に置いて実行する。**

```
    CDP に繋がらない: browserType.connectOverCDP: Invalid URL
```

---

## この先どうするか

| 上の結果 | 次にやること |
| --- | --- |
| ログイン **生きている** | **復旧完了。** 次の定時実行（12/16/19/22 時）から 3 ループが動く |
| ログイン **切れている** | cookie バックアップからの復元を試すか、**PC での再ログインが要る** |
| CDP が繋がらない | guard 以外の理由で Chrome が起動できていない。§1 の全文を読み直す |

## コスト（最上位ルール 2-B）

単価は `claude-api` スキルの料金表（Haiku 4.5 入力 $1.00 / **出力 $5.00** per MTok）。

| | 1 回 | 1 日 | 1 か月 |
| --- | --- | --- | --- |
| **この タスク**（LLM 不使用） | **$0** | **$0** | **$0** |
| フォロー・アンフォロー（DOM 操作） | **$0** | **$0** | **$0** |
| 返信（実測 9/8=5 件・9/9=3 件） | $0.003 | $0.009〜0.015 | 約 $0.27〜0.45 |

**投稿・返信・フォロー・アンフォローのいずれもしていない。cookie も消していない。**
