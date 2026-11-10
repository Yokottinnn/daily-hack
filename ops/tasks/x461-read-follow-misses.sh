#!/bin/bash
# x461（2026-11-11・読むだけ・$0）: フォローの空振りの原因を読む（利用者がダイアログで「原因を読む」を選んだ）。
# ① follow-balance が「フォロー中: 0 件・ページが壊れている」で止まる回の前後と、その回がいつ起きるか（時刻の偏り）
# ② competitor-follower-follow が「scraped 0 followers」「new targets 0」になる理由（どのアカウントを見ているか・既に見た数）
# **何も書き換えない・押さない。** 他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; U="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x461-read-follow-misses.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#(x|twitter)\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#$1.com/<伏せ>#g; s#"/(?!heng_ji31590)[A-Za-z0-9_]{2,15}"#"/<伏せ>"#g'; }
{
echo "# フォローの空振りの原因（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① follow-balance: 0 件で止まった回（11/1 以降・時刻 UTC）"; echo '```'
grep -n 'しか読めない' "$L/follow-balance.log" 2>/dev/null | awk -F'[][]' '{print $2}' | awk '!s[$0]++' | grep '2026-11' | tail -20
echo "--- 時刻ごとの回数（UTC の時）"
grep 'しか読めない' "$L/follow-balance.log" 2>/dev/null | awk -F'[][]' '{print substr($2,12,2)}' | sort | uniq -c
echo "--- 起動の時刻ごとの回数（UTC の時・11/1 以降）"
grep 'follow-balance start' "$L/follow-balance.log" 2>/dev/null | grep '2026-11' | awk -F'[][]' '{print substr($2,12,2)}' | sort | uniq -c
echo "--- 直近の 0 件の回の前後（重複を落として 20 行）"
N="$(grep -n 'しか読めない' "$L/follow-balance.log" | tail -1 | cut -d: -f1)"
[ -n "$N" ] && sed -n "$((N-25)),$((N+2))p" "$L/follow-balance.log" | awk '!s[$0]++' | grep -v 'Call log\|<ws' | tail -20 | cut -c1-220 | hide
echo "--- 読めた回の「フォロー中: N 件」（直近 10 回）"
grep -o 'フォロー中: [0-9]* 件（[0-9]* 秒）' "$L/follow-balance.log" | tail -10
echo '```'
echo; echo "## ② competitor-follower-follow"; echo '```'
P="$HOME/Library/LaunchAgents/ai.openclaw.competitor-follower-follow.plist"
plutil -p "$P" 2>/dev/null | grep -vE 'TOKEN|KEY|SECRET|PASS' | grep -A20 'EnvironmentVariables\|StartCalendar' | head -30
echo "--- ログ（直近 40 行・重複を落とす）"
awk '!s[$0]++' "$L/competitor-follower-follow.log" 2>/dev/null | tail -40 | cut -c1-200 | hide
echo "--- 見る先のリスト・既に見た記録（ファイル名と件数）"
ls -la "$W/data" 2>/dev/null | grep -iE 'competitor|seed|follow-target|followed' | sed "s#$HOME#~#" | head -10
for f in "$W"/data/*competitor*.json "$W"/data/*follow-seed*.json; do [ -f "$f" ] && node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const n=Array.isArray(j)?j.length:Object.keys(j).length;console.log(require("path").basename(process.argv[1])+": "+n+" 件 / 項目 "+(Array.isArray(j)?Object.keys(j[0]||{}).join(","):Object.keys(j).slice(0,8).join(",")))' "$f" 2>&1; done
echo '```'
} > "$OUT" 2>&1
echo "x461 / $(basename "$OUT")"
exit 0
