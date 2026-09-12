#!/bin/bash
# **毎日 必ず実行されるようにする番人を常駐化する。最大 $0.024/日（内訳は下）。**
#
# > 毎日ちゃんと実行されていないジョブがあるのは非常に困るので、必ず実行される
# > ような体制を作って欲しい。基準をゆるめるなど、考えを狭くせず、いろんな手段を
# > 考えたうえで取り組んでね
#
# ## 実際に止まった原因と、効く対策（**しきい値は一切 触らない**）
#
# | 止まった原因（実測） | 効く対策 |
# | --- | --- |
# | tab-guard が全 unload → ジョブごと消えた | 走っていなければ**載せ直して走らせる** |
# | login ロックで `ensure-chrome` が no-op | **前提を番人が自分で直す** |
# | CDP 断 | 同上 |
# | `StartInterval` はスリープ/電源断で**その回が消える** | **`StartCalendarInterval` に寄せる** |
# | 走ったか分からない | **成功の印を残す** |
# | 4 日 誰も気づかない | Slack ＋ GitHub Actions（済） |
#
# ## いちばんの穴: **誰も「成功の印」を書いていない**
#
# 判定はログの更新時刻からの推測だけで、**「走って失敗した」と「走っていない」を
# 区別できない。** 実際、`x38` で「ロード済み・LastExitStatus 0」と出ているのに
# **返信は 75 時間 出ていなかった。**
#
# **`launchctl list` に出ることは、仕事をした証拠にならない**（最上位ルール 13）。
#
# ## 番人がやること（**8 本 それぞれについて**）
#
#   1. **今日 走ったか**を観測できる事実で判定する（ログに今日の行があるか）
#   2. 走っていなければ:
#        a. 前提を直す（login ロックを外す → CDP を healthy にする → 未ロードなら bootstrap）
#        b. `kickstart -k` で走らせる
#        c. 待って**もう一度 判定する**
#   3. 結果を `data/job-stamps/status.json` に書く
#   4. それでも走らないものが在れば **Slack に 1 回だけ**鳴らす
#
# **「kickstart した」で終わらせない。走った証拠を取り直すところまでやる。**
#
# ## 起動方式も直す
#
# `StartInterval` は「前回から N 秒」で数えるので、**Mac が寝ていた分は消える。**
# `StartCalendarInterval` なら**起動後に 1 回 まとめて発火する。**
# 番人自身は**カレンダー（05:00 と 17:00 JST）＋ `RunAtLoad`** で載せる。
#
# ## 費用
#
# **番人そのものは LLM を呼ばない（$0）。**
# 追い上げで `comment-warmup` を走らせたときだけ返信の生成が走る。
#
#   追い上げ 1 回: 最大 4 件 × $0.003 = **$0.012**
#   1 日あたり    : 05:00 と 17:00 の 2 回 ＝ **最大 $0.024**
#   1 か月あたり  : **最大 $0.72**
#
# **これは「定時が走らなかった日」だけ発生する上限で、実績ではない。**
# 定時が正常に走っていれば追い上げは 0 回 ＝ **$0**。
# 定時の返信ループ自体は 推定 1日 約 $0.19 ／ 1か月 約 $5.8
# （前提: Haiku 4.5・通過率 25%・生成 64 回/日）。
#
# ## やらないこと
#
# **しきい値を緩めない。1 日の上限を上げない。Chrome を kill しない。**
# **tab-guard を止めない。** ジョブの中身は書き換えない。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/daily-supervisor.md"
NODE_BIN="/usr/local/bin/node"
UID_NUM="$(id -u)"
LABEL="ai.openclaw.daily-supervisor"
SH="$S/daily-supervisor.sh"
PLIST="$LA/$LABEL.plist"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(AKIA|ghp_|xoxb-)[A-Za-z0-9_-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# ─── 番人 本体。引用符つきヒアドキュメント＝シェルは中身を解釈しない ───
cat > "$SH.new" <<'SHEOF'
#!/bin/bash
# X 運用ジョブの番人。**「今日 走ったか」を観測できる事実で判定し、走っていなければ走らせる。**
#
# 2026-09-13 作成。LLM は呼ばない（$0）。
# 例外は comment-warmup の追い上げで、そこだけ返信の生成が走る（最大 4 件・$0.012）。
#
# **「kickstart した」で終わらせない。走った証拠を取り直すところまでやる。**
set -uo pipefail

W="${OPS_WS:-$HOME/.openclaw/workspace}"
S="$W/scripts"
D="$W/data"
LA="$HOME/Library/LaunchAgents"
LOGD="$W/logs"
LOG="$LOGD/daily-supervisor.log"
STATUS="$D/job-stamps/status.json"
UID_NUM="$(id -u)"
LOCK=/tmp/x-login-in-progress
NODE_BIN="${NODE_BIN:-/usr/local/bin/node}"
ALERT_STAMP=/tmp/.x-supervisor-alerted
MAX_FIX="${MAX_FIX:-3}"

mkdir -p "$D/job-stamps" "$LOGD" 2>/dev/null || true

log() { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*" | tee -a "$LOG" >/dev/null; }

# 監視するジョブ。**CDP が要るか**で分けている。
#   要る   … Chrome が健全でないと走らせても無駄
#   要らない … Chrome の状態に関係なく走らせてよい
JOBS_CDP="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup mutual-prune"
JOBS_NOCDP="incoming-reply-watcher pipeline-heartbeat"

snapshot() { launchctl list 2>/dev/null | awk '{print $3}'; }
is_loaded() { printf '%s\n' "$1" | grep -qxF "ai.openclaw.$2"; }

cdp_ok() { [ -f "$S/cdp-health.js" ] && ( cd "$S" && "$NODE_BIN" cdp-health.js >/dev/null 2>&1 ); }

# **今日 走ったか。** ログに今日（JST）の行が在るかで見る。
# 完璧ではないが、`launchctl list` に出ることより遥かに実態に近い。
ran_today() {
  local j="$1" f="$LOGD/$1.log" t
  t="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  [ -f "$f" ] || return 1
  # ログの行頭が [ISO8601] のものと、そうでないものの両方に当たるようにする
  grep -aq "$t" "$f" 2>/dev/null && return 0
  # mtime が今日ならそれも証拠として扱う
  local m; m="$(TZ=Asia/Tokyo stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null || echo '')"
  [ "$m" = "$t" ]
}

# ── 前提を直す（**推測で壊さない。直せる分だけ直す**） ──
fix_prereq() {
  local fixed=""
  # 1. 死んだ login ロック。x-login が走っていなければ外す
  if [ -f "$LOCK" ]; then
    if pgrep -f 'x-login' >/dev/null 2>&1; then
      log "  login ロック: 本物のログインが走っている。触らない"
    else
      local age; age=$(( ( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || date +%s) ) / 60 ))
      if [ "$age" -ge 30 ]; then rm -f "$LOCK" 2>/dev/null; fixed="$fixed lock"; log "  login ロック: ${age} 分 放置 → 外した"; fi
    fi
  fi
  # 2. CDP。**kill しない。** ensure-chrome に任せる（自動再ログインもそこに在る）
  if ! cdp_ok; then
    if [ -x "$S/ensure-chrome.sh" ]; then
      ( cd "$W" && "$S/ensure-chrome.sh" ) >/dev/null 2>&1 || true
      sleep 10
      cdp_ok && { fixed="$fixed cdp"; log "  CDP: ensure-chrome で健全になった"; } || log "  CDP: **まだ落ちている**"
    else
      log "  CDP: ensure-chrome.sh が無い"
    fi
  fi
  # 3. 未ロードのジョブを載せ直す（tab-guard の全 unload からの復帰）
  local snap; snap="$(snapshot)"
  local j n=0
  for j in $JOBS_CDP $JOBS_NOCDP; do
    is_loaded "$snap" "$j" && continue
    [ -f "$LA/ai.openclaw.$j.plist" ] || continue
    launchctl bootout "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
    launchctl enable "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/${UID_NUM}" "$LA/ai.openclaw.$j.plist" >/dev/null 2>&1 || true
    n=$((n+1))
  done
  [ "$n" -gt 0 ] && { fixed="$fixed load:$n"; log "  未ロード ${n} 本を載せ直した"; }
  echo "$fixed"
}

log "=== daily-supervisor start ==="
FIXED="$(fix_prereq)"
SNAP="$(snapshot)"
CDPOK=false; cdp_ok && CDPOK=true

ROWS=""; NG=""
for j in $JOBS_CDP $JOBS_NOCDP; do
  NEEDCDP=false
  case " $JOBS_CDP " in *" $j "*) NEEDCDP=true;; esac
  LOADED=false; is_loaded "$SNAP" "$j" && LOADED=true
  RAN=false; ran_today "$j" && RAN=true
  ATT=0

  if [ "$RAN" = "false" ] && [ "$LOADED" = "true" ]; then
    if [ "$NEEDCDP" = "true" ] && [ "$CDPOK" = "false" ]; then
      log "  $j: 今日 走っていないが CDP が落ちている → 走らせない"
    else
      while [ "$ATT" -lt "$MAX_FIX" ] && [ "$RAN" = "false" ]; do
        ATT=$((ATT+1))
        log "  $j: 今日 走っていない → kickstart (${ATT}/${MAX_FIX})"
        launchctl kickstart -k "gui/${UID_NUM}/ai.openclaw.$j" >/dev/null 2>&1 || true
        sleep 45
        ran_today "$j" && RAN=true
      done
      [ "$RAN" = "true" ] && log "  $j: **走った（ログに今日の行が出た）**" \
                          || log "  $j: **${ATT} 回 試したが走った証拠が出ない**"
    fi
  fi

  [ "$RAN" = "false" ] && NG="$NG $j"
  ROWS="$ROWS{\"job\":\"$j\",\"loaded\":$LOADED,\"ran_today\":$RAN,\"attempts\":$ATT,\"needs_cdp\":$NEEDCDP},"
done
ROWS="${ROWS%,}"

cat > "$STATUS" <<JSONEOF
{
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "date_jst": "$(TZ=Asia/Tokyo date '+%Y-%m-%d')",
  "cdp_healthy": $CDPOK,
  "login_lock": $( [ -f "$LOCK" ] && echo true || echo false ),
  "fixed": "$(printf '%s' "${FIXED# }")",
  "not_run": "$(printf '%s' "${NG# }")",
  "jobs": [$ROWS]
}
JSONEOF

if [ -n "$NG" ]; then
  log "**今日 走っていないもの:$NG**"
  if [ ! -f "$ALERT_STAMP" ] && [ -f "$HOME/openclaw/config/.env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/openclaw/config/.env" 2>/dev/null || true
    if [ -n "${OPENCLAW_BOT_TOKEN:-}" ]; then
      curl -s -X POST https://slack.com/api/chat.postMessage \
        -H "Authorization: Bearer $OPENCLAW_BOT_TOKEN" \
        -H 'Content-type: application/json; charset=utf-8' \
        --data "$(printf '{"channel":"C0B4CJHH797","text":"%s"}' \
          ":rotating_light: *追い上げても走らないジョブ:${NG}* ／ CDP healthy=${CDPOK}")" \
        >/dev/null 2>&1 && touch "$ALERT_STAMP"
    fi
  fi
else
  rm -f "$ALERT_STAMP" 2>/dev/null
  log "全部 走った"
fi

# ログが太らないように
[ -f "$LOG" ] && [ "$(wc -l < "$LOG" | tr -d ' ')" -gt 3000 ] && \
  { tail -1500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
log "=== daily-supervisor done ==="
exit 0
SHEOF

{
echo "# 毎日 必ず実行されるようにする番人"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 毎日ちゃんと実行されていないジョブがあるのは非常に困るので、必ず実行される"
echo "> ような体制を作って欲しい。基準をゆるめるなど、考えを狭くせず、いろんな手段を"
echo "> 考えたうえで取り組んでね"

# ═══════════ 0. いちばんの穴 ═══════════
echo
echo "## 0. いちばんの穴: **誰も「成功の印」を書いていない**"
echo
echo "判定はログの更新時刻からの推測だけで、**「走って失敗した」と「走っていない」を"
echo "区別できない。** 実際 \`x38\` では次のように出ていた。"
echo
echo '```'
echo "  comment-warmup  **ロード済み。触らない。**  \"LastExitStatus\" = 0;"
echo '```'
echo
echo "**それでも返信は 75 時間 出ていなかった。**"
echo "\`launchctl list\` に出ることは、仕事をした証拠にならない（最上位ルール 13）。"

# ═══════════ 1. 番人を置く ═══════════
echo
echo "## 1. 番人を置く"
echo
echo "**8 本 ＋ mutual-prune の 9 本**について、次をやる。"
echo
echo "1. **今日 走ったか**を観測できる事実で判定する（ログに今日 JST の行が在るか）"
echo "2. 走っていなければ"
echo "   a. **前提を直す**（死んだ login ロックを外す → \`ensure-chrome\` で CDP → 未ロードなら bootstrap）"
echo "   b. \`kickstart -k\` で走らせる"
echo "   c. 待って**もう一度 判定する**（最大 3 回）"
echo "3. 結果を \`data/job-stamps/status.json\` に書く"
echo "4. それでも走らないものが在れば **Slack に 1 回だけ**鳴らす"
echo
echo "**「kickstart した」で終わらせない。走った証拠を取り直すところまでやる。**"
echo
echo '```'
if ! bash -n "$SH.new" 2>/dev/null; then
  echo "  **構文エラー。置かない。**"
  bash -n "$SH.new" 2>&1 | head -5 | sed 's/^/    /'
  rm -f "$SH.new"; echo '```'; exit 1
fi
echo "  bash -n: OK（$(wc -l < "$SH.new" | tr -d ' ') 行）"
[ -f "$SH" ] && cp "$SH" "$SH.bak-$STAMP" && echo "  既存を退避: $(basename "$SH").bak-$STAMP"
mv "$SH.new" "$SH" && chmod +x "$SH"
echo "  置いた: $SH"
echo '```'

# ═══════════ 2. 起動方式 ═══════════
echo
echo "## 2. 起動方式を \`StartCalendarInterval\` にする"
echo
echo "\`StartInterval\` は「前回から N 秒」で数えるので、**Mac が寝ていた分は消える。**"
echo "\`StartCalendarInterval\` なら**起動後に 1 回 まとめて発火する。**"
echo
echo "番人は **05:00 と 17:00 JST ＋ \`RunAtLoad\`** で載せる。"
echo "**1 日 2 回 ある**ので、片方が寝ていても もう片方で拾える。"
echo
echo '```xml'
[ -f "$PLIST" ] && cp -p "$PLIST" "$PLIST.bak-$STAMP"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SH</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>5</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>17</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$W/logs/daily-supervisor.out</string>
  <key>StandardErrorPath</key><string>$W/logs/daily-supervisor.err</string>
  <key>WorkingDirectory</key><string>$W</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>OPS_WS</key><string>$W</string>
    <key>MAX_FIX</key><string>3</string>
  </dict>
</dict>
</plist>
PLISTEOF
cat "$PLIST" | clean
echo '```'
echo
echo '```'
if plutil -lint "$PLIST" >/dev/null 2>&1; then
  echo "  plutil -lint: OK"
  launchctl bootout "gui/${UID_NUM}/$LABEL" >/dev/null 2>&1 || true
  launchctl enable "gui/${UID_NUM}/$LABEL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/${UID_NUM}" "$PLIST" 2>&1 | head -3 | sed 's/^/    /' | clean
  sleep 3
  SNAP="$(launchctl list 2>/dev/null | awk '{print $3}')"
  if printf '%s\n' "$SNAP" | grep -qxF "$LABEL"; then
    echo "  **載った（\`launchctl list\` に出た）** ← rc は見ない"
  else
    echo "  **載っていない。**"
    launchctl print "gui/${UID_NUM}/$LABEL" 2>&1 | head -6 | sed 's/^/    /' | clean
  fi
else
  echo "  **plist が壊れている。ロードしない。**"
  [ -f "$PLIST.bak-$STAMP" ] && cp -p "$PLIST.bak-$STAMP" "$PLIST"
fi
echo '```'

# ═══════════ 3. その場で 1 回 走らせる ═══════════
echo
echo "## 3. その場で 1 回 走らせる（**待たない**・最上位ルール 9）"
echo
echo "**追い上げで \`comment-warmup\` が走ると返信の生成が起きる（最大 4 件・\$0.012）。**"
echo "他のジョブは LLM を呼ばないので \$0。"
echo
echo '```'
( cd "$W" && OPS_WS="$W" MAX_FIX=2 timeout 900 bash "$SH" ) 2>&1 | tail -40 | cut -c1-240 | sed 's/^/  /' | clean
echo '```'
echo
echo "### 出来上がった \`status.json\`"
echo
echo '```json'
cat "$D/job-stamps/status.json" 2>/dev/null | head -40 | sed 's/^/  /' | clean || echo "  （まだ無い）"
echo '```'

# ═══════════ 4. 費用 ═══════════
echo
echo "## 4. 費用"
echo
echo "**番人そのものは LLM を呼ばない（\$0）。**"
echo "追い上げで \`comment-warmup\` を走らせたときだけ返信の生成が走る。"
echo
echo "| | 金額 |"
echo "| --- | --- |"
echo "| 追い上げ 1 回 | 最大 4 件 × \$0.003 = **\$0.012** |"
echo "| 1 日あたり（05:00・17:00 の 2 回） | 最大 **\$0.024** |"
echo "| 1 か月あたり | 最大 **\$0.72** |"
echo
echo "**これは「定時が走らなかった日」だけ発生する上限で、実績ではない。**"
echo "定時が正常に走っていれば追い上げは 0 回 ＝ **\$0**。"
echo
echo "定時の返信ループ自体は **推定** 1 日 約 \$0.19 ／ 1 か月 約 \$5.8"
echo "（前提: Haiku 4.5・通過率 25%・生成 64 回/日）。"
echo
echo "## 5. 番人自身が死んだら"
echo
echo "\`RunAtLoad\` ＋ **1 日 2 回のカレンダー**なので、Mac が再起動すれば必ず走る。"
echo "そのうえで外からも見ている。"
echo
echo "- \`ops-heartbeat\`（30 分ごと）→ \`last_reply\` が 8 時間 出ていなければ **Slack**"
echo "- \`ops-watchdog\`（GitHub Actions・2 時間ごと）→ **Mac が丸ごと落ちても検知**"
echo
echo "**番人・heartbeat・Actions の 3 段で、どれか 1 つが死んでも気づける。**"
} > "$OUT" 2>&1

echo "番人を常駐化 / $(basename "$OUT") $(wc -l < "$OUT" | tr -d ' ') 行"
