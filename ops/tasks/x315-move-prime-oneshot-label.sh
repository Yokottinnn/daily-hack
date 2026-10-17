#!/bin/bash
# **x314 の予約ジョブを、tab-guard に外されないラベルへ載せ替える。時刻と中身は変えない。費用 $0。**
#
# ## なぜ
#
#   x314 は `ai.openclaw.publish-prime-oneshot` で載せた（launchctl print で載っていることは確認済み）。
#   だが tab-guard は CDP 断を誤判定すると `ai.openclaw.*` を一斉に外す（9/9・9/12・9/20 に起きた）。
#   12:00 までに外されると、予約は黙って消える。**`com.dailyhack.*` は 3 回とも生き残っている**ので、そちらへ移す。
#
# ## やること
#
#   ① 古いラベルを bootout し、古い plist を消す
#   ② 実行スクリプトの中のラベルと plist のパスを書き換える（投稿の中身・キューは触らない）
#   ③ 新しいラベルで同じ 10/18 12:00 の plist を置き、bootstrap → **launchctl print で確かめる**
#
# **投稿はしない。LLM を呼ばない（$0／回・$0／日・$0／月）。**
set -uo pipefail

W="$HOME/.openclaw/workspace"
S="$W/scripts"
LA="$HOME/Library/LaunchAgents"
UID_N="$(id -u)"
OLD="ai.openclaw.publish-prime-oneshot"
NEW="com.dailyhack.publish-prime-oneshot"
RUNNER="$S/publish-prime-oneshot.sh"
OUT="${OPS_REPORT_DIR:-/tmp}/move-prime-oneshot.md"

{
echo "# 予約ジョブのラベルを載せ替える（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo
echo "## 0. いまの状態"
echo
echo '```'
if launchctl print "gui/$UID_N/$OLD" >/dev/null 2>&1; then echo "  $OLD: 載っている"; else echo "  $OLD: 載っていない"; fi
[ -f "$RUNNER" ] && echo "  runner: 在る" || echo "  runner: **無い**"
grep -c "blog-promo-20261018-prime-vs-rakuten" "$W/data/post_queue.json" 2>/dev/null | head -1 | sed 's/^/  キューの id 出現: /'
echo '```'
if [ ! -f "$RUNNER" ]; then echo "- **runner が無い。もう走ったか、消えている。何もしない。**"; exit 1; fi
if grep -q 'done rc=' "$W/logs/publish-prime-oneshot.log" 2>/dev/null; then echo "- **もう走っている。何もしない。**"; exit 0; fi

echo
echo "## 1. 実行スクリプトのラベルを書き換える"
echo
perl -pi -e "s/\Q$OLD\E/$NEW/g" "$RUNNER"
echo '```'
grep -nE 'launchctl|rm -f' "$RUNNER" | sed 's/^/  /'
echo '```'

echo
echo "## 2. 古いジョブを外し、新しいラベルで同じ時刻に載せる"
echo
launchctl bootout "gui/$UID_N/$OLD" 2>/dev/null
rm -f "$LA/$OLD.plist"
cat > "$LA/$NEW.plist" <<PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$NEW</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$RUNNER</string>
  </array>
  <key>StartCalendarInterval</key><dict>
    <key>Month</key><integer>10</integer>
    <key>Day</key><integer>18</integer>
    <key>Hour</key><integer>12</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>$W/logs/publish-prime-oneshot-out.log</string>
  <key>StandardErrorPath</key><string>$W/logs/publish-prime-oneshot-err.log</string>
</dict></plist>
PLEOF
BS="$(launchctl bootstrap "gui/$UID_N" "$LA/$NEW.plist" 2>&1)"; BRC=$?
echo '```'
printf '  bootstrap rc=%s  %s\n' "$BRC" "$(printf '%s' "$BS" | head -1)"
echo '```'

echo
echo "## 3. 証拠（rc ではなく print）"
echo
echo '```'
if launchctl print "gui/$UID_N/$NEW" >/dev/null 2>&1; then
  launchctl print "gui/$UID_N/$NEW" 2>/dev/null | grep -E '^\s+(state|runs|path|program) ' | sed 's/^/  /'
  echo "  → **新しいラベルで載っている**"
else
  echo "  → **新しいラベルで載っていない**"
fi
if launchctl print "gui/$UID_N/$OLD" >/dev/null 2>&1; then echo "  古いラベル: **まだ載っている（二重に走る恐れ）**"; else echo "  古いラベル: 外れた"; fi
echo '```'
echo
echo "**投稿していない。LLM を呼んでいない（\$0／回・\$0／日・\$0／月）。**"
} > "$OUT" 2>&1

if grep -q '新しいラベルで載っている' "$OUT" && grep -q '古いラベル: 外れた' "$OUT"; then
  echo "予約を com.dailyhack へ載せ替えた / $(basename "$OUT")"
else
  echo "**載せ替えが終わっていない。レポートを確認すること** / $(basename "$OUT")"
fi
