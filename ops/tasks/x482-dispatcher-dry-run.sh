#!/bin/bash
# x482（2026-11-14・$0）: 押す係を 1 つにまとめる（第 2 段）の試し運転を入れる。利用者がダイアログで「この順でよい」「まず試し運転で作る」を選んだ。
#  ① x-action-pacer.cjs を置き直す（押す直前の記録 x-action-shadow.jsonl を残すようになった。押す動きは変えない）
#  ② x-action-dispatcher.cjs を置き、com.dailyhack.x-action-dispatcher（15 分ごと・DRY_RUN=1）を載せる。**何も押さない**
#     ai.openclaw.* にしないのは tab-guard の全停止で黙って外れるため（CLAUDE.md 最上位ルール 4 の予約タスクと同じ）
# LLM を呼ばない。
set -uo pipefail
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
W="$HOME/.openclaw/workspace"; LIB="$W/lib"; LA="$HOME/Library/LaunchAgents"; UIDN="$(id -u)"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
L="com.dailyhack.x-action-dispatcher"; P="$LA/$L.plist"; LOG="$W/logs/x-action-dispatcher.log"
OUT="${OPS_REPORT_DIR:-/tmp}/x482-dispatcher-dry-run.md"
{
echo "# 押す係の試し運転を入れる（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0・何も押さない）"
git -C "$REPO" fetch -q origin main 2>/dev/null
echo; echo "## ① ② ファイルを置く"; echo '```'
ok=1
for f in x-action-pacer.cjs x-action-dispatcher.cjs; do
  T="$LIB/.x482-$f"
  if git -C "$REPO" show "origin/main:ops/lib/$f" > "$T" 2>/dev/null && [ -s "$T" ] && "$NODE_BIN" --check "$T" 2>/dev/null; then
    [ -f "$LIB/$f" ] && cp -p "$LIB/$f" "$LIB/$f.bak-x482"; mv "$T" "$LIB/$f"; echo "置いた: $f"
  else rm -f "$T"; echo "**取れない／壊れている: $f**"; ok=0; fi
done
grep -q 'x-action-shadow' "$LIB/x-action-pacer.cjs" && echo "pacer: 押す直前の記録 → 入っている"
echo '```'
if [ "$ok" != 1 ]; then echo "**置けなかったので載せない**"; exit 0; fi
echo; echo "## ③ 試し運転のジョブを載せる"; echo '```'
cat > "$P" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$L</string>
  <key>ProgramArguments</key><array><string>$NODE_BIN</string><string>$LIB/x-action-dispatcher.cjs</string></array>
  <key>StartInterval</key><integer>900</integer>
  <key>EnvironmentVariables</key><dict><key>DRY_RUN</key><string>1</string><key>PATH</key><string>/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict></plist>
PL
plutil -lint "$P" | tail -1
launchctl bootout "gui/$UIDN/$L" 2>/dev/null
BS="$(launchctl bootstrap "gui/$UIDN" "$P" 2>&1)"; echo "bootstrap rc=$? $(printf '%s' "$BS" | cut -c1-80)"
PR="$(launchctl print "gui/$UIDN/$L" 2>/dev/null)"
if [ -z "$PR" ]; then echo "**載っていない**"; else echo "載っている ← $(printf '%s\n' "$PR" | grep -aE 'run interval|DRY_RUN' | tr -s ' \t' ' ' | tr '\n' ' ')"; fi
launchctl kickstart "gui/$UIDN/$L" 2>&1 | head -1; sleep 4
echo "--- 1 回目の出力"; tail -n 3 "$LOG" 2>/dev/null
echo "--- 押す直前の記録（いままでの行数）: $(wc -l < "$W/data/x-action-shadow.jsonl" 2>/dev/null | tr -d ' ' || echo 0)"
echo '```'
} > "$OUT" 2>&1
grep -E '置いた|載っている|試し運転\]' "$OUT" | head -4 | cut -c1-140
exit 0
