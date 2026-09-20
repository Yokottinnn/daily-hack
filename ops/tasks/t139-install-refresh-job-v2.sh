#!/bin/bash
# **記事リフレッシュの定期ジョブを Mac に入れ直す（t139）。**
#
# ## t138 が失敗した理由
#
#   ⚠️ 実行スクリプトが無い。/Users/ny/projects/anta-baka-x/blog/scripts/refresh-daily.sh
#
# **Mac の作業ツリーは `origin/main` に追従していない。** タスクは
# `ops-run-tasks.sh` が `git show origin/main:` で取り出して走らせているので、
# **main にマージしてもディスク上にファイルは現れない。**
# plist から作業ツリーのパスを直に呼んだのが間違いだった。
#
# ## ここで入れるもの
#
#   launchd（毎日 05:30）
#     → ~/.openclaw/bin/refresh-daily-boot.sh   ← **薄いシム。ここだけディスクに置く**
#         → git show origin/main:scripts/refresh-daily.sh  ← **毎回 最新を取り出す**
#             → refresh-article.mjs --apply → npm run build → gh pr create
#
# シムは `ops-run-tasks.sh` の自己更新と同じ作りで、**作業ツリーには触らない。**
#
# ## 費用（CLAUDE.md 最上位ルール 2-B）
#
# **このタスク自体は $0。** LLM を呼ばない。
# 入れるジョブのほうは利用者の承認済み（Sonnet 5 ／ 1 日 1 本 ／ PR は人がマージ）。
#
# | 単位 | 金額 |
# | --- | --- |
# | 1 回あたり | **約 $0.07**（推定・入力 2 万 tok / 出力 3 千 tok） |
# | 1 日あたり | **約 $0.07** |
# | 1 か月あたり | **約 $2.1** |
#
# **初回は走らせない**（`RunAtLoad` false）。最初の 1 本は翌朝 05:30。
# **`launchctl list` に出るかで確かめる。** rc は証拠にならない（最上位ルール 13）。

set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t139-install-refresh-job-v2.md"
mkdir -p "$RDIR"
LABEL="com.dailyhack.refresh-daily"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
BOOT="$HOME/.openclaw/bin/refresh-daily-boot.sh"
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"

{
  echo "# 記事リフレッシュの定期ジョブを入れ直す（t139）"
  echo ""
  echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"
  echo ""
} > "$OUT"

if [ ! -d "$REPO/.git" ]; then
  echo "⚠️ **リポジトリが無い。** \`$REPO\`" >> "$OUT"; cat "$OUT"; exit 0
fi

git -C "$REPO" fetch -q origin main 2>/dev/null || true

# **本体が origin/main に在ることを確かめる。** 作業ツリーは見ない
if ! git -C "$REPO" show origin/main:scripts/refresh-daily.sh > /dev/null 2>&1; then
  echo "⚠️ **\`scripts/refresh-daily.sh\` が origin/main に無い。**" >> "$OUT"
  cat "$OUT"; exit 0
fi

mkdir -p "$(dirname "$BOOT")"
cat > "$BOOT" <<'BOOTEOF'
#!/bin/bash
# **毎回 origin/main から本体を取り出して走らせる。** 作業ツリーには触らない。
# 置き換えるときは ops/tasks から入れ直すこと（t139）。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-${BLOG_REPO:-$HOME/projects/anta-baka-x/blog}}"
LOG="$HOME/.openclaw/logs/refresh-daily.log"
mkdir -p "$(dirname "$LOG")"
{
  echo "=== $(date '+%Y-%m-%dT%H:%M:%S%z') boot"
  git -C "$REPO" fetch -q origin main 2>/dev/null || echo "fetch に失敗（続行する）"
} >> "$LOG" 2>&1
LATEST="${TMPDIR:-/tmp}/refresh-daily-latest.sh"
if ! git -C "$REPO" show origin/main:scripts/refresh-daily.sh > "$LATEST" 2>>"$LOG"; then
  echo "本体を取り出せなかった" >> "$LOG"; exit 1
fi
[ -s "$LATEST" ] || { echo "本体が空だった" >> "$LOG"; exit 1; }
exec /bin/bash "$LATEST"
BOOTEOF
chmod +x "$BOOT"

mkdir -p "$(dirname "$PLIST")" "$HOME/.openclaw/logs"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$BOOT</string>
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

# **load ではなく bootstrap**（最上位ルール 13）
launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1
BOOT_RC=$?

if launchctl list | grep -qF "$LABEL"; then
  LOADED="**載った**"
else
  LOADED="**載っていない**"
fi

{
  echo "## 1) 置いたもの"
  echo ""
  echo "- シム: \`$BOOT\`（**毎回 origin/main から本体を取り出す**）"
  echo "- plist: \`$PLIST\`（毎日 05:30・\`RunAtLoad\` false）"
  echo ""
  echo "## 2) 載せた結果"
  echo ""
  echo "- \`bootstrap\` の rc: $BOOT_RC（**これは証拠にならない**）"
  echo "- \`launchctl list\`: $LOADED ← **こちらが証拠**"
  echo ""
  echo "## 3) シムが本体を取り出せるか（**実際に打った**）"
  echo ""
} >> "$OUT"

PROBE="${TMPDIR:-/tmp}/t139-probe.sh"
if git -C "$REPO" show origin/main:scripts/refresh-daily.sh > "$PROBE" 2>/dev/null && [ -s "$PROBE" ]; then
  LINES="$(wc -l < "$PROBE" | tr -d ' ')"
  if /bin/bash -n "$PROBE" 2>/dev/null; then
    echo "- 取り出せた（**$LINES 行**）／ \`bash -n\` **通る**" >> "$OUT"
  else
    echo "- 取り出せた（**$LINES 行**）／ ⚠️ \`bash -n\` が**通らない**" >> "$OUT"
  fi
else
  echo "- ⚠️ **取り出せなかった**" >> "$OUT"
fi

{
  echo ""
  echo "## 4) 作業ツリーの状態（参考・触っていない）"
  echo ""
  echo "- HEAD: \`$(git -C "$REPO" log --oneline -1 2>/dev/null | head -c 120)\`"
  DIRTY_N="$(git -C "$REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  case "$DIRTY_N" in ''|*[!0-9]*) DIRTY_N=0 ;; esac
  if [ "$DIRTY_N" -gt 0 ]; then
    echo "- ⚠️ **未コミットが $DIRTY_N 件 ある。** この場合ジョブは**何もせずに終わる**"
  else
    echo "- 未コミット: **0 件**（ジョブは動ける）"
  fi
  echo ""
  echo "## 5) 鍵の有無"
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
  echo "## 6) 次に起きること"
  echo ""
  echo "- **毎日 05:30 に 1 本** 調べ、確度「高」だけ当てて **PR を作る**"
  echo "- **マージは人がやる。** 自動では入らない"
  echo "- 1 本目は \`ops/data/unindexed.txt\` の先頭（未インデックスの記事から回す）"
  echo "- 実額: \`ops/data/refresh-state.json\` の \`total_usd\`／ログ: \`~/.openclaw/logs/refresh-daily.log\`"
} >> "$OUT"

cat "$OUT"
