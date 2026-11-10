#!/bin/bash
# x462（2026-11-11・読むだけ・$0）: 夕方 18:30〜18:45 JST にだけフォロー系が空振りする理由を読む（利用者がダイアログで「18 時台に重なっているジョブを読む」を選んだ）。
# ① 載っているジョブのうち、18 時台（17:50〜19:10）に起動するもの・間隔で動くものを、plist の時刻から並べる
# ② 11/10 の 18:20〜18:55 JST（09:20〜09:55 UTC）に書かれたログの行を、ジョブごとに先頭だけ出す（Chrome を触ったか）
# **何も書き換えない・押さない。** 他人のハンドルは伏せる。
set -uo pipefail
W="$HOME/.openclaw/workspace"; L="$W/logs"; LA="$HOME/Library/LaunchAgents"; U="$(id -u)"
OUT="${OPS_REPORT_DIR:-/tmp}/x462-read-1830-overlap.md"
hide() { perl -pe 's/@(?!heng_ji31590\b)[A-Za-z0-9_]{2,15}/@<伏せ>/g'; }
{
echo "# 夕方 18 時台に重なるジョブ（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① 18 時台に動くジョブ（載っているものだけ）"; echo '```'
for p in "$LA"/*.plist; do
  lb="$(basename "$p" .plist)"; launchctl print "gui/$U/$lb" >/dev/null 2>&1 || continue
  j="$(plutil -convert json -o - "$p" 2>/dev/null)" || continue
  printf '%s' "$j" | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);const lb=process.argv[1];
let c=j.StartCalendarInterval;const iv=j.StartInterval;const out=[];
if(c){if(!Array.isArray(c))c=[c];for(const t of c){const h=t.Hour,m=t.Minute??0;if(h===undefined){out.push("毎時 "+m+"分")}else{const mins=h*60+m;if(mins>=17*60+50&&mins<=19*60+10)out.push(h+":"+String(m).padStart(2,"0"))}}}
if(iv&&iv<=3600)out.push(iv+"秒ごと");
if(out.length)console.log(lb.padEnd(48)+" "+out.join(" / ")+"  "+((j.ProgramArguments||[]).slice(-1)[0]||"").split("/").pop())});' "$lb"
done
echo '```'
echo; echo "## ② 11/10 18:20〜18:55 JST に書かれたログ（09:2x〜09:5x UTC・ファイルごとに最大 4 行）"; echo '```'
for f in "$L"/*.log; do
  hits="$(grep -E '2026-11-10T09:(2|3|4|5)[0-9]|2026-11-10 18:(2|3|4|5)[0-9]' "$f" 2>/dev/null | awk '!s[$0]++' | head -4)"
  [ -n "$hits" ] && { echo "[$(basename "$f")]"; printf '%s\n' "$hits" | cut -c1-170 | hide; }
done
echo '```'
echo; echo "## ③ 自動化用 Chrome のタブの数と、18 時台の tab-guard / ensure-chrome の記録"; echo '```'
curl -sS --max-time 5 http://127.0.0.1:18810/json/list 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const a=JSON.parse(s);console.log("いまのタブ: "+a.filter(x=>x.type==="page").length)}catch(e){console.log("読めない")}})'
for f in tab-guard.log ensure-chrome.log chrome-restart-hook.log; do grep -E '2026-11-(08|10)T09:(2|3|4|5)' "$L/$f" 2>/dev/null | tail -6 | cut -c1-170 | sed "s/^/[$f] /"; done
echo '```'
} > "$OUT" 2>&1
echo "x462 / $(basename "$OUT")"
exit 0
