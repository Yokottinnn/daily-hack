# 返信の配管を実物で読む（2026-09-06 20:15 JST・費用 $0）

> **戻すだけでは直らない。** 9/2 に「テンプレ当てはめ → 全文生成」の
> 差し替えを途中でやめており、**どこまで配線されたかが分かっていない。**
> 知らないまま load すると**古い経路で返信が出る。**それは
> 『トンチンカン』『AI が自動で返信しているのがバレバレ』の状態に戻すということ。
> **返信しない。投稿しない。ジョブを触らない。LLM も呼ばない。**

## 1. 新しい部品は入っているか

```
  **無し** asuka-reply.cjs            
  **無し** reply-relevance-check.cjs  
  有り  tone-gate.cjs                    4611 B  更新 2026-08-29 00:51
  有り  ng-filter-candidates.cjs         3177 B  更新 2026-08-27 22:38
  有り  reply-ng-check.cjs               3006 B  更新 2026-08-27 22:38
  有り  reply-tone-check.cjs             3220 B  更新 2026-08-29 00:51
  有り  asuka-fill.js                    9654 B  更新 2026-08-15 16:38
  有り  comment-orchestrator.sh          8693 B  更新 2026-08-29 00:51
  有り  auto-reply.js                    9127 B  更新 2026-07-26 21:04
  有り  anthropic-client.js              4175 B  更新 2026-05-09 23:56

  データ:
  **無し** reply-style-prompt.json    
  **無し** reply-relevance-rules.json 
  有り  reply-ng-rules.json              4160 B  更新 2026-08-28 00:40
  有り  reply-tone-rules.json            3572 B  更新 2026-08-29 00:51
  有り  comment-templates.json           7585 B  更新 2026-08-28 00:40
```

**`asuka-reply.cjs` が無ければ、全文生成はまだ Mac に届いていない。**

## 2. `comment-orchestrator.sh` の全文

**どの生成器を叩いているかがここで決まる。**

```bash
     1	#!/bin/bash
     2	# comment-orchestrator.sh (v3 2026-05-13: reply連動 follow E案追加)
     3	# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
     4	set -e
     5	
     6	WS=/Users/ny/.openclaw/workspace
     7	SCRIPTS=$WS/scripts
     8	LOG=$WS/logs/comment-orchestrator.log
     9	MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
    10	REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}
    11	
    12	ts() { date "+%Y-%m-%dT%H:%M:%S"; }
    13	log() { echo "[$(ts)] $*" | tee -a "$LOG"; }
    14	
    15	CONFIG=/Users/ny/.openclaw/openclaw.json
    16	eval "$(/usr/local/bin/node -e "
    17	const c = require('$CONFIG');
    18	console.log('export SLACK_BOT_TOKEN=' + JSON.stringify((c.channels && c.channels.slack && c.channels.slack.botToken) || ''));
    19	")"
    20	export PATH="/usr/local/bin:$PATH"
    21	
    22	log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="
    23	
    24	CAN=$(/usr/local/bin/node $SCRIPTS/comment-state.js can-comment 2>&1)
    25	CAN_OK=$(echo "$CAN" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
    26	if [ "$CAN_OK" != "true" ]; then
    27	  log "global limit: $CAN"
    28	  exit 0
    29	fi
    30	
    31	$SCRIPTS/ensure-chrome.sh || { log "Chrome failed"; exit 1; }
    32	
    33	cd $WS
    34	# 2026-08-07: 以前は 2>&1 で stderr を混ぜたまま JSON.parse していたため、trend-detect が
    35	# 進捗行やエラー行 (例: "hashtag 還元 failed: timeout 12000ms") を出すと SyntaxError で
    36	# ジョブごと落ちていた。stderr はログに流し、stdout から JSON 行だけを拾う。
    37	DETECT_OUT=$(/usr/local/bin/node scripts/trend-detect.js 2>>"$LOG")
    38	CANDIDATES=$(echo "$DETECT_OUT" | /usr/local/bin/node -e "
    39	let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    40	  const line=d.split('\n').reverse().find(l=>l.trim().startsWith('{'));
    41	  if(!line){console.log('[]');return;}
    42	  try{const o=JSON.parse(line);console.log(JSON.stringify(o.candidates||[]));}
    43	  catch(e){console.log('[]');}
    44	})")
    45	# 2026-08-27: 売春系などへの返信を弾く。判定できないときは素通しする（ジョブを落とさない）
    46	CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
    47	N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).length)})")
    48	if [ "$N" = "0" ]; then
    49	  log "no candidates"
    50	  exit 0
    51	fi
    52	
    53	PICKS_FILE=/tmp/orch-picks.$$.json
    54	echo "$CANDIDATES" | /usr/local/bin/node -e "
    55	const cs = require('child_process');
    56	const fs = require('fs');
    57	let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    58	  const items = JSON.parse(d);
    59	  const picked = [];
    60	  const seen = new Set();
    61	  for (const item of items) {
    62	    if (picked.length >= $MAX_PICKS) break;
    63	    if (seen.has(item.author)) continue;
    64	    try {
    65	      const can = JSON.parse(cs.execSync('/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/comment-state.js can-comment ' + item.author).toString());
    66	      if (can.ok) { picked.push(item); seen.add(item.author); }
    67	    } catch (e) {}
    68	  }
    69	  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
    70	});
    71	"
    72	N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
    73	log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
    74	if [ "$N_PICKED" = "0" ]; then
    75	  log "all candidates in cooldown"
    76	  rm -f $PICKS_FILE
    77	  exit 0
    78	fi
    79	
    80	# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
    81	RECENT_IDS=$(/usr/local/bin/node -e "
    82	const j = JSON.parse(require('fs').readFileSync('$WS/data/post_queue.json', 'utf8'));
    83	const ids = j.queue.filter(x => x.id && x.id.startsWith('comment-') && x.template_id).slice(-5).map(x => x.template_id).reverse();
    84	console.log(ids.join(','));
    85	")
    86	log "recent template ids (newest first): ${RECENT_IDS:-none}"
    87	
    88	# 2026-05-13: reply連動 follow (E案) - 今日のfollow数を取得
    89	TODAY=$(date +%Y-%m-%d)
    90	REPLY_FOLLOW_COUNT=$(/usr/local/bin/node -e "
    91	const fs = require('fs');
    92	const p = '$WS/data/reply-followers.json';
    93	if (!fs.existsSync(p)) { console.log(0); process.exit(0); }
    94	const s = JSON.parse(fs.readFileSync(p, 'utf8'));
    95	let n = 0;
    96	for (const [_, e] of Object.entries(s)) {
    97	  if (e.followed_at && e.followed_at.startsWith('$TODAY')) n++;
    98	}
    99	console.log(n);
   100	")
   101	log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"
   102	
   103	for i in $(seq 0 $((N_PICKED - 1))); do
   104	  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
   105	  AUTHOR=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).author)})")
   106	  TARGET_URL=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).tweet_url)})")
   107	
   108	  log "--- processing #$((i+1))/$N_PICKED for @$AUTHOR ---"
   109	
   110	  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
   111	  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
   112	  # 2026-08-28: 紹介コード・URL・見下しなどを送る前に弾く。判定できないときは素通しする
   113	  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
   114	  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
   115	  if [ "$GEN_OK" != "true" ]; then
   116	    log "gen failed (#$((i+1))): $GEN_OUT"
   117	    continue
   118	  fi
   119	  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).text)})")
   120	  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).template_id||'unknown')}catch{console.log('unknown')}})")
   121	  log "  → chosen template_id: $TEMPLATE_ID"
   122	  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
   123	  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)
   124	
   125	  ID="comment-$(date +%Y%m%d-%H%M)-$i"
   126	  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{process.stdout.write(JSON.stringify(d))})"), target_url:'$TARGET_URL', target_handle:'$AUTHOR', template_id:'$TEMPLATE_ID'}))")
   127	  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
   128	  log "enqueue: $ENQ_RES"
   129	  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"
   130	
   131	  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
   132	  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
   133	    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
   134	    ALREADY=$(/usr/local/bin/node -e "
   135	    const fs = require('fs');
   136	    const p = '$WS/data/reply-followers.json';
   137	    if (!fs.existsSync(p)) { console.log('no'); process.exit(0); }
   138	    const s = JSON.parse(fs.readFileSync(p, 'utf8'));
   139	    console.log(s['$AUTHOR'] ? 'yes' : 'no');
   140	    ")
   141	    if [ "$ALREADY" = "yes" ]; then
   142	      log "  follow @$AUTHOR: skipped (already in reply-followers.json)"
   143	    else
   144	      FOLLOW_OUT=$(/usr/local/bin/node $SCRIPTS/follow-handle.js "$AUTHOR" 2>&1 | tail -1)
   145	      FOLLOW_STATUS=$(echo "$FOLLOW_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).status||'unknown')}catch{console.log('parse_err')}})")
   146	      log "  follow @$AUTHOR: $FOLLOW_STATUS"
   147	      if [ "$FOLLOW_STATUS" = "followed" ]; then
   148	        /usr/local/bin/node -e "
   149	        const fs = require('fs');
   150	        const p = '$WS/data/reply-followers.json';
   151	        const s = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
   152	        s['$AUTHOR'] = {
   153	          followed_at: new Date().toISOString(),
   154	          followback_status: 'pending',
   155	          scheduled_unfollow_at: null,
   156	          source: 'comment-orchestrator',
   157	          comment_id: '$ID'
   158	        };
   159	        const tmp = p + '.tmp';
   160	        fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
   161	        fs.renameSync(tmp, p);
   162	        "
   163	        REPLY_FOLLOW_COUNT=$((REPLY_FOLLOW_COUNT + 1))
   164	        log "  recorded in reply-followers.json (count now $REPLY_FOLLOW_COUNT/$REPLY_FOLLOW_DAILY_CAP)"
   165	      fi
   166	    fi
   167	  else
   168	    log "  follow skipped: daily cap ($REPLY_FOLLOW_DAILY_CAP) reached"
   169	  fi
   170	done
   171	
   172	rm -f $PICKS_FILE
   173	log "=== orchestrator done: $N_PICKED drafts, $REPLY_FOLLOW_COUNT reply-connected follows today ==="
```

### 生成器の呼び出し箇所だけ抜き出す

```
46:CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
80:# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
111:  GEN_OUT=$(echo "$GEN_INPUT" | RECENT_TEMPLATE_IDS="$RECENT_IDS" /usr/local/bin/node scripts/asuka-fill.js 2>&1)
113:  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
114:  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
115:  if [ "$GEN_OK" != "true" ]; then
```

## 3. `comment-warmup` の plist

- 更新: 2026-08-23 02:09 / 1354 B
- `plutil -lint`: /Users/ny/Library/LaunchAgents/ai.openclaw.comment-warmup.plist: OK

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>MAX_AGE_HOURS</key>
		<string>18</string>
		<key>MAX_PICKS_PER_FIRE</key>
		<string>2</string>
		<key>MIN_LIKES</key>
		<string>2</string>
		<key>REPLY_FOLLOW_DAILY_CAP</key>
		<string>30</string>
	</dict>
	<key>Label</key>
	<string>ai.openclaw.comment-warmup</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh</string>
	</array>
	<key>StandardErrorPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/comment-warmup-err.log</string>
	<key>StandardOutPath</key>
	<string>/Users/ny/.openclaw/workspace/logs/comment-warmup.log</string>
	<key>StartCalendarInterval</key>
	<array>
		<dict>
			<key>Hour</key>
			<integer>16</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>12</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>22</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
		<dict>
			<key>Hour</key>
			<integer>19</integer>
			<key>Minute</key>
			<integer>0</integer>
		</dict>
	</array>
</dict>
</plist>
```

- `launchctl list`: **未ロード**

## 4. `auto-reply.js` の投稿口（**承認が要るのか**）

```
27:              statusCode: 200,
45:          return { ok: true, status: 200, json: async () => JSON.parse(body), text: async () => body };
63: *   2. post-comment.js で即時 Playwright 投稿 (失敗時は最大2回リトライ)
64: *   3. queue.json 更新 (status=posted, x_tweet_id, posted_at)
73:const POST_COMMENT = `${WS}/scripts/post-comment.js`;
78:const MAX_RETRIES = 2;
105:  // Step 1: Post via post-comment.js (リトライ最大2回、10s間隔)
110:  for (let attempt = 1; attempt <= MAX_RETRIES + 1; attempt++) {
137:    if (attempt <= MAX_RETRIES) {
151:      // 独立 tweet 化 → 既に post-comment.js が 自動削除済、 queue revert + Slack alert
152:      entry.status = "skipped_reply_linkage_lost";
156:      await slackPost(`<@${OWNER_USER_ID}> ⚠️ リプライ独立tweet化 検知 → 自動削除完了\nID: ${id}\n対象: ${entry.target_url}\n削除tweet: ${postRes.tweet_id}\n(post-comment.js Layer 2 が 事後 verify で 検知、 delete-tweet.js で 即削除、 queue status: skipped_reply_linkage_lost)`);
158:      await slackPost(`<@${OWNER_USER_ID}> 🚨 リプライ自動投稿 失敗 (${MAX_RETRIES}回リトライ済)\nID: ${id}\n対象: ${entry.target_url}\nエラー: ${JSON.stringify(postRes)}${stderrInfo}`);
185:  entry.status = "posted";
```

## 5. 返信系ログ

```
  comment-warmup               2026-09-02 12:03  (6186 行)
  comment-warmup-err           2026-09-02 12:03  (2202 行)
  comment-orchestrator         2026-09-02 12:03  (5450 行)
  incoming-reply-watcher       2026-08-30 23:55  (22133 行)
  auto-reply                   （ログ無し）
```

### `comment-warmup.log` の末尾

```
[2026-09-01T22:03:26]   → chosen template_id: T21
[2026-09-01T22:03:26] enqueue: {"ok":true,"id":"comment-20260901-2203-1"}
{"ok":true,"entry_id":"comment-20260901-2203-1","x_tweet_id":"2094773161623728197","url":"https://x.com/heng_ji31590/status/2094773161623728197","slack_report_ts":"silenced"}
[2026-09-01T22:03:40]   follow @<伏せ>: filtered
[2026-09-01T22:03:40] === orchestrator done: 2 drafts, 3 reply-connected follows today ===
[2026-09-02T12:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
[2026-09-02T12:03:06] picked 2 / max 2 (from 15 candidates)
[2026-09-02T12:03:06] recent template ids (newest first): T21,T22,T16c,T04,T07
[2026-09-02T12:03:06] today's reply-connected follows: 0 / 30
[2026-09-02T12:03:06] --- processing #1/2 for @<伏せ> ---
[2026-09-02T12:03:10]   → chosen template_id: T11
[2026-09-02T12:03:10] enqueue: {"ok":true,"id":"comment-20260902-1203-0"}
{"ok":true,"entry_id":"comment-20260902-1203-0","x_tweet_id":"2094984489013502070","url":"https://x.com/heng_ji31590/status/2094984489013502070","slack_report_ts":"silenced"}
[2026-09-02T12:03:25]   follow @<伏せ>: filtered
[2026-09-02T12:03:25] --- processing #2/2 for @<伏せ> ---
[2026-09-02T12:03:29]   → chosen template_id: T07
[2026-09-02T12:03:29] enqueue: {"ok":true,"id":"comment-20260902-1203-1"}
{"ok":true,"entry_id":"comment-20260902-1203-1","x_tweet_id":"2094984567581200796","url":"https://x.com/heng_ji31590/status/2094984567581200796","slack_report_ts":"silenced"}
[2026-09-02T12:03:40]   follow @<伏せ>: skipped (already in reply-followers.json)
[2026-09-02T12:03:40] === orchestrator done: 2 drafts, 0 reply-connected follows today ===
```

### `comment-orchestrator.log` の末尾

```
[2026-09-01T22:03:26] enqueue: {"ok":true,"id":"comment-20260901-2203-1"}
[2026-09-01T22:03:40]   follow @<伏せ>: filtered
[2026-09-01T22:03:40] === orchestrator done: 2 drafts, 3 reply-connected follows today ===
[2026-09-02T12:00:05] === comment orchestrator start (max_picks=2, reply_follow_cap=30) ===
  ng-filter: 16 件中 1 件を弾いた (hard=1)
    弾いた理由 hard: 現金化
[2026-09-02T12:03:06] picked 2 / max 2 (from 15 candidates)
[2026-09-02T12:03:06] recent template ids (newest first): T21,T22,T16c,T04,T07
[2026-09-02T12:03:06] today's reply-connected follows: 0 / 30
[2026-09-02T12:03:06] --- processing #1/2 for @<伏せ> ---
  tone-gate: 送るが記録する (command=なさいよ)
[2026-09-02T12:03:10]   → chosen template_id: T11
[2026-09-02T12:03:10] enqueue: {"ok":true,"id":"comment-20260902-1203-0"}
[2026-09-02T12:03:25]   follow @<伏せ>: filtered
[2026-09-02T12:03:25] --- processing #2/2 for @<伏せ> ---
  tone-gate: 送るが記録する (assertion=年間40000円浮く)
[2026-09-02T12:03:29]   → chosen template_id: T07
[2026-09-02T12:03:29] enqueue: {"ok":true,"id":"comment-20260902-1203-1"}
[2026-09-02T12:03:40]   follow @<伏せ>: skipped (already in reply-followers.json)
[2026-09-02T12:03:40] === orchestrator done: 2 drafts, 0 reply-connected follows today ===
```


## 6. キューの `comment` / `reply`

```
  comment / reply: 908 件
    posted              848 件
    skipped             32 件
    awaiting_approval   15 件
    cancelled_stale     6 件
    skipped_consecutive_errors3 件
    pending             3 件
    cancelled_redundant 1 件
  日別（直近 10 日）:
    2026-09-02  2 件
    2026-09-01  8 件
    2026-08-31  6 件
    2026-08-30  7 件
    2026-08-29  6 件
    2026-08-28  8 件
    2026-08-27  8 件
    2026-08-26  8 件
    2026-08-25  8 件
    2026-08-24  8 件
  最後に出た返信: 2026-09-02T03:03:40.895Z
```

---

**何も触っていない。返信も投稿もしていない。LLM も呼んでいない（$0）。**
