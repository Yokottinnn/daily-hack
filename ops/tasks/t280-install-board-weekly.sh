#!/bin/bash
# **収益化作戦室の元データを毎週取るジョブを入れ、その場で 1 回 走らせる（t280）。** LLM 不使用・**$0**。
#
# 利用者（2026-10-12）:「今回の断面だけではなく定期的にアップデートして、その結果を踏まえて
#   『収益化作戦室』自体のサイトのコンテンツが変更されていくような仕組みを作ってほしい」
#
#   launchd（毎週 月曜 06:40。asp-sync 06:12 の後）
#     → ~/.openclaw/bin/board-weekly-boot.sh  ← 薄いシム（t237 と同じ作り）
#         → git show origin/main:scripts/strategy-board/mac-weekly.sh  ← 毎回 最新を取り出す
#             → reports/board/（gsc-weekly.json・asp-probe/a8partnered.json・mac-weekly-status.json）
#
# ## 費用（最上位ルール 2-B）
# | 1 回 | 1 日 | 1 か月 |
# | --- | --- | --- |
# | **$0**（GSC API は無料・LLM 不使用） | **$0** | **$0**（週 1 回） |
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t280-install-board-weekly.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.board-weekly"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BOOT="$HOME/.openclaw/bin/board-weekly-boot.sh"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
{ echo "# 収益化作戦室の週次データ取得を入れる（t280・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
[ -d "$REPO/.git" ] || { echo "⚠️ リポジトリが無い: \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0; }
git -C "$REPO" fetch -q origin main 2>/dev/null || true
git -C "$REPO" show origin/main:scripts/strategy-board/mac-weekly.sh > /dev/null 2>&1 || { echo "⚠️ mac-weekly.sh が origin/main に無い" >> "$OUT"; cat "$OUT"; exit 0; }

mkdir -p "$(dirname "$BOOT")" "$HOME/.openclaw/logs"
cat > "$BOOT" <<BOOTEOF
#!/bin/bash
# 毎回 origin/main から本体を取り出して走らせる。作業ツリーには触らない（t280）。
set -uo pipefail
REPO="$REPO"
LOG="\$HOME/.openclaw/logs/board-weekly.log"
echo "=== \$(date '+%Y-%m-%dT%H:%M:%S%z') boot" >> "\$LOG"
git -C "\$REPO" fetch -q origin main >> "\$LOG" 2>&1 || echo "fetch に失敗（続行する）" >> "\$LOG"
LATEST="\${TMPDIR:-/tmp}/board-weekly-latest.sh"
git -C "\$REPO" show origin/main:scripts/strategy-board/mac-weekly.sh > "\$LATEST" 2>>"\$LOG" || { echo "本体を取り出せなかった" >> "\$LOG"; exit 1; }
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
  <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>6</integer><key>Minute</key><integer>40</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.openclaw/logs/board-weekly.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/.openclaw/logs/board-weekly.err.log</string>
</dict>
</plist>
PLISTEOF
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1; BRC=$?
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then LOADED="**載った**（launchctl print が通る）"; else LOADED="**載っていない**（bootstrap rc=$BRC）"; fi
{ echo "## ジョブ"; echo; echo "- \`$LABEL\`（毎週 月曜 06:40）: $LOADED"; echo; } >> "$OUT"

# その場で 1 回（GSC 240 秒＋A8 約 5 分。heartbeat を長く止めないよう、裏で走らせて結果は次の周回に載る）
nohup /bin/bash "$BOOT" >/dev/null 2>&1 &
echo "- 1 回目を裏で開始した（pid $!）。結果は \`reports/board/mac-weekly-status.json\` に出る" >> "$OUT"
cat "$OUT"
