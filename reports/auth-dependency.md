# 認証の依存関係（2026-08-22T11:07:15Z）

## Q1. X 運用のジョブは何で認証しているか

### ジョブのスクリプトが API キーを読んでいるか（キー名のみ）
- asuka-fill.js: env=[process.env.RECENT_TEMPLATE_IDS ] / claude CLI 起動=0箇所 / SDK import=0箇所
- comment-warmup.js: 存在しない
- incoming-reply-watcher.js: env=[process.env.CHROME_CDP_URL ] / claude CLI 起動=0箇所 / SDK import=0箇所
- badge-followback.js: env=[process.env.BASELINE_ONLY process.env.CHROME_CDP_URL process.env.DRY_RUN process.env.HOME ] / claude CLI 起動=0箇所 / SDK import=0箇所

### plist が環境変数を渡しているか（キー名のみ・値は出さない）

### OpenClaw の .env にどのキーが「入っているか」（値は出さない）
- /Users/ny/openclaw/config/.env:
    OPENCLAW_BOT_TOKEN
    OPENCLAW_APP_TOKEN
- /Users/ny/.openclaw/workspace/.env:
    GEMINI_API_KEY
- /Users/ny/.openclaw/.env:

## Q2. Claude Code の OAuth はどこに、どう保存されているか

- ファイル: あり（/Users/ny/.claude/.credentials.json）
- 権限: -rw------- ny
- 最終更新: 2026-08-09T23:00:12Z
- 含まれるキー: accessToken authorizationServerUrl claudeAiOauth clientId discoveryState expiresAt mcpOAuth oauthMetadataFound rateLimitTier redirectUri refreshToken refreshTokenExpiresAt scopes serverName serverUrl subscriptionType 
- refreshToken の有無: あり
- expiresAt: 1786345211954
- Keychain の項目: あり

### 最終更新から見た自動更新の動き
credentials の mtime が数時間おきに動いていれば自動更新は効いている。
失効時刻の直前で止まっていれば、更新そのものが走っていない。

## Q3. なぜ更新に失敗したのか（手がかり）

### スリープ設定（寝ている間は更新が走らない）
 standby              1
 hibernatefile        /var/vm/sleepimage
 powernap             1
 networkoversleep     0
 disksleep            0
 sleep                0 (sleep prevented by coreaudiod)
 hibernatemode        3
 displaysleep         10

### 直近の再起動・スリープ履歴
   PreventSystemSleep             0
   PreventUserIdleSystemSleep     1
   pid 182(coreaudiod): [0x0000010a00018225] 289:24:02 PreventUserIdleSystemSleep named: "com.apple.audio.Buil
Kernel Assertions: 0x100=MAGICWAKE
   id=569  level=255 0x100=MAGICWAKE creat=2026/08/10 18:51  mod=2026/08/17 0:16 description=en0 owner=IOSkywa

### 認証まわりのエラー（ログ横断・直近10件）
#### incoming-reply-responder.log  更新=2026-08-10T00:47Z
  @MeY40155748: react-on
{"ok":true,"fetched":15,"replied":0,"reacted":2,"skipped":0,"fail":2,"actions":[{"id":"2074334079424795113","author":"ra
{"ok":true,"fetched":20,"replied":0,"reacted":1,"skipped":0,"fail":0,"actions":[{"id":"2085956828740178055","author":"ma
#### tab-guard.log  更新=2026-08-15T04:43Z
[2026-08-13T12:39:03.401Z] 監視終了（要因を確認してください）
[2026-08-13T14:24:29.401Z] 🚨 Jordan の Chrome プロセスが消滅（ウィンドウ全消え） → 自動化を�
[2026-08-13T14:30:12.401Z] 監視終了（要因を確認してください）
#### cookie-restore.log  更新=2026-08-06T13:28Z
2026-07-13T23:46:54+09:00 restore OK: /Users/ny/.openclaw/workspace/data/cookie-backups/2026-07-13.db → /Users/ny/.ope
2026-07-14T16:00:29+09:00 restore OK: /Users/ny/.openclaw/workspace/data/cookie-backups/2026-07-13.db → /Users/ny/.ope
2026-07-19T04:00:25+09:00 restore OK: /Users/ny/.openclaw/workspace/data/cookie-backups/2026-07-13.db → /Users/ny/.ope
#### comment-orchestrator.log  更新=2026-08-22T10:03Z
[2026-06-10T09:05:57] --- processing #9/9 for @MeY40155748 ---
[2026-06-10T09:06:13]   follow @MeY40155748: filtered
#### cost-monitor.log  更新=2026-08-10T00:32Z
[2026-05-10T18:31:00.401Z] heartbeat updated, exit OK
[2026-07-07T19:13:59.401Z] ERROR fetch-cost-csv (Slack抑制・ログのみ): Command failed: /usr/local/bin/node /Users
[2026-08-08T21:02:05.401Z] heartbeat updated, exit OK
#### blog-rss-watcher.log  更新=2026-08-10T00:28Z
[2026-07-18T00:28:27.401Z] no new items
[2026-07-27T16:36:53.401Z] fetched 62 items
[2026-08-04T23:38:42.401Z] fetched 64 items

## Q4. rc-keeper は何をしているか

- program: /Users/ny/bin/dh-rc-keeper RunAtLoad StandardErrorPath /Users/ny/.dh-rc-keeper.stderr.log StandardOutPath /Users/ny/.dh-rc-keeper.stdout.log StartInterval 
- StartInterval: 300
- rc-keeper のログ末尾:
