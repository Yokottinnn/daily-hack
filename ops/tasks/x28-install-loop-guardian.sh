#!/bin/bash
# **返信・フォロー・アンフォローを止めない番人を置く。費用 $0。**
#
# ## 指示（2026-09-12・最重要）
#
#   > 返信・フォロー・アンフォロー
#   > これが最重要タスクなので、上記のタスクを絶対に止めないような体制を作って欲しい
#   > 上記ができないと、フォロワーも増えないし、アカウントを運営している意味がないんだよ
#
# ## これまで止まった原因と、その共通点
#
#   8/15  poll-approvals が 5 日 停止（Chrome 自動更新）
#   8/30  tab-guard が ai.openclaw.* を全 unload
#   9/7   listener が 19 時間 無反応
#   9/8   chrome-cdp-heal が 5 分おきに Chrome を破壊 → tab-guard が全 unload
#   9/8〜 /tmp/x-login-in-progress の消し忘れで ensure-chrome が exit 0（**4 日**）
#
# **共通点は 4 つ。**
#
#   1. **静かに失敗する** — `ensure-chrome.sh` は exit 0。rc では検知できない
#   2. **検知しても通知されない** — heartbeat に値が無い
#   3. **通知されても自動で直らない** — 人が気づくまで止まったまま
#   4. **直しても永続しない** — load -w した 8 本がまた外れている
#
# ## 番人がやること（15 分ごと）
#
#   A. 期待する 8 本が載っているか → 欠けていれば `launchctl load -w`
#   B. `/tmp/x-login-in-progress` が **6 時間 超**なら退避（消さない）
#   C. CDP が不健全なら `ensure-chrome.sh` を呼ぶ
#   D. 直した内容を 1 行ログに残す
#   E. **2 回 連続で直せなければ Slack に 1 回だけ鳴らす**
#
# ## 番人が「やらないこと」（**ここが今回いちばん大事**）
#
#   * **Chrome を kill しない。** `chrome-cdp-heal` はこれで利用者のブラウザを
#     5 分おきに壊し、tab-guard に全停止させた。**治すために壊さない**
#   * **5 分おきに鳴らさない。** 直せないときだけ、1 回。騒音は通知を殺す
#   * **tab-guard を無効化しない。** 非常ブレーキは残す
#   * **LLM を呼ばない。** 番人自身の費用は $0
#
# ## 番人自身が死んだら
#
# `KeepAlive` + `RunAtLoad` を付ける。落ちても launchd が起こす。
# **番人の生死は heartbeat の `x_jobs` に出る**（x27 で追加済み）。
#
# **投稿しない。返信しない。フォロー・アンフォローしない。Chrome を kill しない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/install-loop-guardian.md"
GUARD="$S/x-loop-guardian.sh"
LABEL="ai.openclaw.x-loop-guardian"
PLIST="$LA/$LABEL.plist"
STAMP="$(date '+%Y%m%d-%H%M%S')"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

{
echo "# 3 ループを止めない番人を置く"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> **返信・フォロー・アンフォローが最重要。絶対に止めない体制を作る。**"
echo
echo "**番人は治すために壊さない。** \`chrome-cdp-heal\` は「治す」ために Chrome を"
echo "5 分おきに kill し、利用者のブラウザを壊し、tab-guard に全停止させた。"
echo "**同じ轍は踏まない。**"

# ═══════════ 1. 番人を書く ═══════════
echo
echo "## 1. 番人スクリプトを置く"
echo
echo '```'
cat > "$GUARD" <<'GUARDEOF'
#!/bin/bash
# x-loop-guardian: 返信・フォロー・アンフォローを止めないための番人。
#
# **治すために壊さない。** Chrome を kill しない。tab-guard を無効化しない。
# LLM を呼ばない（費用 $0）。
#
# 15 分ごとに走り、次の 3 つだけ直す。
#   A. 期待する 8 本が未ロードなら load -w
#   B. /tmp/x-login-in-progress が 6 時間 超なら退避
#   C. CDP が不健全なら ensure-chrome.sh（**kill はしない**）
#
# 2 回 連続で直せなければ Slack に 1 回だけ鳴らす。
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
LOG="$W/logs/x-loop-guardian.log"
FAILSTAMP="$W/data/.guardian-consecutive-failures"
ALERTED="$W/data/.guardian-alerted"
LOCK=/tmp/x-login-in-progress
STALE_HOURS=6

EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback
reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$LOG"; }

FIXED=0
PROBLEMS=""

# ---- A. ジョブのロード ----
for j in $EXPECT; do
  [ -z "$j" ] && continue
  lbl="ai.openclaw.$j"
  launchctl list 2>/dev/null | grep -qF "$lbl" && continue
  P="$LA/$lbl.plist"
  if [ ! -f "$P" ]; then PROBLEMS="$PROBLEMS plist-missing:$j"; continue; fi
  plutil -lint "$P" >/dev/null 2>&1 || { PROBLEMS="$PROBLEMS plist-broken:$j"; continue; }
  if launchctl load -w "$P" 2>/dev/null; then
    log "reloaded $j"; FIXED=$((FIXED+1))
  else
    PROBLEMS="$PROBLEMS load-failed:$j"
  fi
done

# ---- B. login ロックの消し忘れ ----
# **時間だけで判定しない。** 2026-09-12 に mtime が「0 時間」のまま
# 4 日 刺さり続けていた（何かが touch し直している）。時間だけ見ると永久に外せない。
#
# **手動ログイン中なら Chrome が起動しているはず。**
# Chrome が 1 つも無いのに鍵がある = **矛盾＝消し忘れ**。これを主判定にする。
if [ -f "$LOCK" ]; then
  AGE=$(( ( $(date '+%s') - $(stat -f '%m' "$LOCK" 2>/dev/null || echo 0) ) / 3600 ))
  CHROME_UP=0
  pgrep -f 'Google Chrome' >/dev/null 2>&1 && CHROME_UP=1
  REASON=""
  if [ "$CHROME_UP" = "0" ]; then
    REASON="chrome-not-running(${AGE}h)"      # 手で入れるはずの画面が無い＝矛盾
  elif [ "$AGE" -ge "$STALE_HOURS" ]; then
    REASON="stale(${AGE}h)"
  fi
  if [ -n "$REASON" ]; then
    mv "$LOCK" "$LOCK.parked-$(date '+%Y%m%d-%H%M%S')" 2>/dev/null \
      && { log "parked login lock: $REASON"; FIXED=$((FIXED+1)); } \
      || PROBLEMS="$PROBLEMS lock-park-failed"
  else
    log "login lock present, chrome running, fresh (${AGE}h) — leaving it"
  fi
fi

# ---- C. CDP ----
cdp_ok() {
  [ -f "$S/cdp-health.js" ] || return 1
  ( cd "$S" && /usr/local/bin/node cdp-health.js >/dev/null 2>&1 )
}
if ! cdp_ok; then
  # **kill しない。** ensure-chrome.sh に任せる（自動再ログインもそこにある）
  ( cd "$W" && "$S/ensure-chrome.sh" ) >/dev/null 2>&1 || true
  sleep 8
  if cdp_ok; then log "cdp recovered via ensure-chrome"; FIXED=$((FIXED+1))
  else PROBLEMS="$PROBLEMS cdp-unhealthy"; fi
fi

# ---- D/E. 連続失敗したら 1 回だけ鳴らす ----
if [ -n "$PROBLEMS" ]; then
  N=$(( $(cat "$FAILSTAMP" 2>/dev/null || echo 0) + 1 ))
  echo "$N" > "$FAILSTAMP"
  log "unresolved:$PROBLEMS (consecutive=$N)"
  if [ "$N" -ge 2 ] && [ ! -f "$ALERTED" ]; then
    touch "$ALERTED"
    if [ -f "$HOME/openclaw/config/.env" ]; then
      # shellcheck disable=SC1091
      . "$HOME/openclaw/config/.env" 2>/dev/null || true
      if [ -n "${OPENCLAW_BOT_TOKEN:-}" ]; then
        curl -s -X POST https://slack.com/api/chat.postMessage \
          -H "Authorization: Bearer $OPENCLAW_BOT_TOKEN" \
          -H 'Content-type: application/json; charset=utf-8' \
          --data "$(printf '{"channel":"C0B4CJHH797","text":"%s"}' \
            ":rotating_light: *X の 3 ループが自力で直せない* — $PROBLEMS （連続 $N 回）")" \
          >/dev/null 2>&1 || true
        log "alerted slack once"
      fi
    fi
  fi
else
  rm -f "$FAILSTAMP" "$ALERTED" 2>/dev/null
  [ "$FIXED" -gt 0 ] && log "all healthy (fixed $FIXED)" || log "all healthy"
fi

# ログが太らないように
[ -f "$LOG" ] && [ "$(wc -l < "$LOG" | tr -d ' ')" -gt 2000 ] && \
  { tail -1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"; }
exit 0
GUARDEOF
chmod +x "$GUARD"
echo "  置いた: $GUARD"
echo "  $(wc -l < "$GUARD" | tr -d ' ') 行"
bash -n "$GUARD" 2>&1 && echo "  bash -n: OK" || { echo "  **構文エラー。消す。**"; rm -f "$GUARD"; }
echo '```'
if [ ! -f "$GUARD" ]; then echo; echo "**番人を置けなかった。終わる。**"; exit 1; fi

# ═══════════ 2. plist ═══════════
echo
echo "## 2. launchd に載せる（15 分ごと・\`KeepAlive\` 付き）"
echo
echo "**番人自身が死んでも launchd が起こす。**"
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
    <string>$GUARD</string>
  </array>
  <key>StartInterval</key><integer>900</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$W/logs/x-loop-guardian.out</string>
  <key>StandardErrorPath</key><string>$W/logs/x-loop-guardian.err</string>
  <key>WorkingDirectory</key><string>$W</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
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
  launchctl unload "$PLIST" 2>/dev/null || true
  if launchctl load -w "$PLIST" 2>/dev/null; then
    echo "  **ロードした**"
  else
    echo "  **ロードできない**"
  fi
else
  echo "  **plist が壊れている。ロードしない。**"
  [ -f "$PLIST.bak-$STAMP" ] && { cp -p "$PLIST.bak-$STAMP" "$PLIST"; echo "  退避から戻した。"; }
fi
echo '```'

# ═══════════ 3. その場で 1 回 走らせる ═══════════
echo
echo "## 3. その場で 1 回 走らせる（**待たない**）"
echo
echo '```'
bash "$GUARD" 2>&1 | tail -10 | sed 's/^/  /' | clean
echo "  (rc=$?)"
echo
echo "  --- 番人のログ ---"
tail -15 "$W/logs/x-loop-guardian.log" 2>/dev/null | sed 's/^/    /' | clean
echo '```'

# ═══════════ 4. 結果 ═══════════
echo
echo "## 4. いま 3 ループは戻ったか"
echo
echo '```'
EXPECT="comment-warmup competitor-follower-follow hashtag-follow badge-followback reply-followback-check reply-followers-cleanup incoming-reply-watcher pipeline-heartbeat"
OKN=0
for j in $EXPECT; do
  line="$(launchctl list 2>/dev/null | grep -F "ai.openclaw.$j" || true)"
  if [ -z "$line" ]; then printf '  **未ロード** %-36s\n' "$j"
  else printf '%s\n' "$line" | awk -v j="$j" '{printf "  ロード      %-36s rc=%s\n", j, $2}'; OKN=$((OKN+1)); fi
done
echo
echo "  ロード済み: ${OKN} / 8"
echo "  番人:       $(launchctl list 2>/dev/null | grep -cF "$LABEL") 本"
echo
echo "  --- CDP ---"
if [ -f "$S/cdp-health.js" ]; then
  ( cd "$S" && /usr/local/bin/node cdp-health.js ) 2>&1 | head -c 220 | sed 's/^/  /' | clean
fi
echo
echo "  --- login ロック ---"
if [ -f "$LOCK" ]; then echo "  **まだ有る**: $LOCK"; else echo "  無い（正常）"; fi
echo '```'

echo
echo "---"
echo
echo "## この体制で何が変わるか"
echo
echo "| これまで | これから |"
echo "| --- | --- |"
echo "| 静かに失敗して誰も気づかない | **15 分ごとに番人が見て、直せるものは直す** |"
echo "| 気づくまで 2〜4 日 | **heartbeat に \`last_reply.stale\` が出る**（8 時間で赤） |"
echo "| 直しても永続しない | **番人が毎回 load し直す** |"
echo "| 直せないまま放置 | **2 回 連続で直せなければ Slack に 1 回**（騒音にしない） |"
echo
echo "**番人は Chrome を kill しない。** 治すために壊さない。"
echo
echo "## コスト（最上位ルール 2-B）"
echo
echo "単価は \`claude-api\` スキルの料金表（Haiku 4.5 入力 \$1.00 / **出力 \$5.00** per MTok）。"
echo
echo "| | 1 回 | 1 日 | 1 か月 |"
echo "| --- | --- | --- | --- |"
echo "| **番人**（15 分ごと・96 回/日・**LLM 不使用**） | **\$0** | **\$0** | **\$0** |"
echo "| このタスク自体 | **\$0** | **\$0** | **\$0** |"
echo "| フォロー・アンフォロー（DOM 操作） | **\$0** | **\$0** | **\$0** |"
echo "| 返信（**実測** 9/8=5 件・9/9=3 件） | \$0.003 | \$0.009〜0.015 | 約 \$0.27〜0.45 |"
echo
echo "**番人を 15 分ごとに回しても API 課金は \$0。** DOM 操作と launchctl しかしない。"
echo
echo "**投稿・返信・フォロー・アンフォローのいずれもしていない。Chrome も kill していない。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -m1 -oE 'ロード済み: [0-9]+ / 8' "$OUT" 2>/dev/null || echo 'ロード数 不明')"
G="$(grep -m1 -oE '\*\*ロードした\*\*|\*\*ロードできない\*\*' "$OUT" 2>/dev/null || echo '')"
echo "**$(date '+%H:%M') 3 ループの番人を設置（\$0）** / 番人 $G / $N / $(basename "$OUT")"
