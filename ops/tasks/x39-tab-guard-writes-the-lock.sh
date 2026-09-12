#!/bin/bash
# **tab-guard が login ロックを書いていた。それを止める ＋ 外す主を現行犯で押さえる。**
#
# ## x38 で確定した（2026-09-13 01:19）
#
#   パス   : /tmp/x-login-in-progress
#   更新   : 2026-09-13 00:24:13
#   中身   : tab-guard          ← **書いたのは tab-guard**
#
# tab-guard のログの halt 時刻と**秒まで一致する。**
#
#   [2026-09-12T15:24:13.329Z] 🚨 Jordan のタブが 1 → 0 枚 → 自動化を全停止
#                    ↑ 15:24:13Z ＝ JST 00:24:13
#
# **x29 が「誰も作っていない」と報告したのは grep の当て先が違っただけ。**
# `haltAutomation()` が自分でロックを書いている。
#
# ## これが閉じた輪だった
#
#   tab-guard が halt → login ロックを書く
#     → ensure-chrome.sh が rc=0 のまま no-op（Chrome を起動しない）
#     → CDP が落ちてタブが 0 になる
#     → tab-guard が halt →（先頭に戻る）
#
# **`docs/self-healing-deadlock.md` の条件 3「止める対象に、自分を復帰させうるものを
# 入れない」に真正面から違反している。** ロックは復帰経路そのものを塞ぐ。
#
# ## もう 1 つ、外す主が残っている
#
# x38 のセクション 1 では 5/8 が「ロード済み」だったのに、**60 秒後に 4/8 へ減った。**
#
#   30 秒 経過: 5 / 8 本
#   60 秒 経過: 4 / 8 本
#   載っていない: comment-warmup reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat
#
# **その間 tab-guard はログを 1 行も出していない。** 別の主がいる。
#
# ## このタスクがやること
#
#   1. tab-guard.js から **ロックを書く行を探して見せる**（見つからなければ何もしない）
#   2. 見つかったら **その行だけ無効化する。** halt 自体は残す
#   3. **10 秒おきに 3 分 見張り**、ジョブが消えた瞬間に周辺情報を全部 dump する
#   4. 生き残っていれば comment-warmup を走らせて実投稿を数える
#
# ## やらないこと
#
# **Chrome を kill しない。tab-guard を止めない。halt の判定条件を変えない。**
# 変更は `.bak-<日時>` に退避し、`node --check` が通らなければその場で戻す。
#
# 費用: **最大 $0.012**（comment-warmup が生き残った場合の kickstart・最大 4 件）。
# 生き残らなければ **LLM を 1 回も呼ばずに $0 で終わる。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
OUT="${OPS_REPORT_DIR:-/tmp}/tab-guard-writes-the-lock.md"
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
loaded_set() { for j in $EXPECT; do is_loaded "$j" && echo "$j"; done; }

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
echo "# tab-guard が login ロックを書いていた"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"

# ═══════════ 1. ロックを書いている行 ═══════════
echo
echo "## 1. \`tab-guard.js\` のどこがロックを書いているか"
echo
echo '```'
if [ ! -f "$TG" ]; then
  echo "  **$TG が無い。** 以降の修正は行わない。"
  PATCHED=skip
else
  HITS="$(grep -nF 'x-login-in-progress' "$TG" 2>/dev/null)"
  if [ -z "$HITS" ]; then
    echo "  \`x-login-in-progress\` という文字列は tab-guard.js に**無い。**"
    echo "  変数経由で組み立てている可能性がある。周辺を出す。"
    grep -nE 'login|LOCK|lock|writeFileSync' "$TG" 2>/dev/null | head -20 | sed 's/^/    /' | clean
    PATCHED=notfound
  else
    echo "  --- 該当行 ---"
    printf '%s\n' "$HITS" | sed 's/^/    /' | clean
    echo
    echo "  --- 書き込みしている行 ---"
    grep -nE 'writeFileSync|appendFileSync|openSync' "$TG" 2>/dev/null | sed 's/^/    /' | clean
    PATCHED=found
  fi
fi
echo '```'

# ═══════════ 2. 書き込みを無効化する ═══════════
echo
echo "## 2. ロックを書く行だけ無効化する（**halt は残す**）"
echo
echo "止めるのは**ロックの書き込みだけ。** 一括破壊の検知と停止はそのまま残す。"
echo "ロックは \`ensure-chrome.sh\` を no-op にするので、**復帰経路を塞ぐ側の作用しかない。**"
echo
echo '```'
if [ "$PATCHED" != "found" ]; then
  echo "  該当行が特定できていないので**触らない。**（上の出力で次を決める）"
else
  cp "$TG" "$TG.bak-$STAMP" && echo "  退避: $(basename "$TG").bak-$STAMP"
  "$NODE_BIN" -e '
const fs=require("fs");
const p=process.argv[1];
let s=fs.readFileSync(p,"utf8");
const before=s;
// **ロックを書いている行だけをコメントアウトする。** 判定条件・halt 本体は触らない。
s=s.split("\n").map(l=>{
  if(/x-login-in-progress/.test(l) && /(writeFileSync|appendFileSync|openSync)/.test(l)
     && !/^\s*\/\//.test(l)){
    const ind=(l.match(/^\s*/)||[""])[0];
    return ind+"// LOCK_WRITE_DISABLED (2026-09-13): このロックは ensure-chrome.sh を\n"
         + ind+"// no-op にして Chrome の起動を塞ぎ、tab-guard 自身の halt 条件を\n"
         + ind+"// 永久に成立させ続けていた（docs/self-healing-deadlock.md 条件 3）。\n"
         + ind+"// " + l.trim();
  }
  return l;
}).join("\n");
if(s===before){ console.log("  **書き換え対象の行が見つからなかった。何もしていない。**"); process.exit(0); }
fs.writeFileSync(p,s);
console.log("  書き換えた。");
' "$TG" 2>&1 | sed 's/^/  /' | clean

  if "$NODE_BIN" --check "$TG" 2>/dev/null; then
    echo "  node --check: OK"
    grep -n 'LOCK_WRITE_DISABLED' "$TG" 2>/dev/null | head -2 | sed 's/^/    /' | clean
  else
    echo "  **node --check が通らない。戻す。**"
    cp "$TG.bak-$STAMP" "$TG"
    "$NODE_BIN" --check "$TG" 2>&1 | head -3 | sed 's/^/    /' | clean
  fi
fi
echo '```'

# ═══════════ 3. 残っているロックを外す ═══════════
echo
echo "## 3. いまロックが在るなら外す"
echo
echo '```'
if [ ! -f "$LOCK" ]; then
  echo "  ロックは無い（正常）。"
else
  AGE_M=$(( ( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s) ) / 60 ))
  echo "  中身: $(head -c 100 "$LOCK" 2>/dev/null | tr '\n' ' ' | clean) / ${AGE_M} 分前"
  if pgrep -f 'x-login' >/dev/null 2>&1; then
    echo "  **本物のログインが走っている。触らない。**"
  else
    rm -f "$LOCK" 2>/dev/null
    [ -f "$LOCK" ] && echo "  外せなかった" || echo "  **外した**"
  fi
fi
echo '```'

# ═══════════ 4. 消えた瞬間を押さえる ═══════════
echo
echo "## 4. 10 秒おきに 3 分 見張る（**消えた瞬間を押さえる**）"
echo
echo "x38 では 30 秒 → 60 秒 のあいだに 5/8 → 4/8 へ減ったが、"
echo "**tab-guard はログを 1 行も出していない。** 別の主がいる。"
echo
echo '```'
PREV="$(loaded_set | tr '\n' ' ')"
echo "  開始時: $(printf '%s' "$PREV" | wc -w | tr -d ' ') / 8 本"
CAUGHT=0
for t in $(seq 1 18); do
  sleep 10
  NOWSET="$(loaded_set | tr '\n' ' ')"
  GONE=""
  for j in $PREV; do
    case " $NOWSET " in *" $j "*) ;; *) GONE="$GONE $j";; esac
  done
  if [ -n "$GONE" ]; then
    CAUGHT=1
    echo
    echo "  ★ $(date '+%H:%M:%S') **消えた:$GONE**"
    echo "    --- tab-guard ログ 直近 5 行 ---"
    tail -5 "$W/logs/tab-guard.log" 2>/dev/null | sed 's/^/      /' | clean
    echo "    --- いま動いている openclaw 系プロセス ---"
    ps -Ao pid,etime,command 2>/dev/null | grep -iE 'openclaw|launchctl|tab-guard|guardian' \
      | grep -v grep | head -8 | cut -c1-180 | sed 's/^/      /' | clean
    echo "    --- 直近 2 分に更新されたログ ---"
    find "$W/logs" -name '*.log' -newermt '-2M' 2>/dev/null | head -8 | sed 's|.*/|      |'
  fi
  PREV="$NOWSET"
done
FINAL="$(loaded_set | wc -l | tr -d ' ')"
echo
echo "  **3 分後: ${FINAL} / 8 本**"
[ "$CAUGHT" = "0" ] && echo "  3 分 のあいだ 1 本も消えなかった。"
echo '```'

# ═══════════ 5. 走らせる ═══════════
echo
echo "## 5. \`comment-warmup\` が生きていれば、待たずに走らせる"
echo
echo '```'
if ! is_loaded comment-warmup; then
  echo "  comment-warmup が載っていない。**LLM を 1 回も呼ばずに終わる（\$0）。**"
  echo '```'
  exit 0
fi
if ! cdp_ok; then echo "  CDP が落ちている。**走らせない（\$0）。**"; echo '```'; exit 0; fi
if [ -f "$LOCK" ]; then echo "  ロックがまた在る。**走らせない（\$0）。**"; echo '```'; exit 0; fi

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

echo "tab-guard がロックを書いていた / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
