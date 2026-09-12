#!/bin/bash
# **止まっていることが 30 分以内に分かるようにする。費用 $0。**
#
# ## なぜ要るか（2026-09-08〜12 に実際に起きたこと）
#
# `/tmp/x-login-in-progress` という鍵が刺さっていて、`ensure-chrome.sh` が
# **`exit 0` で何もせずに返っていた。** rc=0 なので呼び出し側からは成功に見える。
# **26 本のジョブが、エラーを 1 行も出さずに空振りし続けた。**
#
#   気づくまで: **2 日**
#   その間の実投稿: **0 件**
#
# 同時に `ai.openclaw.*` が **67 本 アンロード**されていたのも、
# heartbeat の `job_count` を**人が見に行かない限り**分からなかった。
#
# ## 入れるもの（heartbeat.json に 3 つ足すだけ）
#
#   "login_lock": { "present": true, "age_hours": 51, "path": "/tmp/x-login-in-progress" }
#   "cdp":        { "healthy": false, "port": 18810, "detail": "..." }
#   "x_jobs":     { "loaded": 1, "expected": 8, "missing": ["comment-warmup", ...] }
#
# **これが出ていれば、次は 30 分で気づける。**
#
# ## 安全側
#
#   * `ops-heartbeat.sh` を**変更前に `.bak-<日時>` へ退避**
#   * `bash -n` が通らなければ**その場で戻す**
#   * 追記は**既存の JSON を壊さない形**（末尾の `}` の直前に差し込む）
#   * **ジョブを触らない。Chrome を触らない。投稿しない。LLM を呼ばない。**
set -uo pipefail

OUT="${OPS_REPORT_DIR:-/tmp}/heartbeat-visibility.md"
W="$HOME/.openclaw/workspace"
S="$W/scripts"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(gh[pousr]_)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 止まっていることが 30 分以内に分かるようにする"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 2026-09-08〜12、\`/tmp/x-login-in-progress\` が刺さったまま"
echo "> **26 本のジョブがエラーを 1 行も出さずに空振りした。気づくまで 2 日。**"
echo "> \`ensure-chrome.sh\` は \`exit 0\` で返すので、**rc では検知できない。**"

# ═══════════ 1. heartbeat の本体を探す ═══════════
echo
echo "## 1. \`ops-heartbeat.sh\` はどこにあるか"
echo
echo '```'
HB=""
for c in "$HOME/ops-heartbeat.sh" "$HOME/openclaw/ops-heartbeat.sh" \
         "$W/ops-heartbeat.sh" "$S/ops-heartbeat.sh" \
         "$HOME/projects/anta-baka-x/blog/ops/ops-heartbeat.sh"; do
  [ -f "$c" ] && { HB="$c"; break; }
done
if [ -z "$HB" ]; then
  HB="$(find "$HOME" -maxdepth 4 -name 'ops-heartbeat.sh' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
fi
if [ -n "$HB" ] && [ -f "$HB" ]; then
  echo "  **有る**: $HB"
  echo "    $(wc -l < "$HB" | tr -d ' ') 行 / 更新 $(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$HB" 2>/dev/null)"
else
  echo "  **見つからない。** launchd の plist から辿る:"
  P="$HOME/Library/LaunchAgents/com.dailyhack.ops-heartbeat.plist"
  [ -f "$P" ] && plutil -p "$P" 2>/dev/null | grep -iE 'Program|Arguments|=>' | head -8 | sed 's/^/    /'
fi
echo '```'
if [ -z "$HB" ] || [ ! -f "$HB" ]; then
  echo
  echo "**本体が見つからないので何も変更しない。** 当て推量でファイルを作らない。"
  exit 1
fi

echo
echo "### JSON を組み立てている箇所"
echo
echo '```bash'
grep -nE 'job_count|unloaded_count|generated_at|"auth"|cat >|heredoc|JSON|EOF' "$HB" 2>/dev/null \
  | head -20 | cut -c1-165 | sed 's/^/  /' | clean
echo '```'

# ═══════════ 2. 追記する値を、まず実際に計算してみる ═══════════
echo
echo "## 2. 足す 3 つの値（**いまの実値**）"
echo
echo '```'
LOCK=/tmp/x-login-in-progress
if [ -f "$LOCK" ]; then
  MT="$(stat -f '%m' "$LOCK" 2>/dev/null || echo 0)"
  AGE=$(( ( $(date '+%s') - MT ) / 3600 ))
  echo "  login_lock : **有る** / ${AGE} 時間 経過 / $LOCK"
else
  echo "  login_lock : 無い（正常）"
fi

if [ -f "$S/cdp-health.js" ]; then
  CH="$( cd "$S" && /usr/local/bin/node "$S/cdp-health.js" 2>&1 | head -c 200 )"
  echo "  cdp        : $(printf '%s' "$CH" | clean)"
else
  curl -s --max-time 5 http://127.0.0.1:18810/json/version >/dev/null 2>&1 \
    && echo "  cdp        : ポートは応答（健全性は未確認）" \
    || echo "  cdp        : **応答なし**"
fi

EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
LOADED=0; MISSING=""
for j in $EXPECT; do
  if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
    LOADED=$((LOADED+1))
  else
    MISSING="$MISSING $j"
  fi
done
echo "  x_jobs     : ロード ${LOADED} / 期待 8"
[ -n "$MISSING" ] && echo "               **欠け:$MISSING**"
echo '```'
echo
echo "**この 3 行が 30 分ごとに出ていれば、次は 2 日も気づかずに済む。**"

# ═══════════ 3. 追記する ═══════════
echo
echo "## 3. \`ops-heartbeat.sh\` に組み込む"
echo
echo "**変更前に退避する。** 通らなければその場で戻す。"
echo
echo '```'
cp -p "$HB" "$HB.bak-$STAMP" && echo "  退避: $(basename "$HB").bak-$STAMP"

if grep -q 'X_HEALTH_BLOCK' "$HB" 2>/dev/null; then
  echo "  既に入っている。触らない。"
else
  # heartbeat.json を書き出す直前に、3 つの値を環境変数へ用意する関数を足す
  python3 - "$HB" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

BLOCK = r'''
# X_HEALTH_BLOCK (2026-09-12): 止まっていることを 30 分で見えるようにする。
# 2026-09-08〜12、/tmp/x-login-in-progress が刺さったまま 26 本のジョブが
# エラーを出さずに空振りした（気づくまで 2 日）。ensure-chrome.sh は exit 0 で
# 返すため rc では検知できない。**値として出すしかない。**
x_health_json() {
  local lock=/tmp/x-login-in-progress
  local lp="false" lage=0
  if [ -f "$lock" ]; then
    lp="true"
    lage=$(( ( $(date '+%s') - $(stat -f '%m' "$lock" 2>/dev/null || echo 0) ) / 3600 ))
  fi

  local cdp="false"
  if [ -f "$HOME/.openclaw/workspace/scripts/cdp-health.js" ]; then
    ( cd "$HOME/.openclaw/workspace/scripts" \
      && /usr/local/bin/node cdp-health.js >/dev/null 2>&1 ) && cdp="true"
  fi

  local expect="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
  local loaded=0 missing="" j
  for j in $expect; do
    if launchctl list 2>/dev/null | grep -qF "ai.openclaw.$j"; then
      loaded=$((loaded+1))
    else
      missing="$missing\"$j\","
    fi
  done
  missing="${missing%,}"

  # **いちばん大事な指標**: 最後に返信が X に出た時刻（キューの x_tweet_id ＝ 一次情報）
  local last_reply="null" reply_age=-1 stale="false"
  local q="$HOME/.openclaw/workspace/data/post_queue.json"
  if [ -f "$q" ]; then
    local r
    r=$(/usr/local/bin/node -e '
const fs=require("fs");
try{
  const q=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  const rows=(q.queue||[]).filter(e=>e&&(e.kind==="comment"||e.kind==="reply")&&(e.x_tweet_id||e.tweet_id));
  const t=rows.map(e=>new Date(e.posted_at||e.created_at||0).getTime()).filter(n=>n>0);
  if(!t.length){ console.log("null -1"); process.exit(0); }
  const m=Math.max.apply(null,t);
  console.log(JSON.stringify(new Date(m).toISOString())+" "+Math.floor((Date.now()-m)/3600000));
}catch(e){ console.log("null -1"); }
' "$q" 2>/dev/null) || r="null -1"
    last_reply="${r%% *}"; reply_age="${r##* }"
    [ "${reply_age:-99}" -ge 8 ] 2>/dev/null && stale="true"
  fi

  printf '"login_lock":{"present":%s,"age_hours":%s,"path":"%s"},"cdp":{"healthy":%s,"port":18810},"x_jobs":{"loaded":%s,"expected":8,"missing":[%s]},"last_reply":{"at":%s,"age_hours":%s,"stale":%s}' \
    "$lp" "$lage" "$lock" "$cdp" "$loaded" "$missing" "$last_reply" "$reply_age" "$stale"
}
'''

# 先頭の set 行の直後（無ければ shebang の直後）に関数を置く
m = re.search(r'^set [^\n]*\n', s, re.M)
if m:
    s = s[:m.end()] + BLOCK + s[m.end():]
else:
    lines = s.split("\n", 1)
    s = lines[0] + "\n" + BLOCK + (lines[1] if len(lines) > 1 else "")

# JSON の "generated_at" の直後に差し込む。
# **ただし $(...) が展開される書き方か確かめてから。**
# クォート付きヒアドキュメント (<<'EOF') の中だと展開されず、
# リテラルの "$(x_health_json)" が JSON に入って**壊れる**。
m2 = re.search(r'"generated_at"\s*:\s*[^\n]*', s)
if not m2:
    print("  JSON への差し込み: **できない（generated_at が見つからない）**")
    print("  → 関数だけ置いた。差し込みは手で行う必要がある。")
    open(p, "w", encoding="utf-8").write(s)
    raise SystemExit(0)

head = s[:m2.start()]
# 直前のヒアドキュメント開始を探す
hd = None
for mm in re.finditer(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", head):
    hd = mm
expandable = True
why = "ヒアドキュメントの外（または展開される書き方）"
if hd:
    quoted = hd.group(1) != ""
    delim = hd.group(2)
    # そのヒアドキュメントが generated_at より前に閉じているか
    closed = re.search(r'^\s*' + re.escape(delim) + r'\s*$', head[hd.end():], re.M)
    if not closed:
        expandable = not quoted
        why = ("<<'" + delim + "' はクォート付き＝**展開されない**") if quoted \
              else ("<<" + delim + " は展開される")

if not expandable:
    print("  JSON への差し込み: **やめた** — " + why)
    print("  → リテラルの $(x_health_json) が JSON に入って壊れるため。")
    print("  → 関数だけ置いた。差し込み方は人が決める。")
    open(p, "w", encoding="utf-8").write(s)
    raise SystemExit(0)

before = s
s = re.sub(r'("generated_at"\s*:\s*"[^"]*"\s*,)',
           r'\1\n  $(x_health_json),', s, count=1)
open(p, "w", encoding="utf-8").write(s)
print("  関数を追加した（" + why + "）")
print("  JSON への差し込み: " + ("できた" if s != before else "**パターンが合わず できない**"))
PY
fi
echo '```'

echo
echo "### 構文チェック（**通らなければ戻す**）"
echo
echo '```'
if bash -n "$HB" 2>&1 | clean; then
  echo "  bash -n: OK"
else
  echo "  **構文エラー。退避から戻す。**"
  cp -p "$HB.bak-$STAMP" "$HB"
  echo "  戻した。"
fi
echo '```'

echo
echo "### 入った差分"
echo
echo '```diff'
diff -u "$HB.bak-$STAMP" "$HB" 2>/dev/null | head -60 | clean
echo '```'

echo
echo "## 4. 戻し方"
echo
echo '```bash'
echo "cp -p $HB.bak-$STAMP $HB"
echo '```'

echo
echo "---"
echo
echo "## 次の heartbeat で確認すること"
echo
echo "\`ops/heartbeat\` の \`heartbeat.json\` に、この 3 つが出ていれば成功。"
echo
echo '```json'
echo '  "login_lock": { "present": false, "age_hours": 0, "path": "/tmp/x-login-in-progress" },'
echo '  "cdp":        { "healthy": true, "port": 18810 },'
echo '  "x_jobs":     { "loaded": 8, "expected": 8, "missing": [] }'
echo '```'
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **この タスク**（LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| **足した 3 項目**（30 分ごと・48 回/日・LLM 不使用） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**ジョブも Chrome も触っていない。投稿もしていない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
R="$(grep -m1 -oE 'bash -n: OK|\*\*構文エラー' "$OUT" 2>/dev/null || echo '結果不明')"
J="$(grep -m1 -oE 'x_jobs     : ロード [0-9]+ / 期待 8' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') heartbeat に鍵・CDP・ジョブ数を追加（\$0）** / $R / $J / $(basename "$OUT")"
