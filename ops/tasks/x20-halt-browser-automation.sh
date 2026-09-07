#!/bin/bash
# **【緊急】ブラウザを触る自動化を止める。先に証拠を取ってから止める。費用 $0。**
#
# ## 症状（2026-09-08・利用者から「最重要課題」と指定）
#
#   > 勝手にブラウザが消されてしまう事象が直近で起きている
#   > たったいまも発生していたのでこれは最重要課題です
#
# ## 順番が大事
#
# **止めると状態が変わって証拠が消える。** だからこの順で行う。
#
#   1. **証拠を採る**（Chrome の起動時刻・親プロセス・いま走っている js）
#   2. **止める**（Chrome を触る `ai.openclaw.*` を unload）
#   3. 止めた結果を確認する
#
# ## 止める対象（Chrome を触るものだけ）
#
# 返信・フォロー・アンフォロー・投稿は**止まる**。それは承知のうえ。
# **利用者のブラウザが壊されるほうが重い。**
#
# ## 止めないもの
#
#   * `com.dailyhack.*`（ポーラー・heartbeat）— **これを止めると戻せなくなる**
#   * `ai.openclaw.gateway` / `listener` — 連絡経路
#
# ## 戻し方
#
#   launchctl load -w ~/Library/LaunchAgents/ai.openclaw.<名前>.plist
#
# レポート末尾に**戻すためのコマンドを全部 並べる。**
#
# **Chrome を殺さない。タブを開かない・閉じない。LLM を呼ばない。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
LA="$HOME/Library/LaunchAgents"
OUT="${OPS_REPORT_DIR:-/tmp}/halt-browser-automation.md"

hide() { sed -E 's/@[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
secrets() { sed -E -e 's#(sk-ant-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' \
                   -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' \
                   -e 's#(xox[baprs]-)[A-Za-z0-9-]+#\1<MASKED>#g'; }
clean() { hide | secrets; }

# Chrome を触るジョブ。**gateway / listener / ポーラーは入れない**
TARGETS="
comment-warmup
competitor-follower-follow
hashtag-follow
badge-followback
reply-followers-cleanup
reply-followback-check
incoming-reply-watcher
auto-detect-and-unfollow-inactive
unfollow-cleanup-morning
unfollow-cleanup-evening
revenge-unfollow
follow-watchdog
poll-approvals
auto-thread-chainifier
chrome-cdp-heal
tab-guard
trend-daily
grok-trending-daily
qt-past-daily
engage-daily
bookmark-watcher
bookmark-analyzer
follower-snapshot
follower-monitor
post-metrics-collector
x-login-compat-test
"

{
echo "# 【緊急】ブラウザを触る自動化を止めた"
echo
echo "**このレポートが作られた時刻: $(date '+%Y-%m-%d %H:%M:%S') JST**"
echo
echo "> 利用者の報告: **「たったいまも発生していたのでこれは最重要課題です」**"
echo
echo "**止める前に証拠を採る。** 止めると状態が変わって証拠が消えるため。"

# ═══════════════════ 1. 証拠 ═══════════════════
echo
echo "## 1. 【止める前】Chrome の状態"
echo
echo '```'
echo "  uptime: $(uptime 2>/dev/null | sed 's/^ *//')"
echo
echo "  --- Chrome 本体（起動時刻・経過時間つき） ---"
ps -eo pid,ppid,lstart,etime,comm 2>/dev/null \
  | grep -i 'Google Chrome\|Chromium' | grep -v ' grep' | head -8 | sed 's/^/    /'
echo
echo "  --- CDP 付きで起動されたもの ---"
ps -eo pid,lstart,etime,args 2>/dev/null | grep -- '--remote-debugging-port' \
  | grep -v ' grep' | head -3 | cut -c1-200 | sed 's/^/    /' | clean
echo
echo "  --- 誰が起動したか（親プロセス） ---"
CPID="$(pgrep -f 'Google Chrome.*--remote-debugging-port' 2>/dev/null | head -1)"
if [ -n "$CPID" ]; then
  PP="$(ps -o ppid= -p "$CPID" 2>/dev/null | tr -d ' ')"
  echo "    Chrome pid=$CPID / 親 pid=$PP"
  ps -o pid,lstart,args -p "$PP" 2>/dev/null | tail -1 | cut -c1-190 | sed 's/^/    /' | clean
else
  echo "    **CDP 付きの Chrome が見つからない（いま落ちている）**"
fi
echo
echo "  --- タブ数（CDP から。開かない・閉じない。数えるだけ） ---"
curl -s --max-time 5 http://127.0.0.1:18810/json/list 2>/dev/null \
  | grep -c '"type": *"page"' | sed 's/^/    ページ数: /' || echo "    CDP に繋がらない"
echo '```'

echo
echo "### いま走っている workspace の js（**これが Chrome を触っている**）"
echo
echo '```'
ps -eo pid,lstart,etime,args 2>/dev/null | grep 'workspace/scripts' | grep -v ' grep' \
  | head -12 | cut -c1-190 | sed 's/^/  /' | clean
echo "  ---（空なら、いま走っているものは無い）---"
echo '```'

echo
echo "### 直近 15 分に更新されたログ（**直前に動いたもの**）"
echo
echo '```'
find "$W/logs" -name '*.log' -mmin -15 2>/dev/null | while read -r f; do
  printf '  %-38s %s\n' "$(basename "$f")" "$(stat -f '%Sm' -t '%m-%d %H:%M:%S' "$f" 2>/dev/null)"
done | sort -k2 | tail -20
echo "  ---（空なら、直近 15 分に動いたジョブは無い）---"
echo '```'

echo
echo "### \`ensure-chrome.sh\` は Chrome を殺すか（**kill の行だけ**）"
echo
echo '```bash'
grep -nE 'kill|pkill|killall|quit|osascript|open -a|--remote-debugging-port' \
  "$W/scripts/ensure-chrome.sh" 2>/dev/null | head -20 | cut -c1-170 | sed 's/^/  /' | clean
echo '```'

echo
echo "### \`browser.close()\` を呼ぶスクリプト（**あれば これが犯人**）"
echo
echo '```javascript'
grep -rnE 'browser\.close\(|\bb\.close\(' "$W/scripts" 2>/dev/null \
  | grep -v node_modules | head -20 | cut -c1-170 | clean
echo "  ---（空なら該当なし）---"
echo '```'

# ═══════════════════ 2. 止める ═══════════════════
echo
echo "## 2. 止める"
echo
echo "**Chrome を触る \`ai.openclaw.*\` を unload する。**"
echo "\`com.dailyhack.*\`（ポーラー・heartbeat）と \`gateway\` / \`listener\` は**触らない**"
echo "（止めると戻せなくなる）。"
echo
echo '```'
STOPPED=0
SKIPPED=0
for j in $TARGETS; do
  [ -z "$j" ] && continue
  lbl="ai.openclaw.$j"
  P="$LA/$lbl.plist"
  if ! launchctl list 2>/dev/null | grep -qF "$lbl"; then
    printf '  未ロード      %-36s （何もしない）\n' "$j"; continue
  fi
  if [ ! -f "$P" ]; then
    printf '  plist が無い  %-36s （何もしない）\n' "$j"; SKIPPED=$((SKIPPED+1)); continue
  fi
  if launchctl unload "$P" 2>/dev/null; then
    printf '  **止めた**    %-36s\n' "$j"; STOPPED=$((STOPPED+1))
  else
    printf '  止められない  %-36s\n' "$j"; SKIPPED=$((SKIPPED+1))
  fi
done
echo
echo "  止めた: ${STOPPED} 本 / 止められなかった: ${SKIPPED} 本"
echo '```'

# ═══════════════════ 3. 結果 ═══════════════════
echo
echo "## 3. 【止めた後】確認"
echo
echo '```'
echo "  --- Chrome はまだ生きているか ---"
ps -eo pid,lstart,etime,comm 2>/dev/null | grep -i 'Google Chrome' | grep -v ' grep' \
  | head -3 | sed 's/^/    /'
echo
echo "  --- まだ走っている workspace の js ---"
ps -eo pid,etime,args 2>/dev/null | grep 'workspace/scripts' | grep -v ' grep' \
  | head -8 | cut -c1-170 | sed 's/^/    /' | clean
echo "    ---（空なら 全部 止まった）---"
echo
echo "  --- ai.openclaw.* で まだロードされているもの ---"
launchctl list 2>/dev/null | awk '{print $3}' | grep '^ai\.openclaw\.' | sort | sed 's/^/    /'
echo '```'

echo
echo "## 4. 戻し方（**そのまま貼れる**）"
echo
echo "原因が分かったら、これで戻す。"
echo
echo '```bash'
for j in $TARGETS; do
  [ -z "$j" ] && continue
  echo "launchctl load -w ~/Library/LaunchAgents/ai.openclaw.$j.plist"
done
echo '```'
echo
echo "**1 本ずつ戻して、どれで再発するかを見るのが確実。**"

echo
echo "---"
echo
echo "**Chrome を殺していない。タブも開いていない・閉じていない（\$0）。**"
echo "**ポーラーと heartbeat は動いたままなので、次のタスクは届く。**"
} > "$OUT" 2>&1

[ -f "$OUT" ] && { clean < "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"; }
N="$(grep -m1 -oE '止めた: [0-9]+ 本' "$OUT" 2>/dev/null || echo '停止数 不明')"
BC="$(grep -A3 'browser.close() を呼ぶスクリプト' "$OUT" 2>/dev/null | grep -c 'close(' || echo 0)"
echo "**$(date '+%H:%M') ブラウザを触る自動化を停止（\$0）** / $N / browser.close 該当 ${BC} / $(basename "$OUT")"
