# 返信の再開と、NG 判定の差し込み位置（2026-08-23 18:45 JST）

## 1. 返信ジョブを戻す

> 022 が止めたが、Jordan の判断は「止めずに NG 判定を先に入れる」。
- ai.openclaw.comment-warmup: **戻した**
- ai.openclaw.incoming-reply-watcher: **戻した**
- ai.openclaw.auto-thread-chainifier: **戻した**

### 確認（launchctl の実体）
  ai.openclaw.comment-warmup                 稼働
  ai.openclaw.incoming-reply-watcher         稼働
  ai.openclaw.auto-thread-chainifier         稼働

## 2. NG ルールと判定モジュールを配置

- reply-ng-rules.json: 配置（3246 B）
- reply-ng-check.cjs: 配置（3006 B）

### 実機での自己テスト
```
OK   売春の勧誘 → ng=true (hard)
OK   ポイ活の人（誤爆NG） → ng=false (never_ng)
OK   LINE誘導 → ng=true (link)
OK   節約垢です 援助希望 → ng=true (hard)
OK   普通の節約垢 → ng=false (never_ng)
全5ケース 期待どおり
```

## 3. 差し込む場所の実物

> **推測でシェルを書き換えない。** ここで実物を見てから次のタスクで入れる。

### comment-orchestrator.sh 全 169 行 / 候補〜pick の部分（30〜85 行）
```bash

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

```

### comment-warmup が実際に叩くもの
```
	arguments = {
		/bin/bash
		/Users/ny/.openclaw/workspace/scripts/comment-orchestrator.sh
	}
```

### 候補 JSON の形（キー名のみ・値は出さない）
```
post_queue の comment エントリのキー: id, kind, text, target_url, target_handle, template_id, status, created_at, x_tweet_id, posted_at, published_via
```
