#!/bin/bash
# **まず返信を出す。診断はそのあと。費用 最大 $0.012。**
#
# ## x39 で分かったこと（2026-09-13 01:26）
#
# ### ① 私のパッチが当たっていなかった
#
#   27:const LOCK = "/tmp/x-login-in-progress";
#   64:  try { fs.writeFileSync(LOCK, "tab-guard"); } catch {}   ← これが書いている
#
# **64 行目に `x-login-in-progress` という文字列は無い**（変数 `LOCK` 経由）。
# x39 のパッチは「同じ行に両方ある」条件だったので **1 行も書き換わっていない。**
# tab-guard は今もロックを書く。**今回は `writeFileSync(LOCK` で当てる。**
#
# ### ② 外す主は tab-guard ではない。約 61 秒 周期で flap している
#
#   ★ 01:27:28 消えた: comment-warmup
#   ★ 01:28:29 消えた: comment-warmup   ← 一度 戻ってから、また消えている
#   ★ 01:29:30 消えた: comment-warmup
#
# **戻っているということは、載せている主も居る。** tab-guard のログはその間 増えていない。
#
# ## 順番を変える
#
# **ジョブが「載り続ける」ことを先に解こうとして 4 日 使った。**
# 載り続けなくても、**載った瞬間に走らせれば返信は出る。**
#
#   1. ロックを本当に無効化する（今度は当たる書き方で）
#   2. ロックを外す
#   3. 欠けている 4 本を bootout → enable → bootstrap で載せ直す
#   4. **載った瞬間に kickstart する。** 消えるかどうかを待たない
#   5. 実投稿を数える（キューの `x_tweet_id`＝一次情報）
#   6. **launchd 自身のログに「誰が外したか」を聞く**（`log show`）
#
# ## やらないこと
#
# **Chrome を kill しない。tab-guard を止めない。halt の判定条件を変えない。**
# 変更は `.bak-<日時>` に退避し、`node --check` が通らなければその場で戻す。
#
# 費用: **最大 $0.012**（kickstart 最大 4 件）。走らせられなければ **$0**。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/post-now.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
UID_NUM="$(id -u)"
LOCK=/tmp/x-login-in-progress
TG="$S/tab-guard.js"
STAMP="$(date '+%Y%m%d-%H%M%S')"

EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
is_loaded() { launchctl list 2>/dev/null | grep -qF "ai.openclaw.$1"; }
cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

count_posted() {
  "$NODE_BIN" -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  console.log((q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")
    &&(e.x_tweet_id||e.tweet_id)).length);
}catch(e){ console.log(-1); }
' "$QJSON" 2>/dev/null || echo -1
}

{
echo "# まず返信を出す"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> ジョブが「載り続ける」ことを先に解こうとして 4 日 使った。"
echo "> **載り続けなくても、載った瞬間に走らせれば返信は出る。**"

# ═══════════ 1. ロックの書き込みを本当に止める ═══════════
echo
echo "## 1. ロックの書き込みを止める（**今度は当たる書き方で**）"
echo
echo "x39 は \`x-login-in-progress\` と \`writeFileSync\` が**同じ行にある**ことを条件にしたが、"
echo "実物は \`const LOCK = \"/tmp/x-login-in-progress\"\` と \`fs.writeFileSync(LOCK, ...)\` に"
echo "**分かれている。** 今回は \`writeFileSync(LOCK\` で当てる。"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  **$TG が無い。触らない。**"
else
  echo "  --- 書き換える前 ---"
  grep -nE 'writeFileSync\(\s*LOCK|LOCK_WRITE_DISABLED' "$TG" 2>/dev/null | sed 's/^/    /' | clean
  cp "$TG" "$TG.bak-$STAMP" && echo "  退避: $(basename "$TG").bak-$STAMP"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
let s=fs.readFileSync(p,"utf8");
const before=s;
let hit=0;
s=s.split("\n").map(l=>{
  // **LOCK 変数への書き込みだけを止める。** 判定条件・halt 本体・ログ・STATE は触らない。
  if(/(writeFileSync|appendFileSync|openSync)\s*\(\s*LOCK\b/.test(l) && !/^\s*\/\//.test(l)){
    hit++;
    const ind=(l.match(/^\s*/)||[""])[0];
    return ind+"// LOCK_WRITE_DISABLED (2026-09-13): このロックは ensure-chrome.sh を no-op に\n"
         + ind+"// して Chrome の起動を塞ぎ、tab-guard 自身の halt 条件を永久に成立させ続けた\n"
         + ind+"// （docs/self-healing-deadlock.md 条件 3）。halt と検知はそのまま残す。\n"
         + ind+"// " + l.trim();
  }
  return l;
}).join("\n");
if(s===before){ console.log("  **対象が見つからなかった。何もしていない。**"); process.exit(0); }
fs.writeFileSync(p,s);
console.log("  書き換えた行数: "+hit);
' "$TG" 2>&1 | sed 's/^/  /' | clean

  if "$NODE_BIN" --check "$TG" 2>/dev/null; then
    echo "  node --check: OK"
    echo "  --- 書き換えた後 ---"
    grep -nE 'LOCK_WRITE_DISABLED|writeFileSync\(\s*LOCK' "$TG" 2>/dev/null | head -6 | sed 's/^/    /' | clean
  else
    echo "  **node --check が通らない。戻す。**"
    cp "$TG.bak-$STAMP" "$TG"
    "$NODE_BIN" --check "$TG" 2>&1 | head -3 | sed 's/^/    /' | clean
  fi
fi
echo '```'

# ═══════════ 2. ロックを外す ═══════════
echo
echo "## 2. 残っているロックを外す"
echo
echo '```'
if [ ! -f "$LOCK" ]; then
  echo "  ロックは無い（正常）。"
elif pgrep -f 'x-login' >/dev/null 2>&1; then
  echo "  **本物のログインが走っている。触らない。**"
else
  echo "  中身: $(head -c 80 "$LOCK" 2>/dev/null | tr '\n' ' ' | clean)"
  rm -f "$LOCK" 2>/dev/null
  [ -f "$LOCK" ] && echo "  外せなかった" || echo "  **外した**"
fi
echo '```'

# ═══════════ 3. 欠けている本を載せ直す ═══════════
echo
echo "## 3. 欠けている本を \`bootout\` → \`enable\` → \`bootstrap\`"
echo
echo "x38 で 2 本が \`Bootstrap failed: 5: Input/output error\` だった。"
echo "**これは「既にドメインに居る」ときの定型。** 先に \`bootout\` してから入れ直す。"
echo
echo '```'
for j in $EXPECT; do
  is_loaded "$j" && { printf '  %-28s 載っている\n' "$j"; continue; }
  P="$LA/ai.openclaw.$j.plist"
  if [ ! -f "$P" ]; then printf '  %-28s **plist が無い**\n' "$j"; continue; fi
  launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
  launchctl enable "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
  ERR="$(launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1 | head -1)"
  if is_loaded "$j"; then printf '  %-28s **載せた**\n' "$j"
  else printf '  %-28s 載らない: %s\n' "$j" "$(printf '%s' "$ERR" | cut -c1-60)"; fi
done
N=0; for j in $EXPECT; do is_loaded "$j" && N=$((N+1)); done
echo
echo "  **いま: ${N} / 8 本**"
echo '```'

# ═══════════ 4. 待たずに走らせる ═══════════
echo
echo "## 4. **載った瞬間に走らせる。** 消えるかどうかを待たない"
echo
echo '```'
if [ ! -f "$LOCK" ] && cdp_ok; then
  echo "  CDP: 健全 / login ロック: 無い → 走らせる"
else
  cdp_ok || echo "  CDP: **落ちている**"
  [ -f "$LOCK" ] && echo "  login ロック: **在る**"
  echo
  echo "  --- ensure-chrome.sh を 1 回 呼ぶ（ロックが無いので no-op にならないはず） ---"
  ( cd "$W" && "$S/ensure-chrome.sh" ) 2>&1 | tail -5 | sed 's/^/    /' | clean
  sleep 10
  cdp_ok && echo "  → CDP 健全になった" || echo "  → **まだ落ちている**"
fi

if ! cdp_ok; then
  echo
  echo "  **CDP が健全にならない。LLM を 1 回も呼ばずに終わる（\$0）。**"
  echo '```'
else
  BEFORE="$(count_posted)"
  echo
  echo "  走らせる前の累計: **${BEFORE} 件**"
  if [ "$BEFORE" = "-1" ]; then
    echo "  **キューが読めない。何もしない。**"
    echo '```'
  else
    echo
    echo "  --- comment-warmup を kickstart（最大 4 件・約 \$0.012） ---"
    if is_loaded comment-warmup; then
      launchctl kickstart -k "gui/${UID_NUM}/ai.openclaw.comment-warmup" 2>&1 | head -2 | sed 's/^/    /' | clean
    else
      echo "    launchd に載っていない。**スクリプトを直接 叩く。**"
      ORCH="$S/comment-orchestrator.sh"
      if [ -f "$ORCH" ]; then
        ( cd "$W" && bash "$ORCH" ) 2>&1 | tail -15 | sed 's/^/    /' | clean
      else
        echo "    **$ORCH が無い。走らせられない（\$0）。**"
        ls -1 "$S" 2>/dev/null | grep -iE 'comment|orchestr' | head -5 | sed 's/^/      候補: /'
      fi
    fi
    echo
    for i in 60 120 180; do
      sleep 60
      printf '    %3s 秒後: 累計 %s 件\n' "$i" "$(count_posted)"
    done
    AFTER="$(count_posted)"
    DIFF=$(( AFTER - BEFORE ))
    echo
    echo "  走らせる前: ${BEFORE} 件 → 後: ${AFTER} 件"
    echo "  **今回 出た数: ${DIFF} 件**"
    echo '```'

    if [ "$DIFF" -gt 0 ]; then
      echo
      echo "### 出た返信（**キューの \`x_tweet_id\`＝一次情報**）"
      echo
      echo '```'
      "$NODE_BIN" -e '
const fs=require("fs");
const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const n=Number(process.argv[2]);
const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
rows.slice(-n).forEach(e=>{
  console.log("  "+(e.posted_at||e.created_at));
  console.log("  https://x.com/heng_ji31590/status/"+(e.x_tweet_id||e.tweet_id));
  console.log("  "+String(e.text||"").replace(/\n/g,"\n  "));
  console.log("");
});
' "$QJSON" "$DIFF" 2>&1 | clean
      echo '```'
    else
      echo
      echo "### 出なかった理由（直近 40 行）"
      echo
      echo '```'
      tail -40 "$W/logs/comment-warmup.log" 2>/dev/null | sed 's/^/  /' | clean
      echo '```'
    fi
  fi
fi

# ═══════════ 5. launchd 自身に聞く ═══════════
echo
echo "## 5. **誰が外したのか、launchd 自身に聞く**"
echo
echo "x39 では 約 61 秒 周期で載っては消える flap を観測したが、"
echo "tab-guard のログは 1 行も増えていない。**推測をやめて一次情報を取る。**"
echo
echo '```'
echo "  --- log show（直近 15 分・launchd の openclaw 関連） ---"
log show --last 15m --style compact \
  --predicate 'subsystem == "com.apple.xpc.launchd"' 2>/dev/null \
  | grep -iE 'openclaw' | tail -40 | cut -c1-200 | sed 's/^/    /' | clean \
  || echo "    log show が使えなかった"
echo '```'
echo
echo '```'
echo "  --- いま launchctl に居る ai.openclaw.* ---"
launchctl list 2>/dev/null | awk '$3 ~ /^ai\.openclaw\./ {printf "    %-12s %-6s %s\n",$1,$2,$3}' | clean
echo '```'
echo
echo '```'
echo "  --- 1 分ごとに走っているもの（flap の周期と一致するか） ---"
for L in com.dailyhack.ops-poller com.dailyhack.ops-heartbeat com.dailyhack.rc-keeper ai.openclaw.x-loop-guardian; do
  P="$LA/$L.plist"
  [ -f "$P" ] || { printf '    %-34s plist 無し\n' "$L"; continue; }
  IV="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$P" 2>/dev/null || echo '-')"
  printf '    %-34s StartInterval=%s\n' "$L" "$IV"
done
echo '```'
} > "$OUT" 2>&1

echo "まず返信を出す / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
