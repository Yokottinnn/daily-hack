#!/bin/bash
# x473（2026-11-14・読むだけ・$0）: follow-balance の夜の回（11:30Z ごろ）から翌朝の回（02:45Z）までに、
# フォロー中が 11〜16 件増える。その間にフォローしているジョブを、ログとフォロー日時の記録から特定する。何も変えない。ハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; D="$W/data"
OUT="${OPS_REPORT_DIR:-/tmp}/x473-read-night-follows.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g; s#x\.com/(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}#x.com/<伏せ>#g'; }
WIN='^\[2026-11-(12T(1[2-9]|2[0-3])|13T0[0-2]|13T(1[2-9]|2[0-3])|14T0[0-2])'
{
echo "# 夜のフォローを読む（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo "見る時間: 11/12 12:00Z〜11/13 02:59Z と 11/13 12:00Z〜11/14 02:59Z（JST 21:00〜11:59）"
echo; echo "## 1. ログごとの『フォローした』らしい行の数（この時間帯）"; echo '```'
for f in "$L"/*.log; do
  n="$(grep -E "$WIN" "$f" 2>/dev/null | grep -ciE '✅|followed|follow ok|フォローした|follow-back|フォロバ' | head -1)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -gt 0 ] && echo "$n $(basename "$f")"
done | sort -rn | head -20
echo '```'
echo; echo "## 2. 上位 3 つのログの該当行（各 25 行）"
for f in $(for f in "$L"/*.log; do n="$(grep -E "$WIN" "$f" 2>/dev/null | grep -ciE '✅|followed|follow ok|フォローした|follow-back|フォロバ' | head -1)"; case "$n" in ''|*[!0-9]*) n=0;; esac; [ "$n" -gt 0 ] && echo "$n $f"; done | sort -rn | head -3 | awk '{print $2}'); do
  echo; echo "### $(basename "$f")"; echo '```'
  grep -E "$WIN" "$f" | grep -iE '✅|followed|follow ok|フォローした|follow-back|フォロバ|start|end' | awk '!s[$0]++' | head -25 | cut -c1-200 | hide
  echo '```'
done
echo; echo "## 3. フォロー日時の記録（data/ の *follow* の json）から、この時間帯に記録された件数と出どころ"; echo '```'
for j in "$D"/*follow*.json; do
  [ -f "$j" ] || continue
  /usr/local/bin/node -e '
const fs=require("fs");let d;try{d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
const re=/^2026-11-(12T(1[2-9]|2[0-3])|13T0[0-2]|13T(1[2-9]|2[0-3])|14T0[0-2])/;const c={};let n=0;
const walk=(o,k)=>{if(!o||typeof o!=="object")return;for(const[kk,v]of Object.entries(o)){if(typeof v==="string"&&/(follow(ed)?_?at|followedAt|at)$/i.test(kk)&&re.test(v)){n++;const src=o.source||o.via||o.kind||o.from||"(出どころなし)";c[src]=(c[src]||0)+1}else if(typeof v==="object")walk(v,kk)}};
walk(d);if(n)console.log(require("path").basename(process.argv[1])+": "+n+" 件 "+JSON.stringify(c));' "$j" 2>/dev/null
done
echo '```'
echo; echo "## 4. この時間帯に動く launchd ジョブ（StartCalendarInterval の時刻つき・follow を含む名前）"; echo '```'
for p in "$HOME"/Library/LaunchAgents/*follow*.plist "$HOME"/Library/LaunchAgents/*reply*.plist; do
  [ -f "$p" ] || continue
  h="$(/usr/libexec/PlistBuddy -c 'Print :StartCalendarInterval' "$p" 2>/dev/null | tr -s ' \n' ' ' | cut -c1-160)"
  i="$(/usr/libexec/PlistBuddy -c 'Print :StartInterval' "$p" 2>/dev/null)"
  echo "$(basename "$p" .plist) | 時刻: ${h:-なし} | 間隔: ${i:-なし}"
done
echo '```'
} > "$OUT" 2>&1
sed -n '/## 1/,/```$/p' "$OUT" | sed -n 3,6p | cut -c1-120
exit 0
