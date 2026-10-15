#!/bin/bash
# **トレンドのワードを毎日ためるジョブを入れ、その場で 1 回 走らせる（t296）。** LLM 不使用・**$0**。
#
# 利用者（2026-10-14）:「最新のトレンドのワードをちゃんと用いて、それに適した記事を作って欲しい」
#
#   launchd（毎日 07:10）
#     → ~/.openclaw/bin/trend-daily-boot.sh  ← 薄いシム（t237 と同じ作り）
#         → git show origin/main:scripts/strategy-board/trend-daily.sh  ← 毎回 最新を取り出す
#             → reports/board/trend/<日付>.json・trend-words.json
#
# ## 費用（最上位ルール 2-B）
# | 1 回 | 1 日 | 1 か月 |
# | --- | --- | --- |
# | **$0**（RSS と画面を読むだけ・LLM 不使用） | **$0**（1 日 1 回） | **$0** |
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t296-install-trend-daily.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.trend-daily"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BOOT="$HOME/.openclaw/bin/trend-daily-boot.sh"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
{ echo "# トレンドのワードを毎日ためるジョブを入れる（t296・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -d "$REPO/.git" ] || { echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
git -C "$REPO" show origin/main:scripts/strategy-board/trend-daily.sh > /dev/null 2>&1 || { echo "⚠️ trend-daily.sh が origin/main に無い" >> "$OUT"; cat "$OUT"; exit 0; }

mkdir -p "$(dirname "$BOOT")" "$HOME/.openclaw/logs"
cat > "$BOOT" <<BOOTEOF
#!/bin/bash
# 毎回 origin/main から本体を取り出して走らせる。作業ツリーには触らない（t296）。
set -uo pipefail
REPO="$REPO"
LOG="\$HOME/.openclaw/logs/trend-daily.log"
echo "=== \$(date '+%Y-%m-%dT%H:%M:%S%z') boot" >> "\$LOG"
git -C "\$REPO" fetch -q origin main >> "\$LOG" 2>&1 || echo "fetch に失敗（続行する）" >> "\$LOG"
LATEST="\${TMPDIR:-/tmp}/trend-daily-latest.sh"
git -C "\$REPO" show origin/main:scripts/strategy-board/trend-daily.sh > "\$LATEST" 2>>"\$LOG" || { echo "本体を取り出せなかった" >> "\$LOG"; exit 1; }
[ -s "\$LATEST" ] || { echo "本体が空" >> "\$LOG"; exit 1; }
DAILY_HACK_REPO="\$REPO" exec /bin/bash "\$LATEST" >> "\$LOG" 2>&1
BOOTEOF
chmod +x "$BOOT"

mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$BOOT</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>10</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.openclaw/logs/trend-daily.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/.openclaw/logs/trend-daily.err.log</string>
</dict>
</plist>
PLISTEOF
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1; BRC=$?
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then LOADED="**載った**（launchctl print が通る）"; else LOADED="**載っていない**（bootstrap rc=$BRC）"; fi
{ echo "## ジョブ"; echo; echo "- \`$LABEL\`（毎日 07:10）: $LOADED"; echo; } >> "$OUT"

# その場で 1 回（数秒で終わる。結果は次の heartbeat に載る）
# 初回は launchd の kickstart で走らせる（nohup だとタスクの子として一緒に落とされる。t281/t282）
launchctl kickstart "gui/$(id -u)/$LABEL" >> "$OUT" 2>&1 && echo "- 1 回目を launchd から開始した" >> "$OUT"
cat "$OUT"
