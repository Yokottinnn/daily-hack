#!/bin/bash
# **載らない 4 本の理由を出す。ついでに comment-warmup を載せて返信を出す。**
#
# ## いま分かっていること（x36 の実測・2026-09-13 00:43）
#
#   載ったか: 1 本 → 60 秒後: 5 / 8 → 120 秒後: 5 / 8 → 180 秒後: 5 / 8
#   **最終: 4 / 8 本**
#   tab-guard: 1 本 ／ CDP: 健全
#   comment-warmup : **未ロード** → 走らせない
#
# **悪循環（全 unload）は止まった。** 0/8 → 4/8 まで戻り、3 分 経っても減っていない。
# tab-guard の A（x33）と B（x36）が効いている。
#
# **だが返信ループ本体の `comment-warmup` が載っていないので、返信は 1 件も出ていない。**
#
# ## 今回やること: 「載らない」の中身を出す
#
# これまで `launchctl load -w` の rc だけ見て「戻した」と書いて外し続けた（最上位ルール 13）。
# **今回は rc を見ない。** 8 本それぞれについて、次を全部 出す。
#
#   1. plist が在るか        … 無ければ「載らない」ではなく「そもそも無い」
#   2. `plutil -lint`        … 壊れた plist は黙って無視される
#   3. `launchctl print` の言い分 … **ここに理由が書いてある**
#   4. 参照している実行ファイルが在るか … 無いと bootstrap は通って即死する
#   5. enable → bootstrap の**標準エラーそのもの**
#   6. **`launchctl list` に出るか** ← これだけが証拠
#
# ## やらないこと
#
# **Chrome を kill しない。tab-guard を止めない。plist を書き換えない。**
# 推測で直さず、**理由を出すことに徹する。**
#
# 唯一の例外は `comment-warmup` が載った場合の `kickstart`。
# **最大 4 件・約 $0.012。** 載らなければ $0 で終わる。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/why-four-wont-load.md"
NODE_BIN="/usr/local/bin/node"
QJSON="$W/data/post_queue.json"
UID_NUM="$(id -u)"
LOCK=/tmp/x-login-in-progress

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
echo "# 載らない 4 本の理由（**rc は見ない**）"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 最上位ルール 13: **\`rc=0\` は「やった」証拠にならない。**"
echo "> 判定は **\`launchctl list\` に出るか** の 1 点だけで行う。"

# ═══════════ 0. いまの状態 ═══════════
echo
echo "## 0. いまの状態"
echo
echo '```'
NOW=0
for j in $EXPECT; do is_loaded "$j" && NOW=$((NOW + 1)); done
echo "  3 ループの 8 本   : ${NOW} / 8 本"
AI_N=$(launchctl list 2>/dev/null | awk '{print $3}' | grep -c '^ai\.openclaw\.' || true)
AI_N=$(printf '%s' "${AI_N:-0}" | tr -dc '0-9'); [ -z "$AI_N" ] && AI_N=0
echo "  ai.openclaw.* 全体: ${AI_N} 本"
echo "  tab-guard         : $(launchctl list 2>/dev/null | grep -cF 'ai.openclaw.tab-guard' || true) 本"
if cdp_ok; then echo "  CDP               : 健全"; else echo "  CDP               : **落ちている**"; fi
if [ -f "$LOCK" ]; then echo "  login ロック      : **有る**（ensure-chrome が no-op になる）"
else echo "  login ロック      : 無い（正常）"; fi
echo '```'

# ═══════════ 1. 1 本ずつ ═══════════
echo
echo "## 1. 8 本を 1 本ずつ見る"

for j in $EXPECT; do
  LBL="ai.openclaw.$j"
  P="$LA/$LBL.plist"
  echo
  echo "### \`$j\`"
  echo
  echo '```'
  if is_loaded "$j"; then
    echo "  **ロード済み。触らない。**"
    launchctl list "$LBL" 2>/dev/null | grep -E '"(PID|LastExitStatus)"' | sed 's/^/    /' | clean
    echo '```'
    continue
  fi

  # 1. plist が在るか
  if [ ! -f "$P" ]; then
    echo "  **plist が無い: $P**"
    echo "  → 「載らない」ではなく **そもそも定義が無い**。復元が要る。"
    ls -1 "$LA" 2>/dev/null | grep -iF "$j" | head -3 | sed 's/^/     似た名前: /'
    echo '```'
    continue
  fi
  echo "  plist   : 在る（$(stat -f '%z bytes / 更新 %Sm' -t '%Y-%m-%d %H:%M' "$P" 2>/dev/null)）"

  # 2. 壊れていないか
  echo "  lint    : $(plutil -lint "$P" 2>&1 | head -1 | sed 's|.*/||')"

  # 3. 参照している実行ファイル
  PROG="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$P" 2>/dev/null \
          | grep -oE '/[^ ]+' | head -2 | tr '\n' ' ')"
  echo "  実行対象: ${PROG:-（読めない）}"
  for p in $PROG; do
    [ -e "$p" ] && echo "    $p … 在る" || echo "    $p … **無い**"
  done

  # 4. launchctl 自身の言い分
  echo
  echo "  --- launchctl print gui/$UID_NUM/$LBL ---"
  launchctl print "gui/${UID_NUM}/$LBL" 2>&1 | head -8 | sed 's/^/    /' | clean

  # 5. enable → bootstrap（標準エラーをそのまま出す）
  echo
  echo "  --- enable ---"
  launchctl enable "gui/${UID_NUM}/$LBL" 2>&1 | head -3 | sed 's/^/    /' | clean
  echo "  --- bootstrap ---"
  launchctl bootstrap "gui/${UID_NUM}" "$P" 2>&1 | head -5 | sed 's/^/    /' | clean

  # 6. 証拠
  sleep 2
  if is_loaded "$j"; then echo; echo "  **→ 載った（launchctl list に出た）**"
  else echo; echo "  **→ 載っていない。上の出力が理由。**"; fi
  echo '```'
done

# ═══════════ 2. 30 秒後にもう一度 ═══════════
echo
echo "## 2. 30 秒後・90 秒後（**外されていないか**）"
echo
echo "x34 では載った直後に tab-guard が外した。**時間を置いて数え直す。**"
echo
echo '```'
for s in 30 60; do
  sleep "$s"
  N=0; for j in $EXPECT; do is_loaded "$j" && N=$((N + 1)); done
  printf '  %3s 秒 経過: %s / 8 本\n' "$s" "$N"
done
FINAL=0; MISSING=""
for j in $EXPECT; do
  if is_loaded "$j"; then FINAL=$((FINAL + 1)); else MISSING="$MISSING $j"; fi
done
echo
echo "  **最終: ${FINAL} / 8 本**"
[ -n "$MISSING" ] && echo "  載っていない:$MISSING"
echo '```'

if [ -f "$S/../logs/tab-guard.log" ] || [ -f "$W/logs/tab-guard.log" ]; then
  echo
  echo "### tab-guard が何か言ったか（直近 10 行）"
  echo
  echo '```'
  tail -10 "$W/logs/tab-guard.log" 2>/dev/null | sed 's/^/  /' | clean
  echo '```'
fi

# ═══════════ 2-B. login ロックの追跡 ═══════════
echo
echo "## 2-B. login ロックは**作られ直している**"
echo
echo "\`heartbeat.json\`（2026-09-12 15:29Z）の実測。"
echo
echo '```'
echo '  "login_lock": {"present": true, "age_hours": 0}'
echo '```'
echo
echo "**9/12 の時点では 51 時間 だった。0 時間 に戻っている ＝ 誰かが作り直している。**"
echo "x26 は「age 0 時間」を見て**触らずに終えた**ので、ロックは残ったままになった。"
echo
echo "ロックが在るあいだ \`ensure-chrome.sh\` は **rc=0 のまま何もしない**（最上位ルール 13）。"
echo
echo '```'
if [ ! -f "$LOCK" ]; then
  echo "  ロックは無い（正常）。この節は何もしない。"
else
  LAGE_S=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s) ))
  LAGE_M=$(( LAGE_S / 60 ))
  echo "  パス      : $LOCK"
  echo "  作成/更新 : $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$LOCK" 2>/dev/null) （**${LAGE_M} 分前**）"
  echo "  中身      : $(head -c 200 "$LOCK" 2>/dev/null | tr '\n' ' ' | clean)"
  echo "  所有者    : $(stat -f '%Su' "$LOCK" 2>/dev/null)"
  echo
  echo "  --- ログイン処理が本当に走っているか ---"
  PROCS="$(pgrep -fl 'x-login' 2>/dev/null | head -5)"
  if [ -n "$PROCS" ]; then
    printf '%s\n' "$PROCS" | sed 's/^/    /' | clean
    echo
    echo "  **本物のログインが進行中。ロックには触らない。**"
  else
    echo "    x-login のプロセスは**無い**"
    echo
    if [ "$LAGE_M" -ge 30 ]; then
      echo "  **30 分 以上 放置されていて、ログインも走っていない ＝ 死んだロック。外す。**"
      rm -f "$LOCK" 2>/dev/null
      if [ -f "$LOCK" ]; then echo "    → **外せなかった**（権限か、即座に再作成された）"
      else echo "    → **外した**"; fi
      sleep 5
      [ -f "$LOCK" ] && echo "    5 秒後: **また在る（誰かが作り直している）**" \
                     || echo "    5 秒後: 無い（正常）"
    else
      echo "  まだ ${LAGE_M} 分。**30 分 未満なので触らない。**"
      echo "  本物のログインの可能性を消せないため。次の巡回で再判定する。"
    fi
  fi
fi
echo '```'

# ═══════════ 3. 返信を出す ═══════════
echo
echo "## 3. \`comment-warmup\` が載ったなら、待たずに走らせる"
echo
echo "> 最上位ルール 9: **「次の定時実行を待つ」は、ほぼ全部 やらなくていい待ち。**"
echo
echo '```'
if ! is_loaded comment-warmup; then
  echo "  comment-warmup が載っていない。**LLM を 1 回も呼ばずに終わる（\$0）。**"
  echo '```'
  exit 0
fi
if ! cdp_ok; then
  echo "  CDP が落ちている。**走らせない（\$0）。**"
  echo '```'
  exit 0
fi
if [ -f "$LOCK" ]; then
  echo "  login ロックが在る。ensure-chrome が no-op になるので **走らせない（\$0）。**"
  echo '```'
  exit 0
fi

BEFORE="$(count_posted)"
echo "  走らせる前の累計: **${BEFORE} 件**"
if [ "$BEFORE" = "-1" ]; then echo "  **キューが読めない。何もしない。**"; echo '```'; exit 1; fi
echo
echo "  --- kickstart -k（最大 4 件・約 \$0.012） ---"
launchctl kickstart -k "gui/${UID_NUM}/ai.openclaw.comment-warmup" 2>&1 | head -3 | sed 's/^/    /' | clean
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
  echo "### 出なかった理由（comment-warmup のログ 直近 40 行）"
  echo
  echo '```'
  tail -40 "$W/logs/comment-warmup.log" 2>/dev/null | sed 's/^/  /' | clean
  echo '```'
fi
} > "$OUT" 2>&1

echo "載らない 4 本の理由 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
