#!/bin/bash
# x435（2026-11-07・読むだけ・$0）: 載っていない ai.openclaw.* のジョブを棚卸しする。
# 利用者がダイアログで「載っていない 40 本を棚卸しする」を選んだ（x426: plist 77 本 / 載っている 37 件）。
# tab-guard の全停止（10/26〜11/6 に 10 回）で外れたままのものと、わざと止めているものを分ける材料を出す。
# 1 本ごとに: いつ動く設定か・呼ぶスクリプトがあるか・ログの最終更新・autoload-jobs.txt に入っているか・AI を呼ぶか。
# **何も書き換えない・載せ直さない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; LA="$HOME/Library/LaunchAgents"; UIDN="$(id -u)"
REPO="${DAILY_HACK_REPO:-/Users/ny/projects/anta-baka-x/blog}"
AUTO="$REPO/ops/data/autoload-jobs.txt"
OUT="${OPS_REPORT_DIR:-/tmp}/x435-unloaded-inventory.md"
JSON="${OPS_REPORT_DIR:-/tmp}/x435-unloaded-inventory.json"
NODE_BIN="$(command -v node 2>/dev/null || echo /usr/local/bin/node)"
{
echo "# 載っていない ai.openclaw.* の棚卸し（$(date '+%Y-%m-%d %H:%M') JST・読むだけ・\$0）"
LIST="$W/.x435-list.txt"; : > "$LIST"
for p in "$LA"/ai.openclaw.*.plist; do
  lb="$(basename "$p" .plist)"
  launchctl print "gui/$UIDN/$lb" >/dev/null 2>&1 && continue
  printf '%s\n' "$p" >> "$LIST"
done
echo; echo "載っていない plist: $(grep -c . "$LIST" | head -1) 本 ／ .disabled にしてある plist: $(ls "$LA"/ai.openclaw.*.disabled 2>/dev/null | wc -l | tr -d ' ') 本"
"$NODE_BIN" -e '
const fs=require("fs"),cp=require("child_process"),path=require("path");
const [list,auto,jsonOut,home]=process.argv.slice(1);
const autos=new Set((fs.existsSync(auto)?fs.readFileSync(auto,"utf8"):"").split("\n").map(s=>s.trim()).filter(s=>s&&!s.startsWith("#")).map(s=>s.split(/\s+/)[0]));
const rows=[];
for (const p of fs.readFileSync(list,"utf8").split("\n").filter(Boolean)) {
  const lb=path.basename(p,".plist");
  let j={}; try { j=JSON.parse(cp.execFileSync("plutil",["-convert","json","-o","-",p],{encoding:"utf8"})); } catch(e) {}
  const args=j.ProgramArguments||(j.Program?[j.Program]:[]);
  const script=args.find(a=>/\.(js|cjs|mjs|sh|py)$/.test(a))||"";
  const exists=script?fs.existsSync(script):null;
  let when="";
  if (j.StartInterval) when="毎 "+Math.round(j.StartInterval/60)+" 分";
  else if (j.StartCalendarInterval) { const a=[].concat(j.StartCalendarInterval); when=a.slice(0,4).map(o=>(o.Weekday!=null?"曜"+o.Weekday+" ":"")+(o.Day!=null?o.Day+"日 ":"")+(o.Hour!=null?String(o.Hour).padStart(2,"0"):"**")+":"+String(o.Minute??0).padStart(2,"0")).join(",")+(a.length>4?" ほか"+(a.length-4):""); }
  else if (j.KeepAlive) when="常駐";
  else if (j.RunAtLoad) when="載せたとき 1 回";
  else when="指定なし";
  const logp=j.StandardOutPath||j.StandardErrorPath||"";
  let lastLog=""; try { if (logp&&fs.existsSync(logp)) lastLog=fs.statSync(logp).mtime.toISOString().slice(0,10); } catch(e){}
  let llm=false; try { if (exists) { const s=fs.readFileSync(script,"utf8"); llm=/anthropic|api\.openai|ANTHROPIC_API_KEY|OPENAI_API_KEY|claude-(haiku|sonnet|opus)|messages\.create/.test(s); } } catch(e){}
  const once=/once|oneshot|-may\d|refollow-|celebrate-/.test(lb);
  rows.push({label:lb.replace("ai.openclaw.",""),when,script:script.replace(home,"~"),script_exists:exists,last_log:lastLog,in_autoload:autos.has(lb),llm,looks_one_shot:once});
}
rows.sort((a,b)=>(b.last_log||"").localeCompare(a.last_log||""));
fs.writeFileSync(jsonOut,JSON.stringify(rows,null,1));
console.log("\n| ジョブ | いつ動く | スクリプト | ログ最終 | 自動載せ直し | AI | 1 回きりらしい |");
console.log("| --- | --- | --- | --- | --- | --- | --- |");
for (const r of rows) console.log(`| ${r.label} | ${r.when} | ${r.script_exists===null?"（無し）":r.script_exists?"ある":"**無い**"} | ${r.last_log||"—"} | ${r.in_autoload?"入っている":"—"} | ${r.llm?"**呼ぶ**":"—"} | ${r.looks_one_shot?"はい":"—"} |`);
' "$LIST" "$AUTO" "$JSON" "$HOME" 2>&1
rm -f "$LIST"
echo; echo "（JSON: x435-unloaded-inventory.json）"
} > "$OUT" 2>&1
head -c 300 "$OUT"
exit 0
