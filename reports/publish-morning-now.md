# 積んである告知を出す（2026-09-05 22:02 JST・費用 $0）

> t048 は積むところまで成功し、**CDP の判定だけで止まった。**
> だがその `127.0.0.1:9222` に根拠は無かった。**今回はソースから口を読む。**

## 0. もう出ていないか

- 投稿済みエントリ: **0 件**

### t048 が積んだエントリ（積み直さない）

```json
{
 "id": "blog-promo-20260905-morning-500-2026",
 "kind": "thread",
 "status": "pending",
 "x_tweet_id": null,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "tweet_id": null,
   "posted": false,
   "images": 4
  },
  {
   "n": 2,
   "role": "cta",
   "tweet_id": null,
   "posted": false,
   "images": 0
  }
 ],
 "posted_at": null,
 "error": null
}
```

## 0-B. 画像を取り直す（**古い絵で出さないため**）

`t048` は画像を `/Users/ny/.openclaw/workspace/data/x-morning-500` に**取り出し済み**で、キューのエントリはその
**実ファイルを指している。** その後に絵を差し替えているので、
**取り直さないと古い絵のまま出る。** パスは同じなのでキューは触らなくてよい。

```
  **更新**  1-summary.jpg    245671 → 250062 bytes
  同じ      2-matsuya.jpg    157075 bytes
  同じ      3-komeda.jpg     171572 bytes
  同じ      4-sukiya.jpg     212141 bytes
```

## 1. Chrome まわりのソースを出して読む

### `ensure-chrome.sh`

```bash
#!/bin/bash
# Ensure Chrome with --remote-debugging-port=18810 is running AND actually responsive.
# Returns 0 on success (CDP コマンドが通る), 1 on failure.
#
# 2026-07-11 login-mode guard: lock 存在時 は Chrome 起動もしない (user 手動 login 中は Chrome を触らない)
# 2026-08-06 hang detect: ポート LISTEN だけでは不十分。ハングした Chrome も
#   ポートを開いたまま /json/version に 200 を返し ws ハンドシェイクも通るため、
#   従来の lsof チェックはハングを "生存" と誤判定し続けた (CDP timeout ログ 18,087 件)。
# 2026-08-07 誤検知/同時実行対策 (初版の設計ミス修正):
#   このスクリプトは 26 本のジョブから呼ばれ同時起動が日常的に起きる。初版は
#   (a) 負荷で health が 1 回転けただけで健全な Chrome を kill しかけ、
#   (b) 同時呼び出しがクールダウンに当たって exit 1 → 呼び出し元が "Chrome failed" で中断
#   していた。さらに現状 Chrome は cookie をディスクに永続化できていないため
#   (Default/Cookies が 0 行のまま)、再起動 = 即ログアウト であり誤 kill の代償が大きい。
#   → ロックで直列化し、ハングは複数回連続失敗で初めて確定、再起動後は自動再ログインする。
LOCK=/tmp/x-login-in-progress
if [ -f "$LOCK" ]; then
  echo "ensure-chrome: login-mode-guard active, skip launch" >&2
  # Chrome が動いていれば 0、 動いてなければ 0 で return (skip = 意図的な no-op)
  exit 0
fi

PORT=18810
USER_DATA=/Users/ny/.openclaw/browser/cft-profile
CHROME=/Users/ny/.<MASKED>\ Chrome\ for\ Testing.app/Contents/MacOS/Google\ Chrome\ for\ Testing
NODE=/usr/local/bin/node
WS=/Users/ny/.openclaw/workspace
HEALTH="$WS/scripts/cdp-health.js"
LOG="$WS/logs/ensure-chrome.log"
LOCKDIR=/tmp/ensure-chrome.lock
LOCK_STALE=240        # ロック放置の掃除しきい値(秒)
CONFIRM_TRIES=3       # ハング確定に必要な連続失敗回数
CONFIRM_WAIT=8        # 確認の間隔(秒)
WAIT_FOR_PEER=150     # 他インスタンスが修復中のとき待つ上限(秒)

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ensure-chrome: $*" >> "$LOG" 2>/dev/null; }

port_listening() { /usr/sbin/lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; }
cdp_healthy() { "$NODE" "$HEALTH" >/dev/null 2>&1; }

# 健全になるまで最大 $1 秒待つ
wait_healthy() {
  local limit=$1 i=0
  while [ $i -lt "$limit" ]; do
    port_listening && cdp_healthy && return 0
    sleep 3; i=$((i + 3))
  done
  return 1
}

acquire_lock() {
  # 放置ロックの掃除 (修復中に kill されたケース)
  if [ -d "$LOCKDIR" ]; then
    local age
    age=$(( $(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || echo 0) ))
    [ "$age" -gt "$LOCK_STALE" ] && rmdir "$LOCKDIR" 2>/dev/null
  fi
  mkdir "$LOCKDIR" 2>/dev/null
}
release_lock() { rmdir "$LOCKDIR" 2>/dev/null; }

kill_chrome() {
  pkill -f "remote-debugging-port=$PORT" 2>/dev/null
  for _ in $(seq 1 10); do
    pgrep -f "remote-debugging-port=$PORT" >/dev/null 2>&1 || return 0
    sleep 1
  done
  pkill -9 -f "remote-debugging-port=$PORT" 2>/dev/null
  sleep 2
}
```

### `post-via-playwright.js` の接続まわり

```javascript
10:const CDP_URL = process.env.CHROME_CDP_URL || "http://127.0.0.1:18810";
42:    browser = await chromium.connectOverCDP(CDP_URL, { timeout: 15000 });
```

### `run-publish.sh` の冒頭

```bash
#!/bin/bash
# run-publish.sh (v3.2 2026-05-15: thread_chain サポート)
# 既存機能: text + image + thread_url_text の自動 reply
# 新規: kind=thread / thread_chain[] → main + 各 reply を順次投稿
#
# Schema:
#   - thread_chain[]: [{text, role: hook|link|body|cta, image_path?, url?}]
#   - 1個目 = main post (post-via-playwright)
#   - 2個目以降 = reply chain (post-comment.js with previous tweet URL as target)
ENTRY_ID="${1:-day2-1}"
/Users/ny/.openclaw/workspace/scripts/ensure-chrome.sh || { echo '{"ok":false,"step":"ensure-chrome","error":"Chrome failed to start"}'; exit 1; }
cd /Users/ny/.openclaw/workspace

ENTRY_JSON=$(/usr/local/bin/node -e "
const q = require('./data/post_queue.json');
const e = q.queue.find(x => x.id === '$ENTRY_ID');
if (!e) { process.exit(1); }
process.stdout.write(JSON.stringify({
  text: e.text,
  image_path: e.image_path || null,
  thread_url_text: e.thread_url_text || null,
  thread_chain: e.thread_chain || null,
  kind: e.kind || null,
  target_url: e.target_url || null,
}));
")
if [ -z "$ENTRY_JSON" ]; then
  echo '{"ok":false,"step":"read-entry","error":"entry not found"}'
  exit 1
fi

HAS_THREAD=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
  const o = JSON.parse(d);
  process.stdout.write((o.thread_chain && Array.isArray(o.thread_chain) && o.thread_chain.length > 1) ? 'yes' : 'no');
});
")

# 🆕 2026-06-07: trend_qt は post-quote-tweet.js で実 QT 化 (旧: 平 post 扱いで意味なかった)
KIND=$(echo "$ENTRY_JSON" | /usr/local/bin/node -e "
```

## 2. ソースに書かれている口を全部 叩く（決め打ちしない）

```
  **生きている** :18810  {   "Browser": "Chrome/140.0.7339.207",   "Protocol-Version": "1.3",   "User-Agent": "Mozi
```

- ソースから拾った口: `18810 `
- 生きている口: **`18810`**

## 3. Chrome のプロセス

```
  502 26-03:23:33 /Applications/Slack.app/Contents/Frameworks/Electron Framework.framework/Helpers/chrome_crashpad_handler --no-upload-gzip --monitor-self-annot
  620 26-03:23:29 /Applications/Visual Studio Code.app/Contents/Frameworks/Electron Framework.framework/Helpers/chrome_crashpad_handler --no-rate-limit --monito
 1161 26-03:23:05 /Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app/Contents/MacOS/../Frameworks/Creative Cloud UI Helper (GPU).app/Contents/M
 1177 26-03:23:02 /Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app/Contents/MacOS/../Frameworks/Creative Cloud UI Helper.app/Contents/MacOS/C
 1178 26-03:23:02 /Applications/Utilities/Adobe Creative Cloud/ACC/Creative Cloud.app/Contents/MacOS/../Frameworks/Creative Cloud UI Helper.app/Contents/MacOS/C
14699 01-18:15:52 /Library/PrivilegedHelperTools/ChromeRemoteDesktopHost.app/Contents/MacOS/remoting_me2me_host_service --run-from-launchd
```

## 4. `ensure-chrome.sh` を走らせる（stderr も出す）

```
(rc=0)
```

- 走らせた後に生きている口: **`18810`**

## 5. 出す

```
[run-publish] thread_chain mode
{"ok":false,"step":"thread-main-exec","error":"Command failed: /usr/local/bin/node scripts/post-via-playwright.js \"<MASKED>
(rc=0)
```

## 6. [1/2] と [2/2] は両方 出たか

- 投稿済みエントリ: **0 件**（開始前 0 件）

```json
{
 "id": "blog-promo-20260905-morning-500-2026",
 "kind": "thread",
 "status": "pending",
 "x_tweet_id": null,
 "images": 4,
 "chain": [
  {
   "n": 1,
   "role": "hook",
   "tweet_id": null,
   "posted": false,
   "images": 4
  },
  {
   "n": 2,
   "role": "cta",
   "tweet_id": null,
   "posted": false,
   "images": 0
  }
 ],
 "posted_at": null,
 "error": null
}
```

**`chain` の 2 本とも `posted: true` でなければ、片肺で終わっている。**
その場合は [2/2] を足すタスクを別に出すこと。**黙って「出ました」と言わない。**

---

**LLM を呼んでいない（$0）。** **X 上の手動投稿はキューからは見えない。**
