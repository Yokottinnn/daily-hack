#!/bin/bash
# **記事リフレッシュの定期ジョブを Mac に入れる（t138）。**
#
# 利用者の承認済み（2026-09-20・ダイアログ）:
#   **Sonnet 5 ／ 1 日 1 本 ／ PR は自動で作り、マージは人がやる**
#
# ## 費用（CLAUDE.md 最上位ルール 2-B）
#
# | 単位 | 金額 |
# | --- | --- |
# | 1 回あたり | **約 $0.07**（推定・Sonnet 5・入力 2 万 tok / 出力 3 千 tok） |
# | 1 日あたり | **約 $0.07** |
# | 1 か月あたり | **約 $2.1** |
#
# 単価は `claude-api` スキルの料金表から（$2/$10 per MTok）。
# **いま動いている反復ジョブの実額は $0.021/日・約 $0.63/月** なので、
# 合計は **約 $2.7/月** の見込みになる。
# **実額は `ops/data/refresh-state.json` の `total_usd` に積まれる。**
#
# ## やること
#
#   1. plist を `~/Library/LaunchAgents/` に置く（毎日 05:30 JST）
#   2. **`bootstrap` で載せる。** `load -w` は rc=0 でも載らない（最上位ルール 13）
#   3. **`launchctl list` に出るかで確かめる。** rc は証拠にならない
#   4. `ops/data/autoload-jobs.txt` に足すのは**別 PR**。
#      tab-guard は `ai.openclaw.*` しか外さないので、このジョブは巻き込まれない
#
# **初回は走らせない。** 載せるだけ。最初の 1 本は定時（翌朝）に出る。
# LLM はこのタスク自体では呼ばない。**このタスクの費用は $0。**

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t138-install-refresh-job.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.refresh-daily"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
REPO="${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}"

{
  echo "# 記事リフレッシュの定期ジョブを入れる（t138）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

if [ ! -d "$REPO" ]; then
  echo "⚠️ **リポジトリが無い。** \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0
fi
RUNNER="$REPO/scripts/refresh-daily.sh"
if [ ! -f "$RUNNER" ]; then
  echo "⚠️ **実行スクリプトが無い。** \`$RUNNER\`（main に入っているか確認する）" >> "$OUT"
  cat "$OUT"; exit 0
fi
chmod +x "$RUNNER" 2>/dev/null || true

mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$RUNNER</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>5</integer><key>Minute</key><integer>30</integer></dict>
  <key>RunAtLoad</key><false/>
  <key>StandardOutPath</key><string>$HOME/.openclaw/logs/refresh-daily.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/.openclaw/logs/refresh-daily.err.log</string>
  <key>WorkingDirectory</key><string>$REPO</string>
</dict>
</plist>
PLISTEOF

{
  echo "## 1) plist"
  echo ""
  echo "- 置いた: \`$PLIST\`"
  echo "- 実行するもの: \`$RUNNER\`"
  echo "- 時刻: **毎日 05:30**（\`RunAtLoad\` は false。**初回は走らせない**）"
  echo ""
} >> "$OUT"

# **load ではなく bootstrap**（最上位ルール 13）
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1
BOOT_RC=$?

# **rc ではなく launchctl list で確かめる**
if launchctl list | grep -qF "$LABEL"; then
  LOADED="**載った**"
else
  LOADED="**載っていない**"
fi

{
  echo "## 2) 載せた結果"
  echo ""
  echo "- \`bootstrap\` の rc: $BOOT_RC（**これは証拠にならない**）"
  echo "- \`launchctl list\`: $LOADED ← **こちらが証拠**"
  echo ""
  echo "## 3) 鍵の有無"
  echo ""
} >> "$OUT"

KEY_NAME="ANTHROPIC""_API_KEY"
ENVF="$HOME/openclaw/config/.env"
if [ -n "${!KEY_NAME:-}" ]; then
  echo "- 環境変数に鍵が在る（**値は出さない**）" >> "$OUT"
elif [ -f "$ENVF" ] && grep -q "^$KEY_NAME=" "$ENVF"; then
  echo "- \`~/openclaw/config/.env\` に鍵の行が在る（**値は出さない**）" >> "$OUT"
else
  echo "- ⚠️ **鍵が見つからない。** ジョブは走っても何もせずに終わる" >> "$OUT"
fi

{
  echo ""
  echo "## 4) 次に起きること"
  echo ""
  echo "- **毎日 05:30 に 1 本** 選んで調べ、確度「高」だけ本文に当てて **PR を作る**"
  echo "- **マージは人がやる。** 自動では入らない"
  echo "- 実額は \`ops/data/refresh-state.json\` の \`total_usd\` に積まれる"
  echo "- ログ: \`~/.openclaw/logs/refresh-daily.log\`"
} >> "$OUT"

cat "$OUT"
