#!/bin/bash
# x463（2026-11-11・$0）: 夕方のフォロー 2 つの時刻をずらす（利用者がダイアログで「フォロー 2 つの時刻をずらす」を選んだ）。
#   follow-balance              18:45 → 20:15
#   competitor-follower-follow  18:30 → 20:45
# 18:00〜19:00 は同じ Chrome を使うジョブが 6 つ重なり、ページが空で返る（x461・x462）。回数は変えない。LLM 不使用。
set -uo pipefail
LA="$HOME/Library/LaunchAgents"; U="$(id -u)"; STAMP="$(date '+%Y%m%d-%H%M%S')"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
OUT="${OPS_REPORT_DIR:-/tmp}/x463-shift-evening-follow.md"
shift_one() { local lb="$1" fh="$2" fm="$3" th="$4" tm="$5" p="$LA/$1.plist"
  [ -f "$p" ] || { echo "  **plist が無い: $lb**"; return; }
  cp -p "$p" "$p.bak.$STAMP"
  plutil -convert json -o "$p.x463.json" "$p" || { echo "  読めない: $lb"; return; }
  R="$("$NODE_BIN" -e '
const fs=require("fs");const [f,fh,fm,th,tm]=process.argv.slice(1);const j=JSON.parse(fs.readFileSync(f,"utf8"));
let c=j.StartCalendarInterval;const arr=Array.isArray(c)?c:[c];let n=0;
for(const t of arr){if(t&&t.Hour===+fh&&(t.Minute||0)===+fm){t.Hour=+th;t.Minute=+tm;n++}}
j.StartCalendarInterval=Array.isArray(c)?arr:arr[0];fs.writeFileSync(f,JSON.stringify(j));console.log(n)' "$p.x463.json" "$fh" "$fm" "$th" "$tm")"
  if [ "$R" != "1" ]; then echo "  $lb: $fh:$fm が見つからない（$R 件）。変えない"; rm -f "$p.x463.json"; return; fi
  plutil -convert xml1 -o "$p" "$p.x463.json" && rm -f "$p.x463.json" && plutil -lint "$p" >/dev/null || { echo "  **書き戻せない。元に戻す**"; cp -p "$p.bak.$STAMP" "$p"; return; }
  launchctl bootout "gui/$U/$lb" 2>/dev/null; launchctl bootstrap "gui/$U" "$p" 2>&1 | head -1
  if launchctl print "gui/$U/$lb" >/dev/null 2>&1; then
    echo "  $lb: $fh:$(printf %02d $fm) → $th:$(printf %02d $tm) → 載っている"
    plutil -p "$p" | grep -A30 StartCalendarInterval | grep -E 'Hour|Minute' | tr -s ' \n' ' ' | sed 's/^/    いまの時刻: /'; echo
  else echo "  **$lb が載っていない。元の plist に戻す**"; cp -p "$p.bak.$STAMP" "$p"; launchctl bootstrap "gui/$U" "$p" 2>&1 | head -1; fi; }
{
echo "# 夕方のフォロー 2 つをずらす（$(date '+%Y-%m-%d %H:%M:%S') JST・\$0）"
echo '```'
shift_one ai.openclaw.follow-balance 18 45 20 15
shift_one ai.openclaw.competitor-follower-follow 18 30 20 45
echo '```'
} > "$OUT" 2>&1
grep -c '→ 載っている' "$OUT" | sed 's/^/載った: /'
exit 0
