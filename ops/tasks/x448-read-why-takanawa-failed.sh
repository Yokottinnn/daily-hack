#!/bin/bash
# x448（2026-11-10・読むだけ・$0）: 高輪の告知が x447 で thread-main-exec で落ちた理由を読む。
# ① 失敗の行を切らずに読む（秘密だけ伏せる） ② cdp-health ③ 自分のプロフィールの直近 8 本に高輪の投稿が無いか（出ていて ok:false の場合がある）。
# **投稿しない。再送しない。キューを書き換えない。**
set -uo pipefail
W="$HOME/.openclaw/workspace"; S="$W/scripts"; LOG="$W/logs/publish-takanawa-oneshot.log"
OUTDIR="${OPS_REPORT_DIR:-/tmp}"; OUT="$OUTDIR/x448-read-why-takanawa-failed.md"
STAMP="$(date '+%Y%m%d-%H%M%S')"; RUNNER="$S/.x448-read-$STAMP.js"; RAW="$W/.x448-out-$STAMP.json"
hide() { sed -E "s/@(heng_ji31590)/@\1/g; s/@[A-Za-z0-9_]{2,15}/@<伏せ>/g"; }
secrets() { sed -E -e 's#(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+#\1<MASKED>#g' -e 's#(Bearer )[A-Za-z0-9._-]{12,}#\1<MASKED>#g' -e 's#(auth_token=)[A-Za-z0-9]+#\1<MASKED>#g' -e 's#(ct0=)[A-Za-z0-9]+#\1<MASKED>#g'; }
clean() { hide | secrets; }
descendants() { local root="$1" p kids; kids="$(ps -Ao pid,ppid 2>/dev/null | awk -v r="$root" '$2==r {print $1}')"; for p in $kids; do echo "$p"; descendants "$p"; done; }
run_limited() { local limit="$1" outf="$2"; shift 2; "$@" > "$outf" 2>&1 & local pid=$! w=0
  while [ "$w" -lt "$limit" ]; do kill -0 "$pid" 2>/dev/null || break; sleep 1; w=$((w + 1)); done
  if kill -0 "$pid" 2>/dev/null; then local victims p; victims="$(descendants "$pid") $pid"; for p in $victims; do kill -TERM "$p" 2>/dev/null || true; done; sleep 3; for p in $victims; do kill -KILL "$p" 2>/dev/null || true; done; wait "$pid" 2>/dev/null || true; return 124; fi
  wait "$pid"; return $?; }
cat > "$RUNNER" <<'JSEOF'
const { chromium } = require("playwright-core");
const CDP = process.env.CHROME_CDP_URL || process.env.CDP_URL || "http://127.0.0.1:18810";
(async () => {
  let b; try { b = await chromium.connectOverCDP(CDP, { timeout: 60000 }); }
  catch (e) { console.log(JSON.stringify({ fatal: "CDP に繋がらない: " + String(e && e.message).slice(0, 200) })); process.exit(0); }
  const ctx = b.contexts()[0]; const p = await ctx.newPage(); const res = { rows: [] };
  try {
    await p.goto("https://x.com/heng_ji31590", { waitUntil: "domcontentloaded", timeout: 45000 }); await p.waitForTimeout(7000);
    res.url = p.url(); res.loggedIn = !!(await p.$('[data-testid="SideNav_NewTweet_Button"], [data-testid="AppTabBar_Profile_Link"]'));
    res.rows = await p.evaluate(() => [...document.querySelectorAll("article")].slice(0, 8).map((a) => { const tm = a.querySelector("time"); const tx = a.querySelector('[data-testid="tweetText"]');
      return { href: tm && tm.closest("a") ? tm.closest("a").getAttribute("href") : null, at: tm ? tm.getAttribute("datetime") : null, text: tx ? tx.innerText.slice(0, 60) : null, photos: a.querySelectorAll('[data-testid="tweetPhoto"]').length }; }));
  } catch (e) { res.error = String(e && e.message).slice(0, 200); }
  try { await p.close(); } catch (e) {} console.log(JSON.stringify(res)); process.exit(0);
})().catch((e) => { console.log(JSON.stringify({ fatal: String(e && e.message).slice(0, 300) })); process.exit(0); });
JSEOF
{
echo "# 高輪の告知はなぜ落ちたか（$(date '+%Y-%m-%d %H:%M:%S') JST・読むだけ・\$0）"
echo; echo "## ① 失敗の行（切らずに）"; echo '```'
grep -n 'thread-main-exec\|ok":false\|start\|done rc' "$LOG" 2>/dev/null | tail -n 4 | clean
echo '```'
echo; echo "## ② cdp-health"; echo '```'
(cd "$S" && run_limited 40 "$RAW.cdp" node "$S/cdp-health.js"; echo "  rc=$?"; head -c 600 "$RAW.cdp" 2>/dev/null) | clean; rm -f "$RAW.cdp"
pgrep -fl "Google Chrome for Testing|chrome" 2>/dev/null | wc -l | sed 's/^/  Chrome 系のプロセス数: /'
echo '```'
echo; echo "## ③ 自分のプロフィールの直近 8 本"; echo '```'
(cd "$S" && run_limited 120 "$RAW" node "$RUNNER"); echo "  rc=$?"
node -e 'let j;try{j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))}catch(e){console.log("読めない: "+require("fs").readFileSync(process.argv[1],"utf8").slice(0,400));process.exit(0)}
if(j.fatal){console.log("止まった: "+j.fatal);process.exit(0)}
console.log("url="+j.url+" loggedIn="+j.loggedIn+(j.error?" error="+j.error:""));
const jst=s=>s?new Date(new Date(s).getTime()+9*3600e3).toISOString().slice(0,16).replace("T"," "):"?";
for(const r of j.rows||[])console.log("- "+jst(r.at)+" "+r.href+" 画像:"+r.photos+" 「"+String(r.text||"").replace(/\n/g," ")+"」");
const hit=(j.rows||[]).find(r=>r.text&&/高輪ゲートウェイに/.test(r.text));console.log("判定: "+(hit?"出ている → https://x.com"+hit.href:"直近 8 本に高輪の投稿は無い"));' "$RAW" 2>&1 | clean
echo '```'
} > "$OUT" 2>&1
rm -f "$RUNNER" "$RAW"
grep -E '判定|止まった|loggedIn' "$OUT" | head -3 | cut -c1-250
exit 0
