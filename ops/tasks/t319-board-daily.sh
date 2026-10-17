#!/bin/bash
# **作戦室の元データを毎日取るように変える（t319）。** 利用者（2026-10-17）「頻度を毎日にしたらコスト変わる？変わらないのであれば毎日更新にして」。
# com.dailyhack.board-weekly（6:40）と com.dailyhack.asp-sync（6:12）の plist から曜日（Weekday）を外して毎日にし、載せ直す。
# ## 費用（最上位ルール 2-B）: どちらも LLM 不使用。**1 回 $0・1 日 $0・1 か月 $0**（週 1 → 毎日でも $0 のまま）
set -uo pipefail
RDIR="${OPS_REPORT_DIR:-/tmp}"
OUT="$RDIR/t319-board-daily.md"
mkdir -p "$RDIR"
{ echo "# 作戦室の元データを毎日取る（t319・**\$0**）"; echo; echo "生成: **$(date '+%Y-%m-%dT%H:%M:%S%z')**"; echo; } > "$OUT"
command -v plutil >/dev/null 2>&1 || { echo "⚠️ plutil が無い" >> "$OUT"; cat "$OUT"; exit 0; }
for LABEL in com.dailyhack.board-weekly com.dailyhack.asp-sync; do
  P="$HOME/Library/LaunchAgents/$LABEL.plist"
  if [ ! -f "$P" ]; then echo "- \`$LABEL\`: plist が無い（\`$P\`）" >> "$OUT"; continue; fi
  cp "$P" "$RDIR/.$LABEL.plist.bak" 2>/dev/null
  if plutil -extract StartCalendarInterval.Weekday raw "$P" >/dev/null 2>&1; then
    plutil -remove StartCalendarInterval.Weekday "$P"; echo "- \`$LABEL\`: 曜日を外した" >> "$OUT"
  else echo "- \`$LABEL\`: 曜日はもう無い" >> "$OUT"; fi
  plutil -lint "$P" >/dev/null 2>&1 || { echo "  - ⚠️ plist が壊れた。元に戻す" >> "$OUT"; cp "$RDIR/.$LABEL.plist.bak" "$P"; }
  launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$P" >/dev/null 2>&1; BRC=$?
  if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    H=$(plutil -extract StartCalendarInterval.Hour raw "$P" 2>/dev/null); M=$(plutil -extract StartCalendarInterval.Minute raw "$P" 2>/dev/null)
    W=$(plutil -extract StartCalendarInterval.Weekday raw "$P" 2>/dev/null || echo なし)
    echo "  - **載った**（launchctl print が通る）・時刻 ${H}:${M}・曜日 ${W}" >> "$OUT"
  else echo "  - **載っていない**（bootstrap rc=$BRC）" >> "$OUT"; fi
done
cat "$OUT"
