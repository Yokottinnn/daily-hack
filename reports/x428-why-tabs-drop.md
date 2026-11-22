# タブが急に減った原因（2026-11-07 14:14 JST・読むだけ・$0）

## ① tab-guard.js（何を数えて、いつ全停止するか）
```js
// 165 行
3: * tab-guard.js — Jordan の Chrome が「丸ごと落とされる」異常だけを検知して自動化を止める。
5: * 2026-08-09: 自動化が Chrome を pkill し、Jordan のウィンドウが全消滅する事故を起こした。
8: * 一方、タブが1〜2枚減るのは Jordan 自身の通常操作でも起きる。それで cron を止めるのは
9: * やり過ぎで無駄な停止を招く（2026-08-09 Jordan 指摘）。
11: *     A. Chrome プロセスが消えた / CDP に繋がらない（＝ウィンドウ全消滅）
13: *     C. 一度に半分以上のタブが消えた（＝一括破壊）
14: *   数枚の増減は Jordan の操作として無視する。
24:const USER_PORT = 18810;
29:const MIN_TABS = 1;              // これ未満なら異常（実質全消滅）
37:function getTabs(port) {
38:  return new Promise((resolve) => {
39:    const req = http.get({ host: "127.0.0.1", port, path: "/json/list", timeout: 8000 }, (r) => {
41:      r.on("data", c => d += c);
42:      r.on("end", () => {
44:          const list = JSON.parse(d).filter(t => t.type === "page");
49:    req.on("timeout", () => { req.destroy(); resolve({ reachable: false }); });
50:    req.on("error", () => resolve({ reachable: false }));
54:// Chrome プロセス自体が生きているか（CDP が重いだけの誤検知を避ける）
57:    execSync(`pgrep -f "remote-debugging-port=${USER_PORT}" >/dev/null 2>&1`, { shell: "/bin/bash" });
66:  // （docs/self-healing-deadlock.md 条件 3）。halt と検知はそのまま残す。
69:    execSync(`for p in ~/Library/LaunchAgents/ai.openclaw.*.plist; do case "$p" in *tab-guard*) continue;; esac; launchctl unload "$p" 2>/dev/null; done`,
72:  try { execSync(`pkill -f 'workspace/scripts/.*\\.js' 2>/dev/null || true`, { shell: "/bin/bash" }); } catch {}
81:  // A: Chrome プロセスが消えた = ウィンドウ全消滅。これが最も許容できない事象。
83:    // UNREACHABLE_GUARD (2026-09-12): **CDP に繋がらないだけで全停止しない。**
84:    // tab-guard は CDP の /json/list でタブを数えている。CDP が落ちていると
86:    // 止めてしまう。すると CDP は永久に戻らない（2026-09-08〜12 に 4 日 止まった）。
89:      log("CDP unreachable が続いている（前回も false）。消滅とみなさず halt しない");
98:    if (!aliveAt || Date.now() - aliveAt > ALIVE_WINDOW_MS) {
110:    haltAutomation("Jordan の Chrome プロセスが消滅（ウィンドウ全消え）");
114:  // CDP が一時的に重いだけなら判定しない（プロセスは生きている）
115:  if (!now.reachable) return { ok: true, skipped: "CDP 応答なし（プロセスは生存）" };
120:  if (now.count < MIN_TABS && (prev.count ?? 0) >= MIN_TABS) {
123:    // page.close() すると 1 → 0 枚になる。それを「実質全消滅」と見なすと、
127:    if (!prev || typeof prev.count !== "number" || prev.count < 3) {
131:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（実質全消滅）`);
135:  else if (prev.count >= 6 && now.count <= prev.count * CATASTROPHIC_RATIO) {
136:    haltAutomation(`Jordan のタブが ${prev.count} → ${now.count} 枚（一括破壊）`);
139:  // それ以外の増減は Jordan の通常操作。止めない。
154:(async () => {
156:    log(`tab-guard 監視開始（${INTERVAL_MS / 1000}秒間隔・全消滅/一括破壊のみ検知）`);
160:      await new Promise(res => setTimeout(res, INTERVAL_MS));
```

## ② daily-supervisor.sh（Chrome に何をするか）
```
# 172 行
7:# **「kickstart した」で終わらせない。走った証拠を取り直すところまでやる。**
27:# 監視するジョブ。**CDP が要るか**で分けている。
28:#   要る   … Chrome が健全でないと走らせても無駄
29:#   要らない … Chrome の状態に関係なく走らせてよい
30:JOBS_CDP="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup mutual-prune"
31:JOBS_NOCDP="incoming-reply-watcher pipeline-heartbeat"
40:cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }
67:  # 2. CDP。**kill しない。** ensure-chrome に任せる（自動再ログインもそこに在る）
68:  if ! cdp_ok; then
69:    if [ -x "$S/ensure-chrome.sh" ]; then
70:      ( cd "$W" && "$S/ensure-chrome.sh" ) >/dev/null 2>&1 || true
72:      cdp_ok && { fixed="$fixed cdp"; log "  CDP: ensure-chrome で健全になった"; } || log "  CDP: **まだ落ちている**"
74:      log "  CDP: ensure-chrome.sh が無い"
77:  # 3. 未ロードのジョブを載せ直す（tab-guard の全 unload からの復帰）
80:  for j in $JOBS_CDP $JOBS_NOCDP; do
83:    launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
93:    launchctl bootout "gui/${UID_NUM}/$u" >/dev/null 2>&1 || true
106:CDPOK=false; cdp_ok && CDPOK=true
109:for j in $JOBS_CDP $JOBS_NOCDP; do
110:  NEEDCDP=false
111:  case " $JOBS_CDP " in *" $j "*) NEEDCDP=true;; esac
117:    if [ "$NEEDCDP" = "true" ] && [ "$CDPOK" = "false" ]; then
118:      log "  $j: 今日 走っていないが CDP が落ちている → 走らせない"
122:        log "  $j: 今日 走っていない → kickstart (${ATT}/${MAX_FIX})"
123:        launchctl kickstart -k "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
133:  ROWS="$ROWS{\"job\":\"$j\",\"loaded\":$LOADED,\"ran_today\":$RAN,\"attempts\":$ATT,\"needs_cdp\":$NEEDCDP},"
141:  "cdp_healthy": $CDPOK,
159:          ":rotating_light: *追い上げても走らないジョブ:${NG}* ／ CDP healthy=${CDPOK}")" \
```

## ③ 全停止の前後のログ（Chrome・CDP・supervisor・tab-guard）
```
--- daily-supervisor.log
[2026-11-03T20:01:04Z]   competitor-follower-follow: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:01:49Z]   competitor-follower-follow: **走った（ログに今日の行が出た）**
[2026-11-03T20:01:49Z]   hashtag-follow: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:02:34Z]   hashtag-follow: **走った（ログに今日の行が出た）**
[2026-11-03T20:02:35Z]   mutual-prune: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:03:20Z]   mutual-prune: **走った（ログに今日の行が出た）**
[2026-11-03T20:03:20Z]   pipeline-heartbeat: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:04:05Z]   pipeline-heartbeat: **走った（ログに今日の行が出た）**
[2026-11-03T20:04:05Z] 全部 走った
[2026-11-03T20:04:05Z] === daily-supervisor done ===
[2026-11-03T20:17:23Z] === daily-supervisor start ===
[2026-11-03T20:18:45Z]   CDP: ensure-chrome で健全になった
--- ensure-chrome.log
[2026-11-03T20:05:06Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-11-03T20:18:31Z] ensure-chrome: CDP hang confirmed (3 consecutive failures) — 自動化専用 Chrome を再起動
[2026-11-03T20:18:35Z] ensure-chrome: Chrome up and CDP responsive
--- ensure-x-login.log
2026-11-03T20:03:29.898Z [main] verified logged_in
--- tab-guard.log
[2026-11-02T13:08:24.652Z] 🚨 Jordan のタブが 22 → 6 枚（一括破壊） → 自動化を全停止
[2026-11-02T13:08:25.042Z] 停止完了
[2026-11-02T13:08:25.044Z] 監視終了（要因を確認してください）
[2026-11-02T13:08:25.165Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-03T20:05:13.197Z] 🚨 Jordan のタブが 23 → 9 枚（一括破壊） → 自動化を全停止
[2026-11-03T20:05:13.823Z] 停止完了
[2026-11-03T20:05:13.895Z] 監視終了（要因を確認してください）
[2026-11-03T20:05:13.995Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
[2026-11-03T20:18:45.693Z] 🚨 Jordan のタブが 9 → 1 枚（一括破壊） → 自動化を全停止
[2026-11-03T20:18:46.012Z] 停止完了
[2026-11-03T20:18:46.013Z] 監視終了（要因を確認してください）
[2026-11-03T20:18:46.058Z] tab-guard 監視開始（30秒間隔・全消滅/一括破壊のみ検知）
--- daily-supervisor.log の 11/3 20:00Z〜20:50Z（全部）
[2026-11-03T20:00:05Z] === daily-supervisor start ===
[2026-11-03T20:00:19Z]   comment-warmup: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:01:04Z]   comment-warmup: **走った（ログに今日の行が出た）**
[2026-11-03T20:01:04Z]   competitor-follower-follow: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:01:49Z]   competitor-follower-follow: **走った（ログに今日の行が出た）**
[2026-11-03T20:01:49Z]   hashtag-follow: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:02:34Z]   hashtag-follow: **走った（ログに今日の行が出た）**
[2026-11-03T20:02:35Z]   mutual-prune: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:03:20Z]   mutual-prune: **走った（ログに今日の行が出た）**
[2026-11-03T20:03:20Z]   pipeline-heartbeat: 今日 走っていない → kickstart (1/3)
[2026-11-03T20:04:05Z]   pipeline-heartbeat: **走った（ログに今日の行が出た）**
[2026-11-03T20:04:05Z] 全部 走った
[2026-11-03T20:04:05Z] === daily-supervisor done ===
[2026-11-03T20:17:23Z] === daily-supervisor start ===
[2026-11-03T20:18:45Z]   CDP: ensure-chrome で健全になった
[2026-11-03T20:47:44Z] === daily-supervisor start ===
[2026-11-03T20:47:45Z] 全部 走った
[2026-11-03T20:47:45Z] === daily-supervisor done ===
[2026-11-04T08:00:05Z] === daily-supervisor start ===
[2026-11-04T08:00:07Z] 全部 走った
[2026-11-04T08:00:07Z] === daily-supervisor done ===
[2026-11-04T20:00:05Z] === daily-supervisor start ===
[2026-11-04T20:00:07Z]   comment-warmup: 今日 走っていない → kickstart (1/3)
[2026-11-04T20:00:52Z]   comment-warmup: **走った（ログに今日の行が出た）**
[2026-11-04T20:00:52Z]   competitor-follower-follow: 今日 走っていない → kickstart (1/3)
[2026-11-04T20:01:37Z]   competitor-follower-follow: **走った（ログに今日の行が出た）**
[2026-11-04T20:01:37Z]   hashtag-follow: 今日 走っていない → kickstart (1/3)
[2026-11-04T20:02:22Z]   hashtag-follow: **走った（ログに今日の行が出た）**
[2026-11-04T20:02:22Z]   mutual-prune: 今日 走っていない → kickstart (1/3)
[2026-11-04T20:03:08Z]   mutual-prune: **走った（ログに今日の行が出た）**
[2026-11-04T20:03:08Z]   pipeline-heartbeat: 今日 走っていない → kickstart (1/3)
[2026-11-04T20:03:53Z]   pipeline-heartbeat: **走った（ログに今日の行が出た）**
[2026-11-04T20:03:53Z] 全部 走った
[2026-11-04T20:03:53Z] === daily-supervisor done ===
[2026-11-05T08:00:05Z] === daily-supervisor start ===
[2026-11-05T08:00:15Z] 全部 走った
[2026-11-05T08:00:15Z] === daily-supervisor done ===
[2026-11-05T20:00:05Z] === daily-supervisor start ===
[2026-11-05T20:00:15Z]   comment-warmup: 今日 走っていない → kickstart (1/3)
[2026-11-05T20:01:01Z]   comment-warmup: **走った（ログに今日の行が出た）**
```

## ④ 同じ時間帯に Chrome を起動・終了したプロセスの記録（macOS のログ・90 秒で打ち切り）
```
```
