# `comment-orchestrator.sh` の実物

**このレポートが作られた時刻: 2026-09-13 20:38:24 JST**

> **いちばん返りのいい供給元（21.5%）に x64 が当たっていない。**
> **広告の判定が「選んだ後」に走っていて、picked の枠を 7 つ 空振りさせている。**

**読むだけ。直さない。**

## 1. 全文

```
  173 行 / 最終更新 2026-09-06 20:52
```

```bash
#!/bin/bash
# comment-orchestrator.sh (v3 2026-05-13: reply連動 follow E案追加)
# trend-detect → filter → MAX_PICKS_PER_FIRE 件 pick + 各 gen + enqueue + draft + follow (E案)
set -e

WS=/Users/ny/.openclaw/workspace
SCRIPTS=$WS/scripts
LOG=$WS/logs/comment-orchestrator.log
MAX_PICKS=${MAX_PICKS_PER_FIRE:-2}
REPLY_FOLLOW_DAILY_CAP=${REPLY_FOLLOW_DAILY_CAP:-10}

ts() { date "+%Y-%m-%dT%H:%M:%S"; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

CONFIG=/Users/ny/.openclaw/openclaw.json
eval "$(/usr/local/bin/node -e "
const c = require('$CONFIG');
console.log('export SLACK_BOT_TOKEN=' + JSON.stringify((c.channels && c.channels.slack && c.channels.slack.botToken) || ''));
")"
export PATH="/usr/local/bin:$PATH"

log "=== comment orchestrator start (max_picks=$MAX_PICKS, reply_follow_cap=$REPLY_FOLLOW_DAILY_CAP) ==="

CAN=$(/usr/local/bin/node $SCRIPTS/comment-state.js can-comment 2>&1)
CAN_OK=$(echo "$CAN" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
if [ "$CAN_OK" != "true" ]; then
  log "global limit: $CAN"
  exit 0
fi

$SCRIPTS/ensure-chrome.sh || { log "Chrome failed"; exit 1; }

cd $WS
# 2026-08-07: 以前は 2>&1 で stderr を混ぜたまま JSON.parse していたため、trend-detect が
# 進捗行やエラー行 (例: "hashtag 還元 failed: timeout 12000ms") を出すと SyntaxError で
# ジョブごと落ちていた。stderr はログに流し、stdout から JSON 行だけを拾う。
DETECT_OUT=$(/usr/local/bin/node scripts/trend-detect.js 2>>"$LOG")
CANDIDATES=$(echo "$DETECT_OUT" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const line=d.split('\n').reverse().find(l=>l.trim().startsWith('{'));
  if(!line){console.log('[]');return;}
  try{const o=JSON.parse(line);console.log(JSON.stringify(o.candidates||[]));}
  catch(e){console.log('[]');}
})")
# 2026-08-27: 売春系などへの返信を弾く。判定できないときは素通しする（ジョブを落とさない）
CANDIDATES=$(echo "$CANDIDATES" | /usr/local/bin/node scripts/ng-filter-candidates.cjs 2>>"$LOG")
N=$(echo "$CANDIDATES" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).length)})")
if [ "$N" = "0" ]; then
  log "no candidates"
  exit 0
fi

PICKS_FILE=/tmp/orch-picks.$$.json
echo "$CANDIDATES" | /usr/local/bin/node -e "
const cs = require('child_process');
const fs = require('fs');
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const items = JSON.parse(d);
  const picked = [];
  const seen = new Set();
  for (const item of items) {
    if (picked.length >= $MAX_PICKS) break;
    if (seen.has(item.author)) continue;
    try {
      const can = JSON.parse(cs.execSync('/usr/local/bin/node /Users/ny/.openclaw/workspace/scripts/comment-state.js can-comment ' + item.author).toString());
      if (can.ok) { picked.push(item); seen.add(item.author); }
    } catch (e) {}
  }
  fs.writeFileSync('$PICKS_FILE', JSON.stringify(picked));
});
"
N_PICKED=$(/usr/local/bin/node -e "console.log(require('$PICKS_FILE').length)")
log "picked $N_PICKED / max $MAX_PICKS (from $N candidates)"
if [ "$N_PICKED" = "0" ]; then
  log "all candidates in cooldown"
  rm -f $PICKS_FILE
  exit 0
fi

# 2026-05-13: 直近5件の chosen_template_id を queue から抽出して asuka-fill に渡す (単調化防止)
RECENT_IDS=$(/usr/local/bin/node -e "
const j = JSON.parse(require('fs').readFileSync('$WS/data/post_queue.json', 'utf8'));
const ids = j.queue.filter(x => x.id && x.id.startsWith('comment-') && x.template_id).slice(-5).map(x => x.template_id).reverse();
console.log(ids.join(','));
")
log "recent template ids (newest first): ${RECENT_IDS:-none}"

# 2026-05-13: reply連動 follow (E案) - 今日のfollow数を取得
TODAY=$(date +%Y-%m-%d)
REPLY_FOLLOW_COUNT=$(/usr/local/bin/node -e "
const fs = require('fs');
const p = '$WS/data/reply-followers.json';
if (!fs.existsSync(p)) { console.log(0); process.exit(0); }
const s = JSON.parse(fs.readFileSync(p, 'utf8'));
let n = 0;
for (const [_, e] of Object.entries(s)) {
  if (e.followed_at && e.followed_at.startsWith('$TODAY')) n++;
}
console.log(n);
")
log "today's reply-connected follows: $REPLY_FOLLOW_COUNT / $REPLY_FOLLOW_DAILY_CAP"

for i in $(seq 0 $((N_PICKED - 1))); do
  PICK=$(/usr/local/bin/node -e "console.log(JSON.stringify(require('$PICKS_FILE')[$i]))")
  AUTHOR=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).author)})")
  TARGET_URL=$(echo "$PICK" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).tweet_url)})")

  log "--- processing #$((i+1))/$N_PICKED for @$AUTHOR ---"

  GEN_INPUT=$(/usr/local/bin/node -e "console.log(JSON.stringify({trend: $PICK, kind: 'comment'}))")
  GEN_OUT=$(echo "$GEN_INPUT" | /usr/local/bin/node scripts/asuka-reply.cjs 2>>"$LOG")
  # 2026-08-28: 紹介コード・URL・見下しなどを送る前に弾く。判定できないときは素通しする
  GEN_OUT=$(printf %s "$GEN_OUT" | /usr/local/bin/node scripts/tone-gate.cjs 2>>"$LOG")
  GEN_OK=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).ok)}catch{console.log('false')}})")
  if [ "$GEN_OK" != "true" ]; then
    log "gen failed (#$((i+1))): $GEN_OUT"
    continue
  fi
  TEXT=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{console.log(JSON.parse(d).text)})")
  TEMPLATE_ID=$(echo "$GEN_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).template_id||'unknown')}catch{console.log('unknown')}})")
  log "  → chosen template_id: $TEMPLATE_ID"
  RECENT_IDS="$TEMPLATE_ID${RECENT_IDS:+,}$RECENT_IDS"
  RECENT_IDS=$(echo "$RECENT_IDS" | cut -d, -f1-5)

  ID="comment-$(date +%Y%m%d-%H%M)-$i"
  ENQUEUE_PAYLOAD=$(/usr/local/bin/node -e "console.log(JSON.stringify({id:'$ID', kind:'comment', text:$(echo "$TEXT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{process.stdout.write(JSON.stringify(d))})"), target_url:'$TARGET_URL', target_handle:'$AUTHOR', template_id:'$TEMPLATE_ID'}))")
  ENQ_RES=$(echo "$ENQUEUE_PAYLOAD" | /usr/local/bin/node scripts/queue-manager.js enqueue 2>&1)
  log "enqueue: $ENQ_RES"
  /usr/local/bin/node $SCRIPTS/auto-reply.js "$ID"

  # 2026-05-13: reply連動 follow (E案: 48h判定 + 7-14日ランダムunfollow)
  if [ "$REPLY_FOLLOW_COUNT" -lt "$REPLY_FOLLOW_DAILY_CAP" ]; then
    # Skip if already in reply-followers.json (cooldown過去にfollow済み)
    ALREADY=$(/usr/local/bin/node -e "
    const fs = require('fs');
    const p = '$WS/data/reply-followers.json';
    if (!fs.existsSync(p)) { console.log('no'); process.exit(0); }
    const s = JSON.parse(fs.readFileSync(p, 'utf8'));
    console.log(s['$AUTHOR'] ? 'yes' : 'no');
    ")
    if [ "$ALREADY" = "yes" ]; then
      log "  follow @$AUTHOR: skipped (already in reply-followers.json)"
    else
      FOLLOW_OUT=$(/usr/local/bin/node $SCRIPTS/follow-handle.js "$AUTHOR" 2>&1 | tail -1)
      FOLLOW_STATUS=$(echo "$FOLLOW_OUT" | /usr/local/bin/node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).status||'unknown')}catch{console.log('parse_err')}})")
      log "  follow @$AUTHOR: $FOLLOW_STATUS"
      if [ "$FOLLOW_STATUS" = "followed" ]; then
        /usr/local/bin/node -e "
        const fs = require('fs');
        const p = '$WS/data/reply-followers.json';
        const s = fs.existsSync(p) ? JSON.parse(fs.readFileSync(p, 'utf8')) : {};
        s['$AUTHOR'] = {
          followed_at: new Date().toISOString(),
          followback_status: 'pending',
          scheduled_unfollow_at: null,
          source: 'comment-orchestrator',
          comment_id: '$ID'
        };
        const tmp = p + '.tmp';
        fs.writeFileSync(tmp, JSON.stringify(s, null, 2));
        fs.renameSync(tmp, p);
        "
        REPLY_FOLLOW_COUNT=$((REPLY_FOLLOW_COUNT + 1))
        log "  recorded in reply-followers.json (count now $REPLY_FOLLOW_COUNT/$REPLY_FOLLOW_DAILY_CAP)"
      fi
    fi
  else
    log "  follow skipped: daily cap ($REPLY_FOLLOW_DAILY_CAP) reached"
  fi
done

rm -f $PICKS_FILE
log "=== orchestrator done: $N_PICKED drafts, $REPLY_FOLLOW_COUNT reply-connected follows today ==="
```

## 2. 広告を弾いているのは誰か（**入口判定の実体**）

```
  ══ ng-filter-candidates.cjs（110 行 / 09-10 21:38）
    /Users/ny/.openclaw/workspace/scripts/ng-filter-candidates.cjs
    --- 「LLM を呼ばずに見送る」を出している箇所 ---

  ══ asuka-reply.cjs（356 行 / 09-13 02:34）
    /Users/ny/.openclaw/workspace/scripts/asuka-reply.cjs
    --- 「LLM を呼ばずに見送る」を出している箇所 ---
      108:    const ts = (relRules && relRules.target_skip) || {};
      110:    for (const h of ts.hashtags || []) if (target.includes(h)) hit.push(h);
      111:    for (const d of ts.domains || []) if (target.includes(d)) hit.push(d);
      112:    for (const w of ts.campaign_words || []) if (target.includes(w)) hit.push(w);
      114:      return skip('PR/アフィリ/拡散キャンペーンの投稿なので LLM を呼ばずに見送る: ' + hit.slice(0, 3).join(' / '));

  ══ trend-detect.js（251 行 / 08-30 21:42）
    /Users/ny/.openclaw/workspace/scripts/trend-detect.js
    --- 「LLM を呼ばずに見送る」を出している箇所 ---

  --- 判定の materialize（呼べる形か） ---
```

**選ぶループから呼べる形（`module.exports`）になっているかが分かれ目。**
なっていれば、選ぶ前に同じ判定を挟むだけで済む。

## 3. plist の環境変数（**上限の実値**）

```
  ══ ai.openclaw.comment-warmup
    EnvironmentVariables	MAX_AGE_HOURS
    18	MAX_PICKS_PER_FIRE
    4	MIN_LIKES
    2	REPLY_FOLLOW_DAILY_CAP
    30	

  ══ ai.openclaw.competitor-follower-follow
    EnvironmentVariables	COMPETITOR_FOLLOW_DAILY_CAP
    30	FORCE_RUN
    1	PATH
    /usr/local/bin:/usr/bin:/bin	

  ══ ai.openclaw.hashtag-follow
    EnvironmentVariables	FORCE_RUN
    1	HASHTAG_FOLLOW_DAILY_CAP
    90	PATH
    /usr/local/bin:/usr/bin:/bin	

```

**x65 のログでは競合刈り取りが `1/30 OK` と出ていた。**
既定は 10 なので、**plist が 30 を渡している**はず。ここで裏を取る。
日曜（`getDay()===0`）はスキップする実装なのに走っていたので、
**`FORCE_RUN` が渡っているかどうか**もここで分かる。

## 4. 費用

**ファイルを読むだけ。LLM を呼ばない。フォローも投稿もしない。**

| | 金額 |
| --- | --- |
| 1 回あたり | **$0** |
| 1 日あたり | **$0** |
| 1 か月あたり | **$0** |

**この後に控えている変更の費用**（判断材料として先に置く）

| | 1 回あたり | 1 日あたり | 1 か月あたり |
| --- | --- | --- | --- |
| いまの実績（生成 9 件/日） | $0.003 | **$0.027** | **約 $0.81** |
| 選ぶ前に広告を弾いた場合（生成 16 件/日・**上限に張り付く**） | $0.003 | **$0.048** | **$1.44** |

**増加は月 +$0.63。** 単価は実測（2026-09-06・全文生成）、件数は 2026-09-13 のログ実測。
